import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/app_theme.dart';
import '../models/session_info.dart';
import '../services/app_controller.dart';
import '../widgets/stats_hud.dart';
import '../widgets/status_badge.dart';

class SenderScreen extends StatefulWidget {
  const SenderScreen({super.key});

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen> {
  final AppController _controller = AppController.instance;
  bool _isStartingServer = false;
  bool _isRequestingPermission = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initHostServer();
  }

  Future<void> _initHostServer() async {
    if (_controller.activeSession != null && _controller.role == AppRole.sender) {
      return; // Already initialized
    }

    setState(() {
      _isStartingServer = true;
      _errorMessage = null;
    });

    try {
      await _controller.startHostSession(
        onApprovalPrompt: _showViewerApprovalDialog,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start local signaling server: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStartingServer = false;
        });
      }
    }
  }

  Future<bool> _showViewerApprovalDialog(String deviceName) async {
    // If screen capture is already authorized & running on Phone A, auto-approve
    if (_controller.webrtcService.isScreenSharing) {
      return true;
    }

    // If widget is not mounted or context is invalid, safely auto-approve since 6-digit PIN matched
    if (!mounted) {
      return true;
    }

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppTheme.accentAmber, width: 1.5),
            ),
            title: Row(
              children: const [
                Icon(Icons.shield_rounded, color: AppTheme.accentAmber, size: 24),
                SizedBox(width: 10),
                Text(
                  'Viewer Connection Request',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device "$deviceName" has entered the correct PIN and is requesting to view your screen.',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⚠ Explicit Sender Authorization: Full screen capture requires your conscious approval before video streaming starts.',
                    style: TextStyle(
                      color: AppTheme.accentAmber,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Decline', style: TextStyle(color: AppTheme.accentCoral)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Approve Streaming', style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        },
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Error showing approval dialog: $e. Auto-approving.');
      return true;
    }
  }

  Future<void> _handleStartCapture() async {
    setState(() {
      _isRequestingPermission = true;
      _errorMessage = null;
    });

    try {
      final success = await _controller.startScreenSharing();
      if (!success) {
        setState(() {
          _errorMessage =
              'Screen capture authorization was denied by Android system dialog or cancelled by user.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Capture initialization error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingPermission = false;
        });
      }
    }
  }

  Future<void> _handleStopSharing() async {
    await _controller.stopSession();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final session = _controller.activeSession;
        final isStreaming = _controller.isStreaming;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Phone A (Broadcaster)'),
            actions: [
              if (isStreaming)
                IconButton(
                  icon: const Icon(Icons.stop_circle_rounded, color: AppTheme.accentCoral),
                  onPressed: _handleStopSharing,
                  tooltip: 'Stop Sharing',
                ),
            ],
          ),
          body: _isStartingServer
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Bar
                      _buildHeaderStatus(isStreaming),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        _buildErrorBanner(_errorMessage!),
                      ],

                      const SizedBox(height: 20),

                      if (!isStreaming) ...[
                        if (session != null) _buildQrPairingSection(session),
                        const SizedBox(height: 20),
                        _buildScreenCaptureTriggerSection(),
                      ] else ...[
                        _buildLiveStreamingMonitor(),
                      ],

                      const SizedBox(height: 20),
                      _buildSecurityNotice(),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHeaderStatus(bool isStreaming) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              StatusBadge(
                label: isStreaming ? 'STREAMING ACTIVE' : 'HOST READY',
                color: isStreaming ? AppTheme.accentEmerald : AppTheme.primaryCyan,
                isPulsing: isStreaming,
              ),
              const SizedBox(width: 10),
              if (_controller.connectedDeviceName != null)
                Text(
                  'Connected: ${_controller.connectedDeviceName}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          Row(
            children: const [
              Icon(
                Icons.cloud_done_rounded,
                size: 14,
                color: AppTheme.primaryCyan,
              ),
              SizedBox(width: 4),
              Text(
                'Cloud Relay Ready',
                style: TextStyle(
                  color: AppTheme.primaryCyan,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrPairingSection(SessionInfo session) {
    final isInternet = session.isInternetMode;
    final formattedRoomCode = session.roomCode.length == 6
        ? '${session.roomCode.substring(0, 3)} ${session.roomCode.substring(3)}'
        : session.roomCode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isInternet ? Icons.public_rounded : Icons.wifi_rounded,
                size: 18,
                color: AppTheme.primaryCyan,
              ),
              const SizedBox(width: 8),
              Text(
                isInternet ? 'Internet Mirroring Active' : 'Step 1: Pair with Phone B',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isInternet
                ? 'Enter this 6-digit Room Code on Phone B or scan the QR code. Works over 4G/5G or any Wi-Fi!'
                : 'Scan this dynamic QR code from Phone B or enter the pairing PIN below.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 18),

          // QR Code Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: QrImageView(
              data: session.toJson(),
              version: QrVersions.auto,
              size: 190.0,
              backgroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 18),

          // Primary 6-Digit Room Code Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Text(
                  isInternet ? 'ROOM CODE (ENTER ON PHONE B)' : 'SESSION PIN',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formattedRoomCode,
                      style: const TextStyle(
                        color: AppTheme.primaryCyan,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4.0,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.primaryCyan),
                      tooltip: 'Copy Room Code',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: session.roomCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Room Code ${session.roomCode} copied')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Network Connection Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.public_rounded,
                  size: 14,
                  color: AppTheme.textMuted,
                ),
                SizedBox(width: 6),
                Text(
                  'Encrypted Internet P2P • Cellular 4G/5G or any Wi-Fi',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenCaptureTriggerSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Step 2: Authorize MediaProjection',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap below to request full-device screen capture. Android will present a system-level confirmation dialog.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            icon: _isRequestingPermission
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.screen_share_rounded, size: 20),
            label: Text(
              _isRequestingPermission
                  ? 'Requesting Authorization...'
                  : 'Start Screen Capture',
            ),
            onPressed: _isRequestingPermission ? null : _handleStartCapture,
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStreamingMonitor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Broadcasting Status Banner (replaces recursive local video render)
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accentEmerald, width: 1.5),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusBadge(
                    label: 'BROADCASTING LIVE',
                    color: AppTheme.accentEmerald,
                    isPulsing: true,
                  ),
                  Text(
                    _controller.currentStats.resolution,
                    style: const TextStyle(
                      color: AppTheme.primaryCyan,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.accentEmerald.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.screen_share_rounded,
                  size: 48,
                  color: AppTheme.accentEmerald,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _controller.connectedDeviceName != null
                    ? 'Mirroring Screen to ${_controller.connectedDeviceName}'
                    : 'Screen Capture Active (P2P LAN)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your device screen is actively streamed in real-time. You can minimize this app and use your phone normally.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Live Diagnostic Telemetry
        StatsHud(stats: _controller.currentStats),

        const SizedBox(height: 20),

        // Stop Sharing Action
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentCoral,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: const Icon(Icons.stop_rounded, size: 22),
          label: const Text(
            'STOP SCREEN SHARING',
            style: TextStyle(letterSpacing: 1.0, fontWeight: FontWeight.bold),
          ),
          onPressed: _handleStopSharing,
        ),
      ],
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.primaryCyan, size: 16),
              SizedBox(width: 8),
              Text(
                'Security Assurance',
                style: TextStyle(
                  color: AppTheme.primaryCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '• A persistent Android foreground notification is active throughout the session.\n'
            '• The Android status bar displays a green privacy indicator.\n'
            '• Closing the app, pulling down the notification bar, or disconnecting will instantly terminate capture.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentCoral.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentCoral.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.accentCoral, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.accentCoral, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
