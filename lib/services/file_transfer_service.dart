import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/file_transfer_model.dart';

typedef FileOfferPrompt = Future<bool> Function(FileTransferItem item);

class FileTransferService {
  RTCDataChannel? _dataChannel;
  FileOfferPrompt? onFileOfferPrompt;

  final StreamController<FileTransferItem> _transferUpdates =
      StreamController<FileTransferItem>.broadcast();
  Stream<FileTransferItem> get transferUpdates => _transferUpdates.stream;

  final Map<String, FileTransferItem> _transfers = {};
  final Map<String, BytesBuilder> _incomingBuffers = {};
  bool _isPaused = false;
  bool _isCancelled = false;

  void attachDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;
    _dataChannel!.onMessage = _handleDataChannelMessage;
  }

  void _handleDataChannelMessage(RTCDataChannelMessage message) {
    try {
      if (message.isBinary) {
        _handleBinaryChunk(message.binary);
      } else {
        final Map<String, dynamic> data =
            jsonDecode(message.text) as Map<String, dynamic>;
        final String type = data['type'] as String? ?? '';

        switch (type) {
          case 'file_meta':
            _handleIncomingFileOffer(data);
            break;
          case 'file_accept':
            _startSendingFileChunks(data['id'] as String);
            break;
          case 'file_reject':
            _handleFileRejected(data['id'] as String);
            break;
          case 'file_cancel':
            _handleTransferCancelled(data['id'] as String);
            break;
          case 'file_pause':
            _handleTransferPaused(data['id'] as String);
            break;
          case 'file_resume':
            _handleTransferResumed(data['id'] as String);
            break;
          case 'file_done':
            _handleRemoteDone(data['id'] as String, data['verified'] as bool? ?? false);
            break;
        }
      }
    } catch (e) {
      debugPrint('DataChannel message handling error: $e');
    }
  }

  // ==========================================
  // SENDER FLOW
  // ==========================================

  Future<FileTransferItem?> prepareFileForTransfer({
    required String filePath,
    required String fileName,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    final totalBytes = bytes.length;
    final totalChunks = (totalBytes / AppConstants.chunkSize).ceil();
    final sha256Hash = sha256.convert(bytes).toString();
    final fileId = const Uuid().v4();

    final item = FileTransferItem(
      id: fileId,
      name: fileName,
      totalBytes: totalBytes,
      totalChunks: totalChunks,
      sha256Expected: sha256Hash,
      isOutgoing: true,
      status: FileTransferStatus.pendingApproval,
    );

    _transfers[fileId] = item;
    _outgoingFileBytes[fileId] = bytes;
    _transferUpdates.add(item);

    // Send metadata to recipient
    _sendJson(item.toMetadataMap());
    return item;
  }

  final Map<String, Uint8List> _outgoingFileBytes = {};

  Future<void> _startSendingFileChunks(String fileId) async {
    final item = _transfers[fileId];
    final bytes = _outgoingFileBytes[fileId];
    if (item == null || bytes == null || _dataChannel == null) return;

    item.status = FileTransferStatus.transferring;
    _isPaused = false;
    _isCancelled = false;
    _transferUpdates.add(item);

    int offset = 0;
    int chunkIndex = 0;

    while (offset < bytes.length && !_isCancelled) {
      while (_isPaused && !_isCancelled) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
      if (_isCancelled) break;

      final end = (offset + AppConstants.chunkSize < bytes.length)
          ? offset + AppConstants.chunkSize
          : bytes.length;
      final chunkSlice = bytes.sublist(offset, end);

      // Packet format: [16 bytes UUID header string] + [4 bytes chunk index] + [raw bytes]
      final builder = BytesBuilder();
      final idBytes = utf8.encode(fileId.padRight(36).substring(0, 36));
      builder.add(idBytes);

      final indexByteData = ByteData(4)..setInt32(0, chunkIndex, Endian.big);
      builder.add(indexByteData.buffer.asUint8List());
      builder.add(chunkSlice);

      final packet = builder.toBytes();

      // Flow control: Prevent DataChannel buffer saturation
      final bufferedAmount = _dataChannel!.bufferedAmount ?? 0;
      if (bufferedAmount > 1024 * 1024) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      _dataChannel!.send(RTCDataChannelMessage.fromBinary(packet));

      offset = end;
      chunkIndex++;
      item.bytesTransferred = offset;
      item.currentChunk = chunkIndex;
      _transferUpdates.add(item);

      // Yield event loop
      await Future.delayed(const Duration(milliseconds: 2));
    }

    if (!_isCancelled) {
      item.status = FileTransferStatus.completed;
      _transferUpdates.add(item);
      _outgoingFileBytes.remove(fileId);
    }
  }

  // ==========================================
  // RECEIVER FLOW
  // ==========================================

  Future<void> _handleIncomingFileOffer(Map<String, dynamic> data) async {
    final item = FileTransferItem.fromMetadataMap(data, isOutgoing: false);
    _transfers[item.id] = item;
    _incomingBuffers[item.id] = BytesBuilder();
    _transferUpdates.add(item);

    // Prompt user for confirmation
    bool accepted = false;
    if (onFileOfferPrompt != null) {
      accepted = await onFileOfferPrompt!(item);
    } else {
      accepted = true;
    }

    if (accepted) {
      item.status = FileTransferStatus.transferring;
      _sendJson({'type': 'file_accept', 'id': item.id});
      _transferUpdates.add(item);
    } else {
      item.status = FileTransferStatus.cancelled;
      _sendJson({'type': 'file_reject', 'id': item.id});
      _incomingBuffers.remove(item.id);
      _transferUpdates.add(item);
    }
  }

  Future<void> _handleBinaryChunk(Uint8List packet) async {
    if (packet.length < 40) return; // 36 bytes ID + 4 bytes index

    final id = utf8.decode(packet.sublist(0, 36)).trim();
    final item = _transfers[id];
    final buffer = _incomingBuffers[id];

    if (item == null || buffer == null) return;

    final indexByteData = ByteData.sublistView(packet, 36, 40);
    final chunkIndex = indexByteData.getInt32(0, Endian.big);
    final chunkData = packet.sublist(40);

    buffer.add(chunkData);
    item.bytesTransferred += chunkData.length;
    item.currentChunk = chunkIndex + 1;
    _transferUpdates.add(item);

    // Check completion
    if (item.bytesTransferred >= item.totalBytes) {
      final completeBytes = buffer.toBytes();
      final calculatedHash = sha256.convert(completeBytes).toString();
      item.sha256Calculated = calculatedHash;

      if (calculatedHash.toLowerCase() == item.sha256Expected.toLowerCase()) {
        // Integrity check passed! Save to local downloads / documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final savePath = '${appDir.path}/${item.name}';
        final savedFile = File(savePath);
        await savedFile.writeAsBytes(completeBytes);

        item.localSavedPath = savePath;
        item.status = FileTransferStatus.completed;
        _sendJson({'type': 'file_done', 'id': item.id, 'verified': true});
      } else {
        item.status = FileTransferStatus.error;
        item.errorMessage = 'SHA-256 Checksum Mismatch! File rejected.';
        _sendJson({'type': 'file_done', 'id': item.id, 'verified': false});
      }

      _incomingBuffers.remove(id);
      _transferUpdates.add(item);
    }
  }

  // ==========================================
  // USER CONTROLS: PAUSE, RESUME, CANCEL
  // ==========================================

  void pauseTransfer(String id) {
    _isPaused = true;
    final item = _transfers[id];
    if (item != null) {
      item.status = FileTransferStatus.paused;
      _sendJson({'type': 'file_pause', 'id': id});
      _transferUpdates.add(item);
    }
  }

  void resumeTransfer(String id) {
    _isPaused = false;
    final item = _transfers[id];
    if (item != null) {
      item.status = FileTransferStatus.transferring;
      _sendJson({'type': 'file_resume', 'id': id});
      _transferUpdates.add(item);
    }
  }

  void cancelTransfer(String id) {
    _isCancelled = true;
    final item = _transfers[id];
    if (item != null) {
      item.status = FileTransferStatus.cancelled;
      _sendJson({'type': 'file_cancel', 'id': id});
      _transferUpdates.add(item);
    }
  }

  void _handleTransferPaused(String id) {
    final item = _transfers[id];
    if (item != null) {
      item.status = FileTransferStatus.paused;
      _transferUpdates.add(item);
    }
  }

  void _handleTransferResumed(String id) {
    final item = _transfers[id];
    if (item != null) {
      item.status = FileTransferStatus.transferring;
      _transferUpdates.add(item);
    }
  }

  void _handleTransferCancelled(String id) {
    final item = _transfers[id];
    if (item != null) {
      item.status = FileTransferStatus.cancelled;
      _transferUpdates.add(item);
    }
  }

  void _handleFileRejected(String id) {
    final item = _transfers[id];
    if (item != null) {
      item.status = FileTransferStatus.cancelled;
      item.errorMessage = 'Recipient declined file transfer.';
      _transferUpdates.add(item);
    }
  }

  void _handleRemoteDone(String id, bool verified) {
    final item = _transfers[id];
    if (item != null) {
      if (verified) {
        item.status = FileTransferStatus.completed;
      } else {
        item.status = FileTransferStatus.error;
        item.errorMessage = 'Recipient reported integrity check failure.';
      }
      _transferUpdates.add(item);
    }
  }

  void _sendJson(Map<String, dynamic> map) {
    if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage(jsonEncode(map)));
    }
  }

  void dispose() {
    _transferUpdates.close();
    _outgoingFileBytes.clear();
    _incomingBuffers.clear();
    _transfers.clear();
  }
}
