import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/app_theme.dart';
import '../services/app_controller.dart';
import '../widgets/stats_hud.dart';
import '../widgets/status_badge.dart';

enum ViewerState { uncoupled, scanning, connecting, awaitingApproval, streaming, failed }

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final AppController _controller = AppController.instance;
  ViewerState _state = ViewerState.uncoupled;
  String? _statusMessage;
  bool _isFullscreen = false;

  final TextEditingController _roomCodeController = TextEditingController();

  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    if (_controller.role == AppRole.viewer && _controller.isStreaming) {
      _state = ViewerState.streaming;
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  void _startScanning() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    setState(() {
      _state = ViewerState.scanning;
      _statusMessage = null;
    });
  }

  void _handleQrDetect(BarcodeCapture capture) {
    if (_state != ViewerState.scanning) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        try {
          final Map<String, dynamic> data =
              jsonDecode(rawValue) as Map<String, dynamic>;
          final roomCode = (data['roomCode'] ?? data['pin']) as String?;
          final ip = data['ip'] as String?;
          final port = data['port'] as int? ?? 8888;
          final pin = data['pin'] as String?;

          if (roomCode != null && roomCode.isNotEmpty) {
            _scannerController?.stop();
            _initiateConnection(roomCodeOrIp: roomCode, port: port, pin: pin);
            break;
          } else if (ip != null && pin != null) {
            _scannerController?.stop();
            _initiateConnection(roomCodeOrIp: ip, port: port, pin: pin);
            break;
          }
        } catch (_) {
          // Fallback if rawValue is just a plain 6-digit room code
          final trimmed = rawValue.trim();
          if (trimmed.length == 6 && int.tryParse(trimmed) != null) {
            _scannerController?.stop();
            _initiateConnection(roomCodeOrIp: trimmed);
            break;
          }
        }
      }
    }
  }

  Future<void> _initiateConnection({
    required String roomCodeOrIp,
    int port = 8888,
    String? pin,
  }) async {
    final clean = roomCodeOrIp.trim().replaceAll(' ', '');
    final isInternet = _controller.useInternetMode || !clean.contains('.');

    setState(() {
      _state = ViewerState.connecting;
      _statusMessage = isInternet
          ? 'Connecting to Internet Room $clean...'
          : 'Connecting to Phone A at $clean:$port...';
    });

    try {
      await _controller.connectAsViewer(
        roomCodeOrIp: clean,
        port: port,
        pin: pin,
        onApproved: () {
          if (mounted) {
            setState(() {
              _state = ViewerState.streaming;
              _statusMessage = null;
            });
          }
        },
        onRejected: (reason) {
          if (mounted) {
            setState(() {
              _state = ViewerState.failed;
              _statusMessage = 'Connection Rejected: $reason';
            });
          }
        },
        onAuthFailed: (reason) {
          if (mounted) {
            setState(() {
              _state = ViewerState.failed;
              _statusMessage = 'Authentication Failed: $reason';
            });
          }
        },
      );

      if (mounted && _state == ViewerState.connecting) {
        setState(() {
          _state = ViewerState.awaitingApproval;
          _statusMessage = 'PIN verified. Awaiting explicit approval on Phone A...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = ViewerState.failed;
          _statusMessage = 'Connection error: $e';
        });
      }
    }
  }

  Future<void> _handleDisconnect() async {
    await _controller.stopSession();
    if (mounted) {
      setState(() {
        _state = ViewerState.uncoupled;
        _statusMessage = null;
        _isFullscreen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_state == ViewerState.streaming) {
          return _buildStreamingView();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Phone B (Viewer)'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 20),

                if (_statusMessage != null) ...[
                  _buildStatusBanner(_statusMessage!, _state == ViewerState.failed),
                  const SizedBox(height: 18),
                ],

                if (_state == ViewerState.scanning) ...[
                  _buildScannerCard(),
                ] else if (_state == ViewerState.connecting ||
                    _state == ViewerState.awaitingApproval) ...[
                  _buildConnectingStateCard(),
                ] else ...[
                  _buildPairingChoiceCards(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF818CF8).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tv_rounded, color: Color(0xFF818CF8), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Viewer Console',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Subscribe to Phone A screen stream in real-time.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairingChoiceCards() {
    return Column(
      children: [
        // Primary Internet Room Code Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryCyan.withValues(alpha: 0.08),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.public_rounded, color: AppTheme.primaryCyan, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Connect via Internet',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Works on 4G/5G mobile data or any Wi-Fi worldwide',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              TextField(
                controller: _roomCodeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6.0,
                  fontFamily: 'monospace',
                  color: AppTheme.primaryCyan,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '• • • • • •',
                  hintStyle: TextStyle(
                    letterSpacing: 6.0,
                    color: AppTheme.textMuted.withValues(alpha: 0.6),
                  ),
                  labelText: '6-Digit Room Code',
                  counterText: '',
                  prefixIcon: const Icon(Icons.pin_rounded, color: AppTheme.primaryCyan, size: 20),
                  filled: true,
                  fillColor: AppTheme.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.surfaceBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryCyan, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              ElevatedButton.icon(
                icon: const Icon(Icons.cloud_sync_rounded, size: 20),
                label: const Text('Connect to Room Stream'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final code = _roomCodeController.text.trim();
                  if (code.length != 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter the 6-digit Room Code shown on Phone A.')),
                    );
                    return;
                  }
                  _initiateConnection(roomCodeOrIp: code);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Scan QR Button Card
        InkWell(
          onTap: _startScanning,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryCyan, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Scan Phone A QR Code',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Instant camera scan pairing',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Security / P2P direct info banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Row(
            children: const [
              Icon(Icons.shield_outlined, color: AppTheme.primaryCyan, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'End-to-end encrypted direct WebRTC video pipeline. No video streams are saved or relayed through third-party servers.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScannerCard() {
    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryCyan, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (_scannerController != null)
            MobileScanner(
              controller: _scannerController!,
              onDetect: _handleQrDetect,
            ),
          Positioned(
            top: 14,
            right: 14,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () {
                _scannerController?.stop();
                setState(() {
                  _state = ViewerState.uncoupled;
                });
              },
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Point camera at the QR code displayed on Phone A',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingStateCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              color: AppTheme.primaryCyan,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _state == ViewerState.awaitingApproval
                ? 'Awaiting Approval on Phone A'
                : 'Connecting to Host...',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _state == ViewerState.awaitingApproval
                ? 'Check Phone A screen. The host must explicitly approve the mirroring request.'
                : 'Establishing local WebSocket handshake and verifying session PIN.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _handleDisconnect,
            child: const Text('Cancel Connection'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(String message, bool isError) {
    final color = isError ? AppTheme.accentCoral : AppTheme.accentAmber;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // LIVE STREAMING HUD & RENDERER (Phase 7)
  // ==========================================

  Widget _buildStreamingView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: !_isFullscreen,
        bottom: !_isFullscreen,
        child: Stack(
          children: [
            // Video Renderer
            Center(
              child: RTCVideoView(
                _controller.webrtcService.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              ),
            ),

            if (_controller.webrtcService.remoteStream == null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryCyan,
                          strokeWidth: 3,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Connecting to Live Video Stream...',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Awaiting screen capture authorization on Phone A',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Top Status Bar (Overlay)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.surfaceBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ViziLink',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: 'LIVE',
                          color: AppTheme.accentCoral,
                          isPulsing: true,
                        ),
                      ],
                    ),
                  ),

                  // Disconnect Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentCoral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Disconnect', style: TextStyle(fontSize: 12)),
                    onPressed: _showDisconnectConfirmation,
                  ),
                ],
              ),
            ),

            // Bottom Diagnostics HUD
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Center(
                child: StatsHud(
                  stats: _controller.currentStats,
                  isFullscreen: _isFullscreen,
                  onToggleFullscreen: () {
                    setState(() {
                      _isFullscreen = !_isFullscreen;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisconnectConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Disconnect Stream?'),
        content: const Text('Are you sure you want to terminate the live screen viewing session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCoral),
            onPressed: () {
              Navigator.pop(ctx);
              _handleDisconnect();
            },
            child: const Text('Disconnect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
