enum FileTransferStatus {
  pendingApproval,
  transferring,
  paused,
  completed,
  cancelled,
  error,
}

class FileTransferItem {
  final String id;
  final String name;
  final int totalBytes;
  final int totalChunks;
  final String sha256Expected;
  final bool isOutgoing;

  int bytesTransferred;
  int currentChunk;
  String? sha256Calculated;
  FileTransferStatus status;
  String? errorMessage;
  String? localSavedPath;

  FileTransferItem({
    required this.id,
    required this.name,
    required this.totalBytes,
    required this.totalChunks,
    required this.sha256Expected,
    required this.isOutgoing,
    this.bytesTransferred = 0,
    this.currentChunk = 0,
    this.sha256Calculated,
    this.status = FileTransferStatus.pendingApproval,
    this.errorMessage,
    this.localSavedPath,
  });

  double get progress => totalBytes > 0 ? (bytesTransferred / totalBytes).clamp(0.0, 1.0) : 0.0;

  bool get isCompleted => status == FileTransferStatus.completed;
  bool get isTransferring => status == FileTransferStatus.transferring;
  bool get isPaused => status == FileTransferStatus.paused;

  Map<String, dynamic> toMetadataMap() {
    return {
      'type': 'file_meta',
      'id': id,
      'name': name,
      'totalBytes': totalBytes,
      'totalChunks': totalChunks,
      'sha256': sha256Expected,
    };
  }

  factory FileTransferItem.fromMetadataMap(Map<String, dynamic> map, {required bool isOutgoing}) {
    return FileTransferItem(
      id: map['id'] as String,
      name: map['name'] as String,
      totalBytes: map['totalBytes'] as int,
      totalChunks: map['totalChunks'] as int,
      sha256Expected: map['sha256'] as String,
      isOutgoing: isOutgoing,
      status: isOutgoing ? FileTransferStatus.transferring : FileTransferStatus.pendingApproval,
    );
  }
}
