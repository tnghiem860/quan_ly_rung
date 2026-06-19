import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../services/user_session.dart';
import '../models/models.dart';
import '../widgets/activity_tile.dart';
import 'new_logbook_screen.dart';

class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key});

  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen> {
  String _filter = 'Tất cả';
  List<String> _filters = ['Tất cả'];
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final actSnap = await FirebaseFirestore.instance.collection('activities').get();
      setState(() {
        _filters = ['Tất cả', ...actSnap.docs.map((doc) => doc['name'] as String)];
        _loadingData = false;
      });
    } catch (e) {
      setState(() => _loadingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    Query query = FirebaseFirestore.instance.collection('logbook_activities')
      .where('user', isEqualTo: UserSession().uid)
      .orderBy('date', descending: true);
      
    if (_filter != 'Tất cả') {
      query = query.where('activityType', isEqualTo: _filter);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Nhật ký hiện trường'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilterSheet),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'logbook_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewLogbookScreen()),
        ),
        backgroundColor: AppTheme.accent,
        foregroundColor: AppTheme.background,
        icon: const Icon(Icons.add),
        label: const Text('Nhật ký mới', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          const Divider(height: 0),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Lỗi tải dữ liệu: ${snapshot.error}',
                      style: const TextStyle(color: AppTheme.danger),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmpty();
                }

                final docs = snapshot.data!.docs;
                final logs = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return LogbookEntry.fromFirestore(data, doc.id);
                }).toList();

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _DismissibleLogTile(
                    entry: logs[i],
                    onDelete: () => _confirmDeleteLog(context, logs[i].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: _filters.map((f) {
          final selected = f == _filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f),
              selected: selected,
              onSelected: (_) => setState(() => _filter = f),
              selectedColor: AppTheme.accent.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: selected ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: selected ? AppTheme.accent : AppTheme.border,
                width: 0.5,
              ),
              backgroundColor: AppTheme.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.book_outlined, size: 56, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text('Chưa có nhật ký', style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 3,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Lọc theo loại công việc',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          ..._filters.map((f) => ListTile(
                title: Text(f, style: const TextStyle(color: AppTheme.textPrimary)),
                trailing: f == _filter ? const Icon(Icons.check, color: AppTheme.accent, size: 18) : null,
                onTap: () {
                  setState(() => _filter = f);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteLog(BuildContext context, String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa nhật ký?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        content: const Text('Nhật ký này sẽ bị xóa vĩnh viễn và không thể khôi phục.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('logbook_activities').doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Đã xóa nhật ký'),
              backgroundColor: AppTheme.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi xóa: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }
}

// ── Widget tile nhật ký với swipe-to-delete ───────────────────────────────────
class _DismissibleLogTile extends StatelessWidget {
  final LogbookEntry entry;
  final VoidCallback onDelete;

  const _DismissibleLogTile({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // Để Firestore xử lý, không dismiss ngay
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3), width: 0.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: AppTheme.danger, size: 22),
            SizedBox(width: 6),
            Text('Xóa', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
      child: GestureDetector(
        onLongPress: onDelete,
        child: ActivityTile(entry: entry, expanded: true),
      ),
    );
  }
}
