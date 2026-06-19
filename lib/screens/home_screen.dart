import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../models/models.dart';
import '../widgets/stat_card.dart';
import '../services/user_session.dart';
import '../widgets/activity_tile.dart';
import '../widgets/section_header.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'main_shell.dart';
import 'new_logbook_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                _buildOnlineStatus(),
                const SizedBox(height: 20),
                _buildStatsGrid(context),
                const SizedBox(height: 24),
                _buildQuickActions(context),
                const SizedBox(height: 24),
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
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          tooltip: 'Thông báo',
          onPressed: () => _showNotificationsDialog(context),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // Hiển thị dialog Thông báo
  static void _showNotificationsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
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
              _NotificationItem(
                icon: Icons.cloud_done_outlined,
                color: AppTheme.success,
                title: 'Đồng bộ hoàn tất',
                subtitle: 'Tất cả nhật ký đã được đồng bộ lên cloud',
                time: 'Vừa xong',
              ),
              const SizedBox(height: 10),
              _NotificationItem(
                icon: Icons.warning_amber_rounded,
                color: AppTheme.warning,
                title: 'Nhắc nhở tuần tra',
                subtitle: 'Khu vực Đắk Lắk chưa được kiểm tra hôm nay',
                time: '2 giờ trước',
              ),
              const SizedBox(height: 10),
              _NotificationItem(
                icon: Icons.info_outline,
                color: AppTheme.info,
                title: 'Cập nhật hệ thống',
                subtitle: 'Phiên bản mới v1.1.0 đã sẵn sàng',
                time: 'Hôm qua',
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

  Widget _buildOnlineStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.success,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [BoxShadow(color: AppTheme.success.withOpacity(0.4), blurRadius: 6, spreadRadius: 2)],
            ),
          ),
          const SizedBox(width: 8),
          const Text('Đang kết nối', style: TextStyle(color: AppTheme.success, fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          const Icon(Icons.wifi, color: AppTheme.accent, size: 16),
          const SizedBox(width: 4),
          const Text('Online', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: Future.wait([
        FirebaseFirestore.instance.collection('forest_projects').where('ownerUid', isEqualTo: UserSession().ownerId).count().get().then((res) => res.count ?? 0),
        FirebaseFirestore.instance.collection('logbook_activities').where('user', isEqualTo: UserSession().uid).count().get().then((res) => res.count ?? 0),
        FirebaseFirestore.instance.collection('logbook_activities').where('user', isEqualTo: UserSession().uid).where('synced', isEqualTo: false).count().get().then((res) => res.count ?? 0),
        FirebaseFirestore.instance.collection('checkins').where('createdBy', isEqualTo: UserSession().uid).count().get().then((res) => res.count ?? 0),
      ]),
      builder: (context, snapshot) {
        final data = snapshot.data ?? [0, 0, 0, 0];
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
              value: data[0].toString(), 
              icon: Icons.folder_outlined, 
              color: AppTheme.accent,
              onTap: () => MainShellState.of(context)?.switchTab(3), // Điều tra
            ),
            StatCard(
              label: 'Tổng nhật ký', 
              value: data[1].toString(), 
              icon: Icons.edit_note, 
              color: AppTheme.info,
              onTap: () => MainShellState.of(context)?.switchTab(2), // Nhật ký
            ),
            StatCard(
              label: 'Chưa đồng bộ', 
              value: data[2].toString(), 
              icon: Icons.cloud_off_outlined, 
              color: AppTheme.warning,
              onTap: () => MainShellState.of(context)?.switchTab(2), // Nhật ký
            ),
            StatCard(
              label: 'Số lần Check-in', 
              value: data[3].toString(), 
              icon: Icons.location_on_outlined, 
              color: AppTheme.success,
              onTap: () => MainShellState.of(context)?.switchTab(1), // Check-in
            ),
          ],
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
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.camera_alt_outlined,
                label: 'Chụp ảnh',
                color: AppTheme.warning,
                onTap: () => _quickTakePhoto(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Chụp ảnh nhanh → thử camera trước, nếu không khả dụng thì mở gallery
  static Future<void> _quickTakePhoto(BuildContext context) async {
    final picker = ImagePicker();
    XFile? photo;

    try {
      photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 50,
      );
    } catch (_) {
      // Camera không khả dụng → fallback gallery
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera không khả dụng, mở thư viện ảnh...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      await Future.delayed(const Duration(milliseconds: 600));
      try {
        photo = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 50,
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi mở ảnh: $e'), backgroundColor: AppTheme.danger),
          );
        }
        return;
      }
    }

    if (photo == null) return;

    try {
      if (!context.mounted) return;
      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOffline = connectivityResult == ConnectivityResult.none;

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              const SizedBox(width: 12),
              Text(isOffline ? 'Đang lưu ảnh cục bộ...' : 'Đang tải ảnh lên...'),
            ],
          ),
          backgroundColor: AppTheme.primaryLight,
          duration: const Duration(seconds: 10),
        ),
      );

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'quick_photo_$timestamp.jpg';
      final Uint8List bytes = await photo.readAsBytes();
      final String storagePath = 'logbook_photos/$fileName';
      
      String? downloadUrl;
      String? localPath;

      if (isOffline) {
        // Lưu cục bộ
        final dir = await getApplicationDocumentsDirectory();
        final localFile = File('${dir.path}/$fileName');
        await localFile.writeAsBytes(bytes);
        localPath = localFile.path;
      } else {
        // Upload lên Storage
        final storageRef = FirebaseStorage.instance.ref();
        final imageRef = storageRef.child(storagePath);
        await imageRef.putData(bytes);
        downloadUrl = await imageRef.getDownloadURL();
      }

      // Lấy vị trí GPS thực (nếu có)
      double lat = 0;
      double lng = 0;
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) {
            perm = await Geolocator.requestPermission();
          }
          if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
            Position pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            lat = pos.latitude;
            lng = pos.longitude;
          }
        }
      } catch (_) {}

      final docRef = FirebaseFirestore.instance.collection('quick_photos').doc();
      final dataToSave = {
        'url': downloadUrl,
        'localPath': localPath,
        'storagePath': storagePath,
        'fileName': fileName,
        'location': {'lat': lat, 'lng': lng},
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'synced': !isOffline,
        'createdBy': UserSession().uid,
      };

      if (isOffline) {
        docRef.set(dataToSave);
      } else {
        await docRef.set(dataToSave);
      }

      if (!context.mounted) return;
      
      final msg = isOffline 
          ? 'Đã lưu ngoại tuyến! Sẽ tự động đồng bộ khi có mạng.'
          : 'Đã tải ảnh lên hệ thống thành công!';
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          backgroundColor: isOffline ? AppTheme.warning : AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
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
