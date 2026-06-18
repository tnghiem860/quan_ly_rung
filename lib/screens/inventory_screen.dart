import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/user_session.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;



  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Điều tra rừng'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.accentLight,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.accent,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Ô mẫu (Plots)'),
            Tab(text: 'Dữ liệu cây'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTreeSheet(context),
        backgroundColor: AppTheme.accent,
        foregroundColor: AppTheme.background,
        icon: const Icon(Icons.add),
        label: const Text('Thêm dữ liệu', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inventory_trees')
            .where('createdBy', isEqualTo: UserSession().uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Lỗi tải dữ liệu: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.danger)),
              ),
            );
          }

          List<TreeRecord> trees = [];
          if (snapshot.hasData) {
            trees = snapshot.data!.docs.map((doc) {
              return TreeRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
            }).toList();
            
            // Sắp xếp local để tránh lỗi thiếu Composite Index của Firestore
            trees.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          }

          if (trees.isEmpty) {
            return const Center(
              child: Text('Chưa có dữ liệu cây nào.', style: TextStyle(color: AppTheme.textSecondary)),
            );
          }

          return TabBarView(
            controller: _tabCtrl,
            children: [
              _buildPlotsTab(trees),
              _buildTreeDataTab(trees),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlotsTab(List<TreeRecord> trees) {
    final plots = trees.map((t) => t.plotCode).toSet().toList();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: plots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final plot = plots[i];
        final plotTrees = trees.where((t) => t.plotCode == plot).toList();
        final totalQty = plotTrees.fold(0, (s, t) => s + t.quantity);
        return _PlotCard(
          plotCode: plot,
          project: plotTrees.first.project,
          speciesCount: plotTrees.length,
          totalTrees: totalQty,
          onTap: () => _showPlotDetail(context, plot, plotTrees),
        );
      },
    );
  }

  Widget _buildTreeDataTab(List<TreeRecord> trees) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: trees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TreeDataCard(
        record: trees[i],
        onDelete: () => _confirmDeleteTree(context, trees[i].id),
      ),
    );
  }

  Future<void> _confirmDeleteTree(BuildContext context, String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa dữ liệu cây?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        content: const Text('Bản ghi cây này sẽ bị xóa vĩnh viễn và không thể khôi phục.', style: TextStyle(color: AppTheme.textSecondary)),
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
        await FirebaseFirestore.instance.collection('inventory_trees').doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Đã xóa dữ liệu cây'),
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

  void _showPlotDetail(BuildContext context, String plotCode, List<TreeRecord> trees) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scroll) => Column(
          children: [
            Container(
              width: 36, height: 3,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.grid_on, color: AppTheme.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(plotCode, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                itemCount: trees.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _TreeDataCard(record: trees[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTreeSheet(BuildContext context) {
    final plotCodeCtrl = TextEditingController();
    final speciesCtrl = TextEditingController();
    final dbhCtrl = TextEditingController();
    final heightCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String? selectedProject;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 36, height: 3, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
                const Text('Thêm dữ liệu cây', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 16),
                
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance.collection('forest_projects').where('ownerId', isEqualTo: UserSession().ownerId).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(color: AppTheme.accent)));
                    final projects = snapshot.data!.docs.map((d) => ForestProject.fromFirestore(d.data() as Map<String, dynamic>, d.id).name).toList();
                    if (projects.isNotEmpty && selectedProject == null) {
                      selectedProject = projects.first;
                    }
                    return DropdownButtonFormField<String>(
                      value: selectedProject,
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(labelText: 'Dự án', prefixIcon: Icon(Icons.forest_outlined)),
                      items: projects.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (v) => setModalState(() => selectedProject = v),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(controller: plotCodeCtrl, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(labelText: 'Mã ô mẫu (VD: PLOT-01)', prefixIcon: Icon(Icons.grid_on))),
                const SizedBox(height: 12),
                TextFormField(controller: speciesCtrl, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(labelText: 'Loài cây', prefixIcon: Icon(Icons.eco_outlined))),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: dbhCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(labelText: 'DBH (cm)', prefixIcon: Icon(Icons.straighten)))),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: heightCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(labelText: 'Chiều cao (m)', prefixIcon: Icon(Icons.height)))),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: qtyCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(labelText: 'Số lượng cây', prefixIcon: Icon(Icons.numbers))),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedProject == null || plotCodeCtrl.text.isEmpty || speciesCtrl.text.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đủ thông tin (Dự án, Ô mẫu, Loài cây)'), backgroundColor: AppTheme.warning));
                       return;
                    }
                    
                    try {
                      final plotCode = plotCodeCtrl.text.trim();
                      final db = FirebaseFirestore.instance;
                      
                      String plotId = '';
                      final plotSnap = await db.collection('inventory_plots')
                        .where('code', isEqualTo: plotCode)
                        .where('project', isEqualTo: selectedProject)
                        .limit(1)
                        .get();
                        
                      if (plotSnap.docs.isEmpty) {
                         final plotRef = await db.collection('inventory_plots').add({
                           'code': plotCode,
                           'project': selectedProject,
                           'area': 0.0,
                           'latitude': 0.0,
                           'longitude': 0.0,
                           'elevation': 0.0,
                           'status': 'Draft',
                           'createdAt': FieldValue.serverTimestamp(),
                         });
                         plotId = plotRef.id;
                      } else {
                         plotId = plotSnap.docs.first.id;
                      }

                      await db.collection('inventory_trees').add({
                        'plotId': plotId,
                        'plotCode': plotCode,
                        'project': selectedProject,
                        'species': speciesCtrl.text.trim(),
                        'dbh': double.tryParse(dbhCtrl.text) ?? 0.0,
                        'height': double.tryParse(heightCtrl.text) ?? 0.0,
                        'quantity': int.tryParse(qtyCtrl.text) ?? 1,
                        'createdBy': UserSession().uid,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Đã lưu dữ liệu cây!'), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        );
                      }
                    } catch (e) {
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.danger));
                       }
                    }
                  },
                  child: const Text('Lưu dữ liệu'),
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}

class _PlotCard extends StatelessWidget {
  final String plotCode;
  final String project;
  final int speciesCount;
  final int totalTrees;
  final VoidCallback onTap;

  const _PlotCard({
    required this.plotCode,
    required this.project,
    required this.speciesCount,
    required this.totalTrees,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.grid_on, color: AppTheme.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plotCode, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(project, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$speciesCount loài', style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w500)),
                Text('$totalTrees cây', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TreeDataCard extends StatelessWidget {
  final TreeRecord record;
  final VoidCallback? onDelete;
  const _TreeDataCard({required this.record, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      onLongPress: onDelete,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.eco, color: AppTheme.accent, size: 16),
                const SizedBox(width: 6),
                Text(record.species, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(record.plotCode, style: const TextStyle(color: AppTheme.accent, fontSize: 11)),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 16),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _DataChip(label: 'DBH', value: '${record.dbhCm} cm'),
                const SizedBox(width: 8),
                _DataChip(label: 'Cao', value: '${record.heightM} m'),
                const SizedBox(width: 8),
                _DataChip(label: 'Số lượng', value: '${record.quantity} cây'),
              ],
            ),
          ],
        ),
      ),
    );

    if (onDelete == null) return card;

    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete!();
        return false;
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
      child: card,
    );
  }
}

class _DataChip extends StatelessWidget {
  final String label;
  final String value;
  const _DataChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          const SizedBox(height: 1),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
