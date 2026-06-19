import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/user_session.dart';
import '../services/notification_service.dart';
import 'package:geolocator/geolocator.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
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
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Ô mẫu (Plots)'),
            Tab(text: 'Dữ liệu cây'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inventory_fab',
        onPressed: () => _showAddTreeSheet(context),
        backgroundColor: AppTheme.accent,
        foregroundColor: AppTheme.background,
        icon: const Icon(Icons.add),
        label: const Text('Thêm dữ liệu cây',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _PlotsTab(onAddTree: () => _showAddTreeSheet(context)),
          _TreeDataTab(onDelete: _confirmDeleteTree),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTree(
      BuildContext context, String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa dữ liệu cây?',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        content: const Text(
            'Bản ghi cây này sẽ bị xóa vĩnh viễn và không thể khôi phục.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('inventory_trees')
            .doc(docId)
            .delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Đã xóa dữ liệu cây'),
              backgroundColor: AppTheme.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Lỗi xóa: $e'),
                backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  void _showAddTreeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => const _AddTreeSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB: Ô MẪU (PLOTS)
// ─────────────────────────────────────────────────────────────
class _PlotsTab extends StatelessWidget {
  final VoidCallback onAddTree;
  const _PlotsTab({required this.onAddTree});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inventory_plots')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.accent));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Lỗi tải dữ liệu: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.danger)),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('Chưa có ô mẫu nào.',
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }

        final plots = docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return _PlotItem(
            id: doc.id,
            plotCode: d['code'] ?? d['plotCode'] ?? '—',
            project: d['project'] ?? d['projectName'] ?? '—',
            area: (d['area'] as num?)?.toDouble() ?? 0.0,
            latitude: (d['latitude'] as num?)?.toDouble() ?? 0.0,
            longitude: (d['longitude'] as num?)?.toDouble() ?? 0.0,
            elevation: (d['elevation'] as num?)?.toDouble() ?? 0.0,
            status: d['status'] ?? 'Draft',
          );
        }).toList();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: plots.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _PlotCard(plot: plots[i]),
        );
      },
    );
  }
}

class _PlotItem {
  final String id;
  final String plotCode;
  final String project;
  final double area;
  final double latitude;
  final double longitude;
  final double elevation;
  final String status;
  _PlotItem({
    required this.id,
    required this.plotCode,
    required this.project,
    required this.area,
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.status,
  });
}

class _PlotCard extends StatelessWidget {
  final _PlotItem plot;
  const _PlotCard({required this.plot});

  @override
  Widget build(BuildContext context) {
    final isDraft = plot.status.toLowerCase() == 'draft';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.grid_on,
                    color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plot.plotCode,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    Text(plot.project,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDraft
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDraft
                        ? const Color(0xFFFF9800)
                        : const Color(0xFF4CAF50),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  plot.status,
                  style: TextStyle(
                    color: isDraft
                        ? const Color(0xFFE65100)
                        : const Color(0xFF2E7D32),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Details row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(
                icon: Icons.square_foot,
                label: 'Diện tích',
                value: '${plot.area.toStringAsFixed(0)} m²',
              ),
              _InfoChip(
                icon: Icons.location_on_outlined,
                label: 'Lat',
                value: plot.latitude.toStringAsFixed(6),
              ),
              _InfoChip(
                icon: Icons.location_on_outlined,
                label: 'Lng',
                value: plot.longitude.toStringAsFixed(6),
              ),
              _InfoChip(
                icon: Icons.terrain_outlined,
                label: 'Cao độ',
                value: '${plot.elevation.toStringAsFixed(0)} m',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _updateLocation(context, plot),
              icon: const Icon(Icons.my_location, size: 16),
              label: const Text('Cập nhật vị trí GPS', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent,
                side: const BorderSide(color: AppTheme.accent, width: 0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateLocation(BuildContext context, _PlotItem plot) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vui lòng bật GPS', style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.warning));
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đang lấy tọa độ GPS...', style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.info));
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      await FirebaseFirestore.instance
          .collection('inventory_plots')
          .doc(plot.id)
          .update({
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      await NotificationService().pushPlotLocationUpdate(
        project: plot.project,
        plotCode: plot.plotCode,
        docId: plot.id,
        lat: position.latitude,
        lng: position.longitude,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Cập nhật vị trí thành công!', style: TextStyle(color: Colors.white)),
                backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e', style: const TextStyle(color: Colors.white)), backgroundColor: AppTheme.danger));
      }
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text('$label: ',
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB: DỮ LIỆU CÂY
// ─────────────────────────────────────────────────────────────
class _TreeDataTab extends StatefulWidget {
  final Future<void> Function(BuildContext, String) onDelete;
  const _TreeDataTab({required this.onDelete});

  @override
  State<_TreeDataTab> createState() => _TreeDataTabState();
}

class _TreeDataTabState extends State<_TreeDataTab> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search & filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm dữ liệu cây...',
                    hintStyle:
                        const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search,
                        color: AppTheme.textMuted, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Icon(Icons.close,
                                color: AppTheme.textMuted, size: 16))
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: AppTheme.cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppTheme.border, width: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppTheme.border, width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppTheme.accent, width: 1),
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Table header
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Expanded(
                  flex: 3,
                  child: Text('Mã ô mẫu',
                      style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600))),
              Expanded(
                  flex: 3,
                  child: Text('Loài cây',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600))),
              Expanded(
                  flex: 2,
                  child: Text('DBH (cm)',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('Cao (m)',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('SL cây',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center)),
              SizedBox(width: 32),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Tree list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('inventory_trees')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.accent));
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Lỗi: ${snapshot.error}',
                        style:
                            const TextStyle(color: AppTheme.danger)));
              }

              List<TreeRecord> trees = [];
              if (snapshot.hasData) {
                trees = snapshot.data!.docs.map((doc) {
                  return TreeRecord.fromFirestore(
                      doc.data() as Map<String, dynamic>, doc.id);
                }).toList();
                trees.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              }

              // Filter by search
              if (_searchQuery.isNotEmpty) {
                trees = trees.where((t) {
                  return t.plotCode.toLowerCase().contains(_searchQuery) ||
                      t.species.toLowerCase().contains(_searchQuery) ||
                      t.project.toLowerCase().contains(_searchQuery);
                }).toList();
              }

              if (trees.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco_outlined,
                          color: AppTheme.textMuted.withValues(alpha: 0.5),
                          size: 48),
                      const SizedBox(height: 12),
                      const Text('Không có dữ liệu cây',
                          style:
                              TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: trees.length,
                itemBuilder: (_, i) => _TreeRow(
                  record: trees[i],
                  onDelete: () =>
                      widget.onDelete(context, trees[i].id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TreeRow extends StatelessWidget {
  final TreeRecord record;
  final VoidCallback onDelete;
  const _TreeRow({required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: AppTheme.danger, size: 20),
            SizedBox(width: 4),
            Text('Xóa',
                style: TextStyle(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Row(
          children: [
            // Plot Code (clickable/highlighted like web admin)
            Expanded(
              flex: 3,
              child: Text(
                record.plotCode,
                style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
            // Species
            Expanded(
              flex: 3,
              child: Text(
                record.species,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // DBH
            Expanded(
              flex: 2,
              child: Text(
                record.dbhCm.toStringAsFixed(0),
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            // Height
            Expanded(
              flex: 2,
              child: Text(
                record.heightM.toStringAsFixed(0),
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            // Quantity
            Expanded(
              flex: 2,
              child: Text(
                '${record.quantity} cây',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
            // Delete button
            GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.delete_outline,
                    color: AppTheme.danger, size: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTTOM SHEET: THÊM DỮ LIỆU CÂY
// ─────────────────────────────────────────────────────────────
class _AddTreeSheet extends StatefulWidget {
  const _AddTreeSheet();

  @override
  State<_AddTreeSheet> createState() => _AddTreeSheetState();
}

class _AddTreeSheetState extends State<_AddTreeSheet> {
  final _speciesCtrl = TextEditingController();
  final _dbhCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');

  String? _selectedProjectId;
  String? _selectedProjectName;
  String? _selectedPlotId;
  String? _selectedPlotCode;

  List<Map<String, String>> _projects = [];
  List<Map<String, String>> _plots = [];
  bool _loadingProjects = true;
  bool _loadingPlots = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _speciesCtrl.dispose();
    _dbhCtrl.dispose();
    _heightCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    final snap = await FirebaseFirestore.instance
        .collection('forest_projects')
        .where('ownerUid', isEqualTo: UserSession().ownerId)
        .where('workerUids', arrayContains: UserSession().uid)
        .get();
    final list = snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'name': (data['projectName'] ?? data['name'] ?? 'Không rõ').toString(),
      };
    }).toList();
    if (mounted) {
      setState(() {
        _projects = list;
        _loadingProjects = false;
        if (list.isNotEmpty) {
          _selectedProjectId = list.first['id'];
          _selectedProjectName = list.first['name'];
          _loadPlots(list.first['id']!);
        }
      });
    }
  }

  Future<void> _loadPlots(String projectId) async {
    setState(() {
      _loadingPlots = true;
      _selectedPlotId = null;
      _selectedPlotCode = null;
      _plots = [];
    });
    final snap = await FirebaseFirestore.instance
        .collection('inventory_plots')
        .where('projectId', isEqualTo: projectId)
        .get();

    // Nếu lưu theo tên dự án thay vì ID, thử filter theo tên
    List<QueryDocumentSnapshot> docs = snap.docs;
    if (docs.isEmpty && _selectedProjectName != null) {
      final snap2 = await FirebaseFirestore.instance
          .collection('inventory_plots')
          .where('project', isEqualTo: _selectedProjectName)
          .get();
      docs = snap2.docs;
    }

    final list = docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return {
        'id': d.id,
        'code': (data['code'] ?? data['plotCode'] ?? '—').toString(),
      };
    }).toList();

    if (mounted) {
      setState(() {
        _plots = list;
        _loadingPlots = false;
        if (list.isNotEmpty) {
          _selectedPlotId = list.first['id'];
          _selectedPlotCode = list.first['code'];
        }
      });
    }
  }

  Future<void> _save() async {
    if (_selectedProjectId == null ||
        _selectedPlotId == null ||
        _speciesCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vui lòng chọn đủ Dự án, Ô mẫu và nhập Loài cây'),
          backgroundColor: AppTheme.warning));
      return;
    }

    setState(() => _saving = true);
    try {
      final docRef = await FirebaseFirestore.instance.collection('inventory_trees').add({
        'plotId': _selectedPlotId,
        'plotCode': _selectedPlotCode,
        'projectId': _selectedProjectId,
        'project': _selectedProjectName,
        'species': _speciesCtrl.text.trim(),
        'dbh': double.tryParse(_dbhCtrl.text) ?? 0.0,
        'height': double.tryParse(_heightCtrl.text) ?? 0.0,
        'quantity': int.tryParse(_qtyCtrl.text) ?? 1,
        'createdBy': UserSession().uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Gửi thông báo lên web admin
      await NotificationService().pushTreeData(
        project: _selectedProjectName ?? '',
        plotCode: _selectedPlotCode ?? '',
        species: _speciesCtrl.text.trim(),
        quantity: int.tryParse(_qtyCtrl.text) ?? 1,
        docId: docRef.id,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã lưu dữ liệu cây!'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Thêm dữ liệu cây',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            const SizedBox(height: 16),

            // Dự án dropdown
            if (_loadingProjects)
              const SizedBox(
                  height: 48,
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.accent, strokeWidth: 2)))
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedProjectId,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                    labelText: 'Dự án',
                    prefixIcon: Icon(Icons.forest_outlined)),
                items: _projects
                    .map((p) => DropdownMenuItem(
                        value: p['id'],
                        child: Text(p['name']!,
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final proj =
                      _projects.firstWhere((p) => p['id'] == v);
                  setState(() {
                    _selectedProjectId = v;
                    _selectedProjectName = proj['name'];
                  });
                  _loadPlots(v);
                },
              ),

            const SizedBox(height: 12),

            // Ô mẫu dropdown
            if (_loadingPlots)
              const SizedBox(
                  height: 48,
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.accent, strokeWidth: 2)))
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedPlotId,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                    labelText: 'Ô mẫu (Plot)',
                    prefixIcon: Icon(Icons.grid_on)),
                hint: const Text('Chọn ô mẫu',
                    style: TextStyle(
                        color: AppTheme.textMuted, fontSize: 13)),
                items: _plots
                    .map((p) => DropdownMenuItem(
                        value: p['id'], child: Text(p['code']!)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final plot =
                      _plots.firstWhere((p) => p['id'] == v);
                  setState(() {
                    _selectedPlotId = v;
                    _selectedPlotCode = plot['code'];
                  });
                },
              ),

            const SizedBox(height: 12),

            // Loài cây
            TextFormField(
              controller: _speciesCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                  labelText: 'Loài cây',
                  prefixIcon: Icon(Icons.eco_outlined)),
            ),
            const SizedBox(height: 12),

            // DBH + Height
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _dbhCtrl,
                  keyboardType: TextInputType.number,
                  style:
                      const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                      labelText: 'DBH (cm)',
                      prefixIcon: Icon(Icons.straighten)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  style:
                      const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                      labelText: 'Chiều cao (m)',
                      prefixIcon: Icon(Icons.height)),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Số lượng
            TextFormField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                  labelText: 'Số lượng cây',
                  prefixIcon: Icon(Icons.numbers)),
            ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Lưu dữ liệu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
