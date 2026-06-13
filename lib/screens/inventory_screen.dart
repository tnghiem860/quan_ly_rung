import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final List<TreeRecord> _trees = [
    TreeRecord(plotCode: 'FLT-0001', species: 'Keo Lai', dbhCm: 18, heightM: 12, quantity: 150, project: 'Dak Lak Project 01'),
    TreeRecord(plotCode: 'FLT-0002', species: 'Bạch Đàn', dbhCm: 15, heightM: 10, quantity: 200, project: 'Lam Dong Project 02'),
    TreeRecord(plotCode: 'FLT-0003', species: 'Thông', dbhCm: 22, heightM: 15, quantity: 120, project: 'Gia Lai Project 01'),
    TreeRecord(plotCode: 'FLT-0001', species: 'Keo Lá Tràm', dbhCm: 16, heightM: 11, quantity: 80, project: 'Dak Lak Project 01'),
  ];

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
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildPlotsTab(),
          _buildTreeDataTab(),
        ],
      ),
    );
  }

  Widget _buildPlotsTab() {
    final plots = _trees.map((t) => t.plotCode).toSet().toList();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: plots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final plot = plots[i];
        final plotTrees = _trees.where((t) => t.plotCode == plot).toList();
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

  Widget _buildTreeDataTab() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: _trees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TreeDataCard(record: _trees[i]),
    );
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
    final speciesCtrl = TextEditingController();
    final dbhCtrl = TextEditingController();
    final heightCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 36, height: 3, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            const Text('Thêm dữ liệu cây', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 16),
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
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text('Đã lưu dữ liệu cây!'), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                );
              },
              child: const Text('Lưu dữ liệu'),
            ),
          ],
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
              decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
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
  const _TreeDataCard({required this.record});

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              const Icon(Icons.eco, color: AppTheme.accent, size: 16),
              const SizedBox(width: 6),
              Text(record.species, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(record.plotCode, style: const TextStyle(color: AppTheme.accent, fontSize: 11)),
              ),
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
