import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/constants.dart';
import '../services/app_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppController _controller = AppController.instance;

  String _selectedPreset = '720p (Recommended)';
  int _selectedFps = 30;
  int _selectedBitrate = 2500;

  @override
  void initState() {
    super.initState();
    _selectedFps = _controller.targetFps;
    _selectedBitrate = _controller.bitrateKbps;
    if (_controller.videoHeight == 1080) {
      _selectedPreset = '1080p (High Quality)';
    } else if (_controller.videoHeight == 540) {
      _selectedPreset = '540p (Low Bandwidth)';
    } else {
      _selectedPreset = '720p (Recommended)';
    }
  }

  void _saveSettings() {
    final preset = AppConstants.videoPresets[_selectedPreset]!;
    _controller.videoWidth = preset['width']!;
    _controller.videoHeight = preset['height']!;
    _controller.targetFps = _selectedFps;
    _controller.bitrateKbps = _selectedBitrate;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Quality'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSettingSection(
              title: 'Screen Capture Resolution',
              subtitle: 'Affects capture detail and rendering performance.',
              child: DropdownButtonFormField<String>(
                initialValue: _selectedPreset,
                dropdownColor: AppTheme.surfaceLight,
                items: AppConstants.videoPresets.keys.map((name) {
                  return DropdownMenuItem(
                    value: name,
                    child: Text(name, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedPreset = val);
                    _saveSettings();
                  }
                },
              ),
            ),

            const SizedBox(height: 20),

            _buildSettingSection(
              title: 'Target Frame Rate (FPS)',
              subtitle: 'Higher FPS requires stronger Wi-Fi connection.',
              child: Row(
                children: [15, 30, 60].map((fps) {
                  final isSelected = _selectedFps == fps;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isSelected ? AppTheme.primaryCyan.withValues(alpha: 0.2) : AppTheme.surfaceLight,
                          side: BorderSide(
                            color: isSelected ? AppTheme.primaryCyan : AppTheme.surfaceBorder,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        onPressed: () {
                          setState(() => _selectedFps = fps);
                          _saveSettings();
                        },
                        child: Text('$fps FPS', style: TextStyle(
                          color: isSelected ? AppTheme.primaryCyan : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        )),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            _buildSettingSection(
              title: 'Max Bitrate',
              subtitle: 'Cap network bandwidth per stream.',
              child: DropdownButtonFormField<int>(
                initialValue: _selectedBitrate,
                dropdownColor: AppTheme.surfaceLight,
                items: const [
                  DropdownMenuItem(value: 1500, child: Text('1.5 Mbps (Balanced)')),
                  DropdownMenuItem(value: 2500, child: Text('2.5 Mbps (Recommended)')),
                  DropdownMenuItem(value: 5000, child: Text('5.0 Mbps (Ultra Crisp)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedBitrate = val);
                    _saveSettings();
                  }
                },
              ),
            ),

            _buildSettingSection(
              title: 'Mirroring Network Mode',
              subtitle: 'Select whether to mirror over the Internet or local Wi-Fi router.',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppTheme.primaryCyan,
                title: Text(
                  _controller.useInternetMode
                      ? 'Internet Cloud Mode (Active)'
                      : 'Local LAN Offline Mode',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _controller.useInternetMode
                      ? 'Connects anywhere over cellular 4G/5G or separate Wi-Fi networks via 6-digit Room Codes.'
                      : 'Requires both devices to share the exact same Wi-Fi router (offline mode).',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                value: _controller.useInternetMode,
                onChanged: (val) {
                  setState(() {
                    _controller.useInternetMode = val;
                  });
                },
              ),
            ),

            const SizedBox(height: 24),

            _buildAboutCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSection({
    required String title,
    required String subtitle,
    required Widget child,
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
          Text(
            title,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'About ViziLink Security Lab',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'Version: ${AppConstants.appVersion}\n'
            'Architecture: Android MediaProjection + WebRTC Native P2P\n'
            'Signaling: Embedded Local WebSocket Server\n'
            'License: Educational / Research Security Prototype',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}
