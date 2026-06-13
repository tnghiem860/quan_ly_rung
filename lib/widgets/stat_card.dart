import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';

// ── StatCard ──────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w700, height: 1),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── ActivityTile ──────────────────────────────────────────────────────────────
class ActivityTile extends StatelessWidget {
  final LogbookEntry entry;
  final bool expanded;

  const ActivityTile({super.key, required this.entry, this.expanded = false});

  Color get _activityColor {
    switch (entry.activityType) {
      case 'Trồng cây': return AppTheme.success;
      case 'Chăm sóc cây': return AppTheme.info;
      case 'Bón phân': return AppTheme.warning;
      case 'Kiểm tra sinh trưởng': return AppTheme.accentLight;
      case 'Tuần tra': return const Color(0xFF9B8ECC);
      case 'Phòng cháy chữa cháy': return AppTheme.danger;
      default: return AppTheme.accent;
    }
  }

  IconData get _activityIcon {
    switch (entry.activityType) {
      case 'Trồng cây': return Icons.eco;
      case 'Chăm sóc cây': return Icons.favorite_outline;
      case 'Bón phân': return Icons.science_outlined;
      case 'Kiểm tra sinh trưởng': return Icons.monitor_heart_outlined;
      case 'Tuần tra': return Icons.security_outlined;
      case 'Phòng cháy chữa cháy': return Icons.local_fire_department_outlined;
      default: return Icons.edit_note;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inHours < 24) return '${diff.inHours}h trước';
    if (diff.inDays == 1) return 'Hôm qua';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _activityColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_activityIcon, color: _activityColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.activityType,
                        style: TextStyle(color: _activityColor, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (!entry.synced)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Chưa sync', style: TextStyle(color: AppTheme.warning, fontSize: 9)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  entry.description,
                  maxLines: expanded ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.folder_outlined, size: 11, color: AppTheme.textMuted),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        entry.project,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(_formatDate(entry.date), style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
                if (expanded && entry.photos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.photo_library_outlined, size: 11, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text('${entry.photos.length} hình ảnh', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── SectionHeader ─────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }
}
