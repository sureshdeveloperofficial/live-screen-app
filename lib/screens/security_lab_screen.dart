import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_theme.dart';

class SecurityLabScreen extends StatelessWidget {
  const SecurityLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Lab (Educational)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroBanner(),
            const SizedBox(height: 20),

            _buildSection(
              title: '1. How MediaProjection Protects Android',
              subtitle: 'Android OS System-Level Consent Architecture',
              icon: Icons.shield_rounded,
              accentColor: AppTheme.primaryCyan,
              content: [
                _buildParagraph(
                  'Android enforces a strict security boundary around screen display contents. '
                  'Unlike legacy desktop operating systems where any background process can capture display pixels, '
                  'Android prevents applications from directly reading the framebuffer.',
                ),
                _buildKeyPoint(
                  'The MediaProjection Token Model',
                  'Apps must call "MediaProjectionManager.createScreenCaptureIntent()". '
                  'This triggers Android\'s trusted SystemUI to present a non-bypassable system dialog to the user. '
                  'Only after the user explicitly taps "Start now" does the OS return an Activity Result containing a cryptographic token.',
                ),
                _buildKeyPoint(
                  'Single-Use & Process-Bound',
                  'The resulting token is bound to the calling application UID. '
                  'If the app terminates, loses focus, or if the user taps the notification bar, '
                  'the Android system revokes the token and the VirtualDisplay stops emitting video frames.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildSection(
              title: '2. Foreground Services & Privacy Indicators',
              subtitle: 'Preventing Covert and Silent Background Capture',
              icon: Icons.notifications_active_rounded,
              accentColor: AppTheme.accentAmber,
              content: [
                _buildParagraph(
                  'Starting in Android 10 and reinforced heavily in Android 14 (API 34), '
                  'the operating system mandates that screen capture can ONLY execute under a dedicated Foreground Service '
                  'with the "mediaProjection" type declared in the manifest.',
                ),
                _buildKeyPoint(
                  'Mandatory Ongoing Notification',
                  'Foreground services must display a persistent, non-dismissible notification. '
                  'An application cannot suppress, hide, or set notification priority to zero to evade the user.',
                ),
                _buildKeyPoint(
                  'System Privacy Chip (Green Indicator)',
                  'Android 12+ introduces the hardware privacy chip in the top status bar. '
                  'Whenever MediaProjection, Camera, or Microphone APIs are active, the Android OS itself draws '
                  'the green status icon. This indicator is rendered by the system compositor and CANNOT be covered or spoofed.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildSection(
              title: '3. Technical Stream Transport (WebRTC)',
              subtitle: 'Local Peer-to-Peer vs External Cloud Exfiltration',
              icon: Icons.lock_outline_rounded,
              accentColor: const Color(0xFF818CF8),
              content: [
                _buildParagraph(
                  'Legitimate screen mirroring tools (such as ViziLink) transport video frames over direct P2P connections, '
                  'whereas malicious spyware exfiltrates frames to remote command-and-control (C2) servers.',
                ),
                _buildKeyPoint(
                  'DTLS-SRTP End-to-End Encryption',
                  'WebRTC video tracks and DataChannels are encrypted using Datagram Transport Layer Security (DTLS) '
                  'and Secure Real-time Transport Protocol (SRTP). Keys are negotiated peer-to-peer.',
                ),
                _buildKeyPoint(
                  'Zero-Cloud Architecture',
                  'ViziLink runs an embedded signaling server directly on Phone A. '
                  'No third-party server ever stores, processes, or relays video frames or files.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildSection(
              title: '4. Attack Vector Comparison: Spyware vs ViziLink',
              subtitle: 'Contrasting Malicious Techniques with Legitimate Mirroring',
              icon: Icons.compare_arrows_rounded,
              accentColor: AppTheme.accentCoral,
              content: [
                _buildComparisonTable(),
              ],
            ),

            const SizedBox(height: 16),

            _buildSection(
              title: '5. Defender\'s Inspection & Audit Guide',
              subtitle: 'How Sysadmins and Users Can Audit Active Screen Mirroring',
              icon: Icons.terminal_rounded,
              accentColor: AppTheme.accentEmerald,
              content: [
                _buildParagraph(
                  'Security teams, forensic analysts, and curious users can verify and audit active MediaProjection sessions '
                  'directly via ADB terminal commands.',
                ),
                _buildCodeSnippet(
                  'Check active MediaProjection sessions:',
                  'adb shell dumpsys media_projection',
                  context,
                ),
                const SizedBox(height: 8),
                _buildCodeSnippet(
                  'Inspect running mediaProjection foreground services:',
                  'adb shell dumpsys activity services | grep -i "mediaProjection"',
                  context,
                ),
                const SizedBox(height: 8),
                _buildCodeSnippet(
                  'Query AppOps permissions for screen capture:',
                  'adb shell cmd appops get com.vizilink.securitylab.vizilink_security_lab PROJECT_MEDIA',
                  context,
                ),
                const SizedBox(height: 12),
                _buildKeyPoint(
                  'How to Revoke Access Manually',
                  '1. Swipe down the Android notification shade and tap "Stop Sharing" on the persistent notification.\n'
                  '2. Open Android Settings → Apps → ViziLink → Permissions → Remove notifications / screen recording.\n'
                  '3. In Developer Options → Running Services, terminate any unauthorized background process.',
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.school_rounded, color: AppTheme.primaryCyan, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Android Screen Capture Security Architecture',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'This educational module illustrates how modern Android OS security controls prevent covert surveillance, '
            'and how defenders can inspect and audit running screen mirroring tools.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<Widget> content,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...content,
        ],
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.45),
      ),
    );
  }

  Widget _buildKeyPoint(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.surfaceBorder.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder.symmetric(
          inside: const BorderSide(color: AppTheme.surfaceBorder, width: 0.8),
        ),
        columnWidths: const {
          0: FlexColumnWidth(1.2),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1.5),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: AppTheme.background.withValues(alpha: 0.6)),
            children: const [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Vector', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary)),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Malicious Spyware', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.accentCoral)),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('ViziLink Mirroring', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.accentEmerald)),
              ),
            ],
          ),
          _buildTableRow(
            'User Consent',
            'Abuses Accessibility Services or overlay phishing to bypass prompts',
            'Requires explicit Android MediaProjection system dialog & PIN verification',
          ),
          _buildTableRow(
            'Visibility',
            'Hides app icon, suppresses notifications, operates invisibly',
            'Persistent non-dismissible notification + green system status indicator',
          ),
          _buildTableRow(
            'Destination',
            'Exfiltrates frames to rogue remote C2 servers over the internet',
            'Transfers encrypted frames strictly over local Wi-Fi / Hotspot LAN',
          ),
          _buildTableRow(
            'Termination',
            'Resists termination, sets alarms, restarts on reboot',
            'Instant cessation on user disconnect, notification tap, or app exit',
          ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String vector, String malicious, String legitimate) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(vector, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: AppTheme.textPrimary)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(malicious, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, height: 1.3)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(legitimate, style: const TextStyle(fontSize: 10, color: AppTheme.accentEmerald, height: 1.3)),
        ),
      ],
    );
  }

  Widget _buildCodeSnippet(String label, String command, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  command,
                  style: const TextStyle(
                    color: AppTheme.primaryCyan,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textMuted),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: command));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Command copied to clipboard')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
