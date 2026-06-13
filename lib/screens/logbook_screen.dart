import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
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
  final _filters = ['Tất cả', ...activityTypes];

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('logbooks').orderBy('timestamp', descending: true);
    if (_filter != 'Tất cả') {
      query = query.where('activity', isEqualTo: _filter);
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
                  itemBuilder: (_, i) => ActivityTile(entry: logs[i], expanded: true),
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
              selectedColor: AppTheme.accent.withOpacity(0.2),
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
}
