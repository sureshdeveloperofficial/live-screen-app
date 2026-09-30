import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/app_controller.dart';
import '../widgets/status_badge.dart';
import 'file_transfer_screen.dart';
import 'security_lab_screen.dart';
import 'sender_screen.dart';
import 'settings_screen.dart';
import 'viewer_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppController.instance,
      builder: (context, _) {
        final controller = AppController.instance;
        final bool hasActiveSession = controller.role != AppRole.none;

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryCyan.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.screen_share_rounded,
                                    color: AppTheme.primaryCyan,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'ViziLink',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      'SECURITY LAB',
                                      style: TextStyle(
                                        color: AppTheme.primaryCyan,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Security Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.accentEmerald.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.accentEmerald.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.verified_user_rounded, color: AppTheme.accentEmerald, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Zero-Stealth Architecture: Android MediaProjection & Explicit Foreground Consent',
                                  style: TextStyle(
                                    color: AppTheme.accentEmerald,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (hasActiveSession) ...[
                          const SizedBox(height: 16),
                          _buildActiveSessionBanner(context, controller),
                        ],

                        const SizedBox(height: 24),
                        const Text(
                          'Select Mirroring Role',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Features List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildFeatureCard(
                        context: context,
                        title: 'Start Screen Sharing',
                        subtitle: 'Phone A (Broadcaster) — Stream screen anywhere over Internet (4G/5G/Wi-Fi) with 6-digit Room Code & system consent.',
                        icon: Icons.cast_connected_rounded,
                        accentColor: AppTheme.primaryCyan,
                        badgeLabel: 'SENDER (PHONE A)',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SenderScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildFeatureCard(
                        context: context,
                        title: 'View Another Device',
                        subtitle: 'Phone B (Receiver) — Enter 6-digit Room Code or scan QR to view live screen from anywhere.',
                        icon: Icons.tv_rounded,
                        accentColor: const Color(0xFF818CF8),
                        badgeLabel: 'VIEWER (PHONE B)',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ViewerScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildFeatureCard(
                        context: context,
                        title: 'WebRTC File Transfer',
                        subtitle: 'P2P chunked file transfer with SHA-256 integrity verification, flow control, and recipient approval.',
                        icon: Icons.folder_shared_rounded,
                        accentColor: AppTheme.accentAmber,
                        badgeLabel: 'DATA CHANNEL',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FileTransferScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildFeatureCard(
                        context: context,
                        title: 'Educational Security Lab',
                        subtitle: 'Interactive analysis of Android screen capture defenses: MediaProjection token security, AppOps, and spyware detection.',
                        icon: Icons.security_rounded,
                        accentColor: AppTheme.accentEmerald,
                        badgeLabel: 'DEEP DIVE',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SecurityLabScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildFooter(),
                      const SizedBox(height: 20),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveSessionBanner(BuildContext context, AppController controller) {
    final isSender = controller.role == AppRole.sender;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Row(
        children: [
          StatusBadge(
            label: isSender ? 'HOSTING' : 'VIEWING',
            color: AppTheme.primaryCyan,
            isPulsing: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.isStreaming ? 'Stream Active' : 'Session Ready',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  controller.connectedDeviceName ?? 'Waiting for peer...',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              backgroundColor: AppTheme.surfaceBorder,
              foregroundColor: AppTheme.textPrimary,
            ),
            onPressed: () {
              if (isSender) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SenderScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ViewerScreen()),
                );
              }
            },
            child: const Text('Resume', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String badgeLabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.surfaceBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                StatusBadge(label: badgeLabel, color: accentColor),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Launch',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, color: accentColor, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: const [
          Icon(Icons.lock_clock_rounded, color: AppTheme.textMuted, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No external cloud relay. Peer-to-peer transport operates directly across your local Wi-Fi or Hotspot.',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
