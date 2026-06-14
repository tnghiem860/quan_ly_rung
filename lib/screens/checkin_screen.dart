import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/user_session.dart';
import '../widgets/section_header.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  bool _isLocating = false;
  bool _hasLocation = false;
  double? _lat;
  double? _lng;
  String? _selectedProject;
  List<String> _projects = [];
  bool _loadingData = true;
  final _notesCtrl = TextEditingController();
  final MapController _mapController = MapController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final projSnap = await FirebaseFirestore.instance.collection('projects').where('ownerId', isEqualTo: UserSession().ownerId).get();
      setState(() {
        _projects = projSnap.docs.map((doc) => doc['name'] as String).toList();
        if (_projects.isNotEmpty) _selectedProject = _projects.first;
        _loadingData = false;
      });
    } catch (e) {
      setState(() => _loadingData = false);
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Cuộn màn hình xuống phần lịch sử check-in
  void _scrollToHistory(BuildContext context) {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _getLocation() async {
    setState(() => _isLocating = true);

    try {
      // Kiểm tra dịch vụ GPS có bật không
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng bật GPS trên thiết bị')),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      // Kiểm tra và yêu cầu quyền truy cập vị trí
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Quyền truy cập vị trí bị từ chối')),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quyền vị trí bị chặn vĩnh viễn. Vào Cài đặt để cấp quyền.')),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      // Lấy vị trí thực từ GPS
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _isLocating = false;
        _hasLocation = true;
        _lat = position.latitude;
        _lng = position.longitude;
      });

      // Di chuyển bản đồ đến vị trí thực
      try {
        _mapController.move(LatLng(_lat!, _lng!), 15.0);
      } catch (_) {}
    } catch (e) {
      setState(() => _isLocating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lấy vị trí: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _checkIn() async {
    if (!_hasLocation) return;

    setState(() => _isLocating = true);

    try {
      // Kiểm tra mạng
      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOffline = connectivityResult == ConnectivityResult.none;

      final docRef = FirebaseFirestore.instance.collection('checkins').doc();
      final dataToSave = {
        'project': _selectedProject,
        'latitude': _lat!,
        'longitude': _lng!,
        'notes': _notesCtrl.text,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'synced': !isOffline,
        'createdBy': UserSession().uid,
      };

      if (isOffline) {
        docRef.set(dataToSave);
      } else {
        await docRef.set(dataToSave);
      }

      setState(() {
        _notesCtrl.clear();
        _hasLocation = false;
        _lat = null;
        _lng = null;
        _isLocating = false;
      });
      if (mounted) {
        final msg = isOffline 
            ? 'Đã lưu ngoại tuyến! Sẽ tự động đồng bộ khi có mạng.'
            : 'Check-in thành công! Đã lưu lên hệ thống.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: const TextStyle(color: Colors.white)),
            backgroundColor: isOffline ? AppTheme.warning : AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLocating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi check-in: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Check-in GPS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'Lịch sử Check-in',
            onPressed: () => _scrollToHistory(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFlutterMap(),
            const SizedBox(height: 20),
            _buildLocationCard(),
            const SizedBox(height: 16),
            _buildTimeInfo(),
            const SizedBox(height: 16),
            _buildProjectSelector(),
            const SizedBox(height: 16),
            _buildNotesField(),
            const SizedBox(height: 20),
            _buildCheckInButton(),
            const SizedBox(height: 28),
            const SectionHeader(title: 'Lịch sử Check-in'),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('checkins')
                  .orderBy('timestamp', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: AppTheme.danger)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Chưa có check-in nào.', style: TextStyle(color: AppTheme.textSecondary)),
                  );
                }

                final docs = snapshot.data!.docs;
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final record = CheckInRecord.fromFirestore(data, doc.id);
                    return _CheckInHistoryTile(record: record);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Bản đồ thực bằng flutter_map + OpenStreetMap
  Widget _buildFlutterMap() {
    final LatLng center = _hasLocation && _lat != null && _lng != null
        ? LatLng(_lat!, _lng!)
        : const LatLng(14.0583, 108.2772); // Trung tâm Việt Nam

    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _hasLocation ? 15.0 : 5.5,
              ),
              children: [
                TileLayer(
                  // Dùng trực tiếp server ảnh bản đồ của Google Maps, truyền thêm gl=VN để ép hiển thị theo góc nhìn chủ quyền Việt Nam (không cần API Key)
                  urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&hl=vi&gl=VN',
                  userAgentPackageName: 'com.forestworker.app',
                ),
                if (_hasLocation && _lat != null && _lng != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_lat!, _lng!),
                        width: 50,
                        height: 50,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accent.withValues(alpha: 0.5),
                                    blurRadius: 12,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.my_location, color: Colors.white, size: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            // Badge góc phải
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _hasLocation ? Icons.gps_fixed : Icons.gps_not_fixed,
                      color: _hasLocation ? AppTheme.accent : AppTheme.textMuted,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _hasLocation ? 'GPS Active' : 'Chưa định vị',
                      style: TextStyle(
                        color: _hasLocation ? AppTheme.accent : AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tọa độ hiển thị dưới bản đồ
            if (_hasLocation)
              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.background.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3), width: 0.5),
                  ),
                  child: Text(
                    '📍 ${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
                    style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo() {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} - ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.access_time, color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thời gian thiết bị',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeStr,
                  style: const TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hasLocation ? AppTheme.accent.withValues(alpha: 0.4) : AppTheme.border,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_hasLocation ? AppTheme.accent : AppTheme.textMuted).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _hasLocation ? Icons.location_on : Icons.location_off_outlined,
              color: _hasLocation ? AppTheme.accent : AppTheme.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasLocation ? 'Vị trí đã xác định' : 'Chưa có vị trí',
                  style: TextStyle(
                    color: _hasLocation ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (_hasLocation) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Lat: ${_lat!.toStringAsFixed(6)} | Lng: ${_lng!.toStringAsFixed(6)}',
                    style: const TextStyle(color: AppTheme.accent, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isLocating ? null : _getLocation,
            icon: _isLocating
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.background),
                  )
                : const Icon(Icons.gps_fixed, size: 16),
            label: Text(_isLocating ? 'Đang lấy...' : 'Lấy vị trí', style: const TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dự án', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedProject,
          dropdownColor: AppTheme.surface,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: const InputDecoration(),
          items: _projects.map((p) => DropdownMenuItem(
            value: p,
            child: Text(p),
          )).toList(),
          onChanged: (v) => setState(() => _selectedProject = v!),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ghi chú', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesCtrl,
          maxLines: 2,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nhập ghi chú (tuỳ chọn)...',
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInButton() {
    return ElevatedButton.icon(
      onPressed: _hasLocation ? _checkIn : null,
      icon: const Icon(Icons.check_circle_outline, size: 20),
      label: const Text('Xác nhận Check-in'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _hasLocation ? AppTheme.accent : AppTheme.textMuted,
      ),
    );
  }
}

class _CheckInHistoryTile extends StatelessWidget {
  final CheckInRecord record;
  const _CheckInHistoryTile({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppTheme.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.project,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')} • ${record.latitude.toStringAsFixed(4)}, ${record.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Đã lưu', style: TextStyle(color: AppTheme.success, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
