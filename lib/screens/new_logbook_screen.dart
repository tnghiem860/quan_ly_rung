import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/user_session.dart';
import '../services/notification_service.dart';

class NewLogbookScreen extends StatefulWidget {
  const NewLogbookScreen({super.key});

  @override
  State<NewLogbookScreen> createState() => _NewLogbookScreenState();
}

class _NewLogbookScreenState extends State<NewLogbookScreen> {
  List<String> _activities = [];
  List<String> _projects = [];
  String? _selectedActivity;
  String? _selectedProject;
  bool _loadingData = true;
  final _descCtrl = TextEditingController();
  final List<XFile> _pickedPhotos = [];
  bool _saving = false;
  final ImagePicker _picker = ImagePicker();
  double? _lat;
  double? _lng;
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final actSnap = await FirebaseFirestore.instance.collection('activities').get();
      final projSnap = await FirebaseFirestore.instance.collection('forest_projects').where('ownerUid', isEqualTo: UserSession().ownerId).where('workerUids', arrayContains: UserSession().uid).get();
      
      setState(() {
        _activities = actSnap.docs.map((doc) => doc['name'] as String).toList();
        _projects = projSnap.docs.map((doc) => ForestProject.fromFirestore(doc.data(), doc.id).name).toList();
        if (_activities.isNotEmpty) _selectedActivity = _activities.first;
        if (_projects.isNotEmpty) _selectedProject = _projects.first;
        _loadingData = false;
      });
    } catch (e) {
      setState(() => _loadingData = false);
    }
  }

  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _loadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _loadingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _loadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _loadingLocation = false;
      });
    } catch (e) {
      setState(() => _loadingLocation = false);
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  // Chụp ảnh bằng camera - thử mở camera trước, nếu không được thì dùng gallery
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 50,
      );
      if (photo != null && _pickedPhotos.length < 10) {
        setState(() => _pickedPhotos.add(photo));
      }
    } catch (e) {
      // Camera không khả dụng (VD: thiết bị không có camera) → thử gallery
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera không khả dụng, chuyển sang thư viện ảnh...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      await Future.delayed(const Duration(milliseconds: 500));
      await _pickFromGallery();
    }
  }

  // Chọn ảnh từ thư viện
  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 50,
      );
      if (images.isNotEmpty) {
        final remaining = 10 - _pickedPhotos.length;
        setState(() {
          _pickedPhotos.addAll(images.take(remaining));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chọn ảnh: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  // Upload ảnh lên Firebase Storage
  Future<List<Map<String, dynamic>>> _uploadPhotosToStorage() async {
    final List<Map<String, dynamic>> uploadedPhotos = [];
    final storageRef = FirebaseStorage.instance.ref();
    for (int i = 0; i < _pickedPhotos.length; i++) {
      try {
        final Uint8List bytes = await _pickedPhotos[i].readAsBytes();
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final String storagePath = 'logbook_photos/$fileName';
        final imageRef = storageRef.child(storagePath);
        
        await imageRef.putData(bytes);
        final downloadUrl = await imageRef.getDownloadURL();
        
        uploadedPhotos.add({
          'url': downloadUrl,
          'name': fileName,
          'storagePath': storagePath,
        });
      } catch (e) {
        debugPrint('Lỗi upload ảnh $i: $e');
      }
    }
    return uploadedPhotos;
  }

  // Lưu ảnh xuống bộ nhớ cục bộ khi Offline
  Future<List<Map<String, dynamic>>> _savePhotosLocally() async {
    final List<Map<String, dynamic>> localPhotos = [];
    try {
      final dir = await getApplicationDocumentsDirectory();
      for (int i = 0; i < _pickedPhotos.length; i++) {
        final Uint8List bytes = await _pickedPhotos[i].readAsBytes();
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final localFile = File('${dir.path}/$fileName');
        await localFile.writeAsBytes(bytes);

        localPhotos.add({
          'localPath': localFile.path,
          'name': fileName,
          'storagePath': 'logbook_photos/$fileName',
        });
      }
    } catch (e) {
      debugPrint('Lỗi lưu ảnh cục bộ: $e');
    }
    return localPhotos;
  }

  Future<void> _save() async {
    if (_descCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mô tả công việc')),
      );
      return;
    }
    setState(() => _saving = true);

    try {
      // Kiểm tra mạng
      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOffline = connectivityResult == ConnectivityResult.none;

      // Upload ảnh lên Storage (Online) hoặc lưu cục bộ (Offline)
      List<Map<String, dynamic>> photoData = [];
      if (_pickedPhotos.isNotEmpty) {
        if (!isOffline) {
          photoData = await _uploadPhotosToStorage();
        } else {
          photoData = await _savePhotosLocally();
        }
      }

      // Chuẩn bị dữ liệu
      final docRef = FirebaseFirestore.instance.collection('logbook_activities').doc();
      final dataToSave = {
        'activityType': _selectedActivity,
        'project': _selectedProject,
        'description': _descCtrl.text,
        'photos': photoData,
        'photoCount': photoData.length,
        'latitude': _lat ?? 0.0,
        'longitude': _lng ?? 0.0,
        'location': '${_lat?.toStringAsFixed(4) ?? 0.0}, ${_lng?.toStringAsFixed(4) ?? 0.0}',
        'date': Timestamp.fromDate(DateTime.now()),
        'synced': !isOffline,
        'user': UserSession().uid,
        'userName': UserSession().fullName,
      };

      // Ghi dữ liệu
      if (isOffline) {
        // Không dùng await để tránh treo giao diện khi mất mạng
        docRef.set(dataToSave);
      } else {
        // Đợi server xác nhận nếu đang có mạng
        await docRef.set(dataToSave);
        // Gửi thông báo lên web admin
        await NotificationService().pushLogbookEntry(
          project: _selectedProject ?? '',
          activityType: _selectedActivity ?? '',
          docId: docRef.id,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        final msg = isOffline 
            ? 'Đã lưu ngoại tuyến! Sẽ tự động đồng bộ khi có mạng.'
            : 'Nhật ký đã lưu lên hệ thống! (${photoData.length} ảnh)';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // Hiển thị dialog chọn nguồn ảnh
  void _showPhotoSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn nguồn ảnh',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: AppTheme.accent),
                ),
                title: const Text('Chụp ảnh mới', style: TextStyle(color: AppTheme.textPrimary)),
                subtitle: const Text('Mở camera để chụp', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library, color: AppTheme.info),
                ),
                title: const Text('Chọn từ thư viện', style: TextStyle(color: AppTheme.textPrimary)),
                subtitle: const Text('Chọn ảnh có sẵn', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
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
        title: const Text('Nhật ký mới'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Lưu', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildField('Loại công việc', _buildActivitySelector()),
            const SizedBox(height: 16),
            _buildField('Dự án', _buildProjectSelector()),
            const SizedBox(height: 16),
            _buildField('Mô tả công việc', _buildDescriptionField()),
            const SizedBox(height: 16),
            _buildField('Hình ảnh (${_pickedPhotos.length}/10)', _buildPhotoGrid()),
            const SizedBox(height: 16),
            _buildField('Thời gian & Vị trí', Column(
              children: [
                _buildTimeInfo(),
                const SizedBox(height: 8),
                _buildLocationInfo(),
              ],
            )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildActivitySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _activities.map((a) {
        final selected = a == _selectedActivity;
        return GestureDetector(
          onTap: () => setState(() => _selectedActivity = a),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? AppTheme.accent : AppTheme.border,
                width: selected ? 1 : 0.5,
              ),
            ),
            child: Text(
              a,
              style: TextStyle(
                color: selected ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProjectSelector() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedProject,
      dropdownColor: AppTheme.surface,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: const InputDecoration(),
      items: _projects.map((p) => DropdownMenuItem(
        value: p,
        child: Text(p),
      )).toList(),
      onChanged: (v) => setState(() => _selectedProject = v!),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descCtrl,
      maxLines: 5,
      maxLength: 500,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: const InputDecoration(
        hintText: 'Mô tả chi tiết công việc đã thực hiện...',
        alignLabelWithHint: true,
        counterStyle: TextStyle(color: AppTheme.textMuted),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _pickedPhotos.length < 10 ? _pickedPhotos.length + 1 : _pickedPhotos.length,
      itemBuilder: (_, i) {
        if (i == _pickedPhotos.length) return _buildAddPhotoButton();
        return _buildPhotoThumbnail(i);
      },
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: _showPhotoSourceDialog,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: AppTheme.accent, size: 28),
            SizedBox(height: 4),
            Text('Chụp / Chọn ảnh', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(int i) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryLight.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.accent, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: FutureBuilder<Uint8List>(
              future: _pickedPhotos[i].readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  );
                }
                return const Center(
                  child: Icon(Icons.image, color: AppTheme.accent, size: 32),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => setState(() => _pickedPhotos.removeAt(i)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppTheme.danger,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.background.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${i + 1}',
              style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeInfo() {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} - ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: AppTheme.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thời gian trên thiết bị', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                Text(timeStr, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
    final hasLocation = _lat != null && _lng != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            hasLocation ? Icons.location_on : Icons.location_off_outlined,
            color: hasLocation ? AppTheme.accent : AppTheme.textMuted,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLocation ? 'Vị trí GPS đã xác định' : (_loadingLocation ? 'Đang lấy vị trí...' : 'Không có GPS'),
                  style: TextStyle(
                    color: hasLocation ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  hasLocation
                      ? '${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}'
                      : 'Bấm "Cập nhật" để thử lại',
                  style: TextStyle(
                    color: hasLocation ? AppTheme.accent : AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _loadingLocation
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                )
              : TextButton(
                  onPressed: _fetchLocation,
                  child: const Text('Cập nhật', style: TextStyle(fontSize: 12)),
                ),
        ],
      ),
    );
  }
}
