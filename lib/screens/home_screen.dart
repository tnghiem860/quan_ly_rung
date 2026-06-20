import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../main.dart';
import '../models/models.dart';
import '../widgets/stat_card.dart';
import '../services/user_session.dart';
import '../widgets/activity_tile.dart';
import 'main_shell.dart';
import 'new_logbook_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
  }


  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                // ── [Flowchart 6] Node: "Indicator Online/Offline" ──
                // StreamBuilder lắng nghe Connectivity.onConnectivityChanged
                // Hiển thị ở dạng cây xanh (Online) hoặc đỏ (Offline)
                _buildOnlineStatus(context),
                const SizedBox(height: 20),
                // ── [Flowchart 1] Node: "Dashboard - KPI" ──
                // Thống kê: Dự án, Tổng nhật ký, Chưa đồng bộ, Số lần Check-in
                _buildStatsGrid(context),
                const SizedBox(height: 24),
                // ── [Flowchart 1] Node: "Thác tác nhanh" ──
                // Nút Check-in GPS và Nhật ký mới
                _buildQuickActions(context),
                const SizedBox(height: 24),
                // ── [Flowchart 1] Node: "Hoạt động gần đây" ──
                // Stream 5 nhật ký mới nhất từ Firestore, sắp xếp cục bộ
                const SectionHeader(title: 'Hoạt động gần đây'),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('logbook_activities')
                      .where('user', isEqualTo: UserSession().uid)
                      .snapshots(),
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
                      return const Center(
                        child: Text(
                          'Chưa có hoạt động nào.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    var entries = docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return LogbookEntry.fromFirestore(data, doc.id);
                    }).toList();
                    
                    // Sort locally and limit to 5 to avoid composite index requirements
                    entries.sort((a, b) => b.date.compareTo(a.date));
                    if (entries.length > 5) entries = entries.sublist(0, 5);

                    return Column(
                      children: entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ActivityTile(entry: entry),
                        );
                      }).toList(),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppTheme.primary,
      expandedHeight: 140,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppTheme.primary,
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(UserSession().uid).snapshots(),
            builder: (context, snapshot) {
              String name = '...';
              String initials = 'U';
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                name = data['fullName'] ?? 'Không rõ';
                if (name.isNotEmpty) {
                  final parts = name.split(' ');
                  if (parts.length > 1) {
                    initials = '${parts.first[0]}${parts.last[0]}'.toUpperCase();
                  } else {
                    initials = name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
                  }
                }
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          'Xin chào, $name',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontSize: 20,
                                color: Colors.white,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getFormattedDate(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => MainShellState.of(context)?.switchTab(4),
                    child: Stack(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: AppTheme.background,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppTheme.warning,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.primary, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.forest, color: AppTheme.accentLight, size: 20),
            const SizedBox(width: 8),
            Text(
              'Forest Worker',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.fromLTRB(16, 0, 0, 14),
        collapseMode: CollapseMode.pin,
      ),
      actions: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('recipientIds', arrayContains: UserSession().uid)
              .snapshots(),
          builder: (context, snapshot) {
            bool hasUnread = false;
            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final readBy = List<String>.from(data['readBy'] ?? []);
                if (!readBy.contains(UserSession().uid)) {
                  hasUnread = true;
                  break;
                }
              }
            }

            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  tooltip: 'Thông báo',
                  onPressed: () => _showNotificationsDialog(context),
                ),
                if (hasUnread)
                  Positioned(
                    right: 8,
                    top: 12,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primary, width: 1.5),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  static void _showNotificationsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Thông báo', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('recipientIds', arrayContains: UserSession().uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: AppTheme.danger)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Không có thông báo nào.', style: TextStyle(color: AppTheme.textSecondary)));
                    }

                    final docs = snapshot.data!.docs;
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        
                        // Đánh dấu đã đọc khi hiển thị
                        final readBy = List<String>.from(data['readBy'] ?? []);
                        if (!readBy.contains(UserSession().uid)) {
                          doc.reference.update({
                            'readBy': FieldValue.arrayUnion([UserSession().uid])
                          });
                        }

                        final type = data['type'] as String? ?? 'general';
                        IconData icon = Icons.info_outline;
                        Color color = AppTheme.info;

                        if (type == 'new_project') {
                          icon = Icons.folder_special;
                          color = AppTheme.success;
                        } else if (type == 'plot_update') {
                          icon = Icons.edit_location_alt_outlined;
                          color = AppTheme.warning;
                        }

                        String timeStr = '';
                        if (data['createdAt'] != null) {
                          final ts = data['createdAt'] as Timestamp;
                          final date = ts.toDate();
                          timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.day}/${date.month}';
                        }

                        return _NotificationItem(
                          icon: icon,
                          color: color,
                          title: data['title'] ?? 'Thông báo',
                          subtitle: data['message'] ?? '',
                          time: timeStr,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFormattedDate() {

    final now = DateTime.now();
    String weekday = '';
    switch (now.weekday) {
      case 1: weekday = 'Thứ 2'; break;
      case 2: weekday = 'Thứ 3'; break;
      case 3: weekday = 'Thứ 4'; break;
      case 4: weekday = 'Thứ 5'; break;
      case 5: weekday = 'Thứ 6'; break;
      case 6: weekday = 'Thứ 7'; break;
      case 7: weekday = 'Chủ nhật'; break;
    }
    return '$weekday, ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  Widget _buildOnlineStatus(BuildContext context) {
    return StreamBuilder<ConnectivityResult>(
      stream: Connectivity().onConnectivityChanged,
      initialData: _isOnline ? ConnectivityResult.wifi : ConnectivityResult.none,
      builder: (context, snapshot) {
        final result = snapshot.data ?? ConnectivityResult.none;
        final isOnline = result != ConnectivityResult.none;

        // Cập nhật lại state nếu giá trị thay đổi
        if (isOnline != _isOnline) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isOnline = isOnline);
          });
        }

        final dotColor = isOnline ? AppTheme.success : AppTheme.danger;
        final statusText = isOnline ? 'Đang kết nối' : 'Mất kết nối';
        final iconData = isOnline ? Icons.wifi : Icons.wifi_off;
        final iconColor = isOnline ? AppTheme.accent : AppTheme.danger;
        final labelText = isOnline ? 'Online' : 'Offline';
        final labelColor = isOnline ? AppTheme.textSecondary : AppTheme.danger;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isOnline
                ? AppTheme.cardBg
                : AppTheme.danger.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isOnline ? AppTheme.border : AppTheme.danger.withValues(alpha: 0.35),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 2,
                    )
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  statusText,
                  key: ValueKey(statusText),
                  style: TextStyle(
                    color: dotColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(iconData, key: ValueKey(iconData), color: iconColor, size: 16),
              ),
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  labelText,
                  key: ValueKey(labelText),
                  style: TextStyle(color: labelColor, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final uid = UserSession().uid;
    final ownerId = UserSession().ownerId;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('forest_projects').where('ownerUid', isEqualTo: ownerId).where('workerUids', arrayContains: uid).snapshots(),
      builder: (context, projSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('logbook_activities').where('user', isEqualTo: uid).snapshots(),
          builder: (context, logSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('checkins').where('createdBy', isEqualTo: uid).snapshots(),
              builder: (context, checkinSnap) {
                final data0 = projSnap.data?.docs.length ?? 0;
                final data1 = logSnap.data?.docs.length ?? 0;
                int data2 = 0;
                if (logSnap.hasData) {
                  data2 = logSnap.data!.docs.where((d) => (d.data() as Map<String, dynamic>)['synced'] == false).length;
                }
                final data3 = checkinSnap.data?.docs.length ?? 0;

                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    StatCard(
                      label: 'Dự án', 
                      value: data0.toString(), 
                      icon: Icons.folder_outlined, 
                      color: AppTheme.accent,
                      onTap: () => MainShellState.of(context)?.switchTab(3), // Điều tra
                    ),
                    StatCard(
                      label: 'Tổng nhật ký', 
                      value: data1.toString(), 
                      icon: Icons.edit_note, 
                      color: AppTheme.info,
                      onTap: () => MainShellState.of(context)?.switchTab(2), // Nhật ký
                    ),
                    StatCard(
                      label: 'Chưa đồng bộ', 
                      value: data2.toString(), 
                      icon: Icons.cloud_off_outlined, 
                      color: AppTheme.warning,
                      onTap: () => MainShellState.of(context)?.switchTab(2), // Nhật ký
                    ),
                    StatCard(
                      label: 'Số lần Check-in', 
                      value: data3.toString(), 
                      icon: Icons.location_on_outlined, 
                      color: AppTheme.success,
                      onTap: () => MainShellState.of(context)?.switchTab(1), // Check-in
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Thao tác nhanh'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.add_location_alt_outlined,
                label: 'Check-in GPS',
                color: AppTheme.accent,
                onTap: () {
                  // Chuyển sang tab Check-in (index 1) trong MainShell
                  MainShellState.of(context)?.switchTab(1);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.note_add_outlined,
                label: 'Nhật ký mới',
                color: AppTheme.info,
                onTap: () {
                  // Mở màn hình tạo nhật ký mới
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NewLogbookScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget hiển thị mỗi thông báo ────────────────────────────────────────────
class _NotificationItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;

  const _NotificationItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(time, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}
