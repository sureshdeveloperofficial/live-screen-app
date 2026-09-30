import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/stream_stats.dart';

class StatsHud extends StatelessWidget {
  final StreamStats stats;
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;

  const StatsHud({
    super.key,
    required this.stats,
    this.onToggleFullscreen,
    this.isFullscreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatItem('FPS', stats.fps.toStringAsFixed(0), AppTheme.primaryCyan),
          _buildDivider(),
          _buildStatItem('LATENCY', '${stats.latencyMs} ms', AppTheme.accentEmerald),
          _buildDivider(),
          _buildStatItem(
            'BITRATE',
            stats.bitrateKbps >= 1000
                ? '${(stats.bitrateKbps / 1000).toStringAsFixed(1)} Mbps'
                : '${stats.bitrateKbps.toStringAsFixed(0)} kbps',
            AppTheme.accentAmber,
          ),
          _buildDivider(),
          _buildStatItem('NET', stats.connectionType, AppTheme.textSecondary),
          if (onToggleFullscreen != null) ...[
            _buildDivider(),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: AppTheme.primaryCyan,
                size: 20,
              ),
              onPressed: onToggleFullscreen,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: AppTheme.surfaceBorder,
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
  }
}
