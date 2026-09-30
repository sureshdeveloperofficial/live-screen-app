import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/file_transfer_model.dart';
import '../services/app_controller.dart';
import '../widgets/status_badge.dart';

class FileTransferScreen extends StatefulWidget {
  const FileTransferScreen({super.key});

  @override
  State<FileTransferScreen> createState() => _FileTransferScreenState();
}

class _FileTransferScreenState extends State<FileTransferScreen> {
  final AppController _controller = AppController.instance;
  final List<FileTransferItem> _transfers = [];

  @override
  void initState() {
    super.initState();

    // Setup incoming offer dialog callback
    _controller.fileTransferService.onFileOfferPrompt = _showIncomingFilePrompt;

    // Listen for transfer updates
    _controller.fileTransferService.transferUpdates.listen((item) {
      if (mounted) {
        setState(() {
          final index = _transfers.indexWhere((t) => t.id == item.id);
          if (index >= 0) {
            _transfers[index] = item;
          } else {
            _transfers.insert(0, item);
          }
        });
      }
    });
  }

  Future<bool> _showIncomingFilePrompt(FileTransferItem item) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.primaryCyan, width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.download_rounded, color: AppTheme.primaryCyan, size: 24),
            SizedBox(width: 10),
            Text('Incoming File Transfer', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remote peer wants to send you:\n"${item.name}"',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Size: ${_formatBytes(item.totalBytes)} (${item.totalChunks} chunks)',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SHA-256 Checksum:',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.sha256Expected,
                    style: const TextStyle(
                      color: AppTheme.primaryCyan,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Decline', style: TextStyle(color: AppTheme.accentCoral)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept Transfer'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _pickAndSendFile() async {
    final file = await FilePicker.pickFile();

    if (file != null && file.path != null) {
      await _controller.fileTransferService.prepareFileForTransfer(
        filePath: file.path!,
        fileName: file.name,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final bool isChannelReady =
            _controller.webrtcService.dataChannel != null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('WebRTC File Transfer'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildChannelStatusBanner(isChannelReady),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.file_upload_outlined, size: 22),
                  label: const Text('SELECT FILE TO SEND (DATA CHANNEL)'),
                  onPressed: isChannelReady ? _pickAndSendFile : null,
                ),

                if (!isChannelReady) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Note: Establish an active screen sharing session first to open the direct WebRTC DataChannel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],

                const SizedBox(height: 24),
                const Text(
                  'Transfers & Integrity Log',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),

                if (_transfers.isEmpty)
                  _buildEmptyState()
                else
                  ..._transfers.map((item) => _buildTransferCard(item)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChannelStatusBanner(bool isReady) {
    final color = isReady ? AppTheme.accentEmerald : AppTheme.accentAmber;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle_outline_rounded : Icons.sync_problem_rounded,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReady ? 'DataChannel Ready (P2P)' : 'DataChannel Inactive',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isReady
                      ? 'Encrypted local transport active. Max chunk size: 64 KB.'
                      : 'Connect Phone A and Phone B to enable direct P2P data transfer.',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCard(FileTransferItem item) {
    Color statusColor;
    String statusLabel;

    switch (item.status) {
      case FileTransferStatus.pendingApproval:
        statusColor = AppTheme.accentAmber;
        statusLabel = 'AWAITING APPROVAL';
        break;
      case FileTransferStatus.transferring:
        statusColor = AppTheme.primaryCyan;
        statusLabel = 'TRANSFERRING';
        break;
      case FileTransferStatus.paused:
        statusColor = AppTheme.textMuted;
        statusLabel = 'PAUSED';
        break;
      case FileTransferStatus.completed:
        statusColor = AppTheme.accentEmerald;
        statusLabel = 'SHA-256 VERIFIED ✓';
        break;
      case FileTransferStatus.cancelled:
        statusColor = AppTheme.accentCoral;
        statusLabel = 'CANCELLED';
        break;
      case FileTransferStatus.error:
        statusColor = AppTheme.accentCoral;
        statusLabel = 'FAILED';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    item.isOutgoing ? Icons.upload_file_rounded : Icons.download_rounded,
                    color: item.isOutgoing ? AppTheme.primaryCyan : AppTheme.accentEmerald,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 170,
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              StatusBadge(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: item.progress,
              minHeight: 6,
              backgroundColor: AppTheme.surfaceLight,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 10),

          // Details row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatBytes(item.bytesTransferred)} / ${_formatBytes(item.totalBytes)} (${(item.progress * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'Chunk ${item.currentChunk} of ${item.totalChunks}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),

          if (item.status == FileTransferStatus.completed && item.localSavedPath != null) ...[
            const SizedBox(height: 8),
            Text(
              'Saved to: ${item.localSavedPath}',
              style: const TextStyle(
                color: AppTheme.accentEmerald,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],

          if (item.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              item.errorMessage!,
              style: const TextStyle(color: AppTheme.accentCoral, fontSize: 11),
            ),
          ],

          // Controls
          if (item.status == FileTransferStatus.transferring ||
              item.status == FileTransferStatus.paused) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (item.status == FileTransferStatus.transferring)
                  TextButton.icon(
                    icon: const Icon(Icons.pause_rounded, size: 16),
                    label: const Text('Pause', style: TextStyle(fontSize: 12)),
                    onPressed: () => _controller.fileTransferService.pauseTransfer(item.id),
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Resume', style: TextStyle(fontSize: 12)),
                    onPressed: () => _controller.fileTransferService.resumeTransfer(item.id),
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: AppTheme.accentCoral),
                  label: const Text('Cancel', style: TextStyle(color: AppTheme.accentCoral, fontSize: 12)),
                  onPressed: () => _controller.fileTransferService.cancelTransfer(item.id),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        children: const [
          Icon(Icons.folder_open_rounded, size: 40, color: AppTheme.textMuted),
          SizedBox(height: 12),
          Text(
            'No Active File Transfers',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Files sent over WebRTC DataChannel will appear here with real-time SHA-256 checksum checks.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
