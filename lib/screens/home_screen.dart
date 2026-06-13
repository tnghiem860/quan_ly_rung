import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../main.dart';
import '../models/models.dart';
import '../widgets/stat_card.dart';
import '../services/user_session.dart';
import '../widgets/activity_tile.dart';
import '../widgets/section_header.dart';
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
                      .collection('logbooks')
                      .orderBy('timestamp', descending: true)
                      .limit(5)
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
                    return Column(
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final entry = LogbookEntry.fromFirestore(data, doc.id);
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
      expandedHeight: 120,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppTheme.primary,
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc('user_001').snapshots(),
            builder: (context, snapshot) {
              String name = '...';
              String initials = 'TB';
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                name = data['name'] ?? 'Không rõ';
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
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Xin chào, $name',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getFormattedDate(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Stack(
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
                ],
              );
            },
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.forest, color: AppTheme.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              'Forest Worker',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        titlePadding: const EdgeInsets.fromLTRB(16, 0, 0, 14),
        collapseMode: CollapseMode.pin,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {},
        ),
        const SizedBox(width: 4),
      ],
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
        FirebaseFirestore.instance.collection('projects').count().get().then((res) => res.count ?? 0),
        FirebaseFirestore.instance.collection('logbooks').count().get().then((res) => res.count ?? 0),
        FirebaseFirestore.instance.collection('logbooks').where('synced', isEqualTo: false).count().get().then((res) => res.count ?? 0),
        FirebaseFirestore.instance.collection('checkins').count().get().then((res) => res.count ?? 0),
      ]),
      builder: (context, snapshot) {
        final data = snapshot.data ?? [0, 0, 0, 0];
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            StatCard(label: 'Dự án', value: data[0].toString(), icon: Icons.folder_outlined, color: AppTheme.accent),
            StatCard(label: 'Tổng nhật ký', value: data[1].toString(), icon: Icons.edit_note, color: AppTheme.info),
            StatCard(label: 'Chưa đồng bộ', value: data[2].toString(), icon: Icons.cloud_off_outlined, color: AppTheme.warning),
            StatCard(label: 'Số lần Check-in', value: data[3].toString(), icon: Icons.location_on_outlined, color: AppTheme.success),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Đang tải ảnh lên...'),
            ],
          ),
          backgroundColor: AppTheme.primaryLight,
          duration: const Duration(seconds: 10),
        ),
      );

      // Mã hoá ảnh sang base64
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'quick_photo_$timestamp.jpg';
      final Uint8List bytes = await photo.readAsBytes();
      final String base64String = base64Encode(bytes);
      final String base64Data = 'data:image/jpeg;base64,$base64String';

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

      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOffline = connectivityResult == ConnectivityResult.none;

      final docRef = FirebaseFirestore.instance.collection('quick_photos').doc();
      final dataToSave = {
        'url': base64Data,
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
