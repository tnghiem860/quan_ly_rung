import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'user_session.dart';

/// [Flowchart 4 - Nhật ký & Đồng bộ] + [Flowchart 6 - Online/Offline]
/// Singleton chạy nền: lắng nghe kết nối mạng và tự động đồng bộ dữ liệu
/// còn đọc offline (nhật ký có ảnh, check-in) lên Firebase khi có mạng.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  // ── [Flowchart 6] Node: "Connectivity.onConnectivityChanged - Stream lắng nghe liên tục" ──
  // Được gọi từ MainShell.initState(). Lắng nghe thay đổi mạng liên tục;
  // khi có Wifi/Mobile → kích hoạt syncAll().
  void startListening() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      // [Flowchart 6] Node: "Kết nối" → gọi SyncService.syncAll
      if (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi) {
        syncAll();
      }
    });
  }

  void stopListening() {
    _connectivitySub?.cancel();
  }

  // ── [Flowchart 4] Node: "SyncService.syncAll" ────────────────────────────
  // Điểm điều phối: chạy tuần tự _syncLogbookActivities() và _syncCheckins().
  // Có cờ _isSyncing tránh chạy đồng thời.
  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      // Kiểm tra mạng lần cuối trước khi thực sự sync
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _isSyncing = false;
        return;
      }

      await _syncLogbookActivities();
      await _syncCheckins();
    } catch (e) {
      debugPrint('SyncService error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ── [Flowchart 4] Node: "_syncLogbookActivities: Upload ảnh offline → Storage" ──
  // Truy vấn nhật ký có synced=false, từng ảnh có localPath
  // → đọc file, putData lên Firebase Storage → lưu URL → cập nhật synced=true.
  Future<void> _syncLogbookActivities() async {
    final uid = UserSession().uid;
    if (uid.isEmpty) return;

    // [Flowchart 4] Truy vấn Firestore: nhật ký của user còn chưa đồng bộ
    final snapshot = await FirebaseFirestore.instance
        .collection('logbook_activities')
        .where('user', isEqualTo: uid)
        .where('synced', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      List<dynamic> photos = data['photos'] ?? [];
      bool allUploaded = true;

      List<Map<String, dynamic>> updatedPhotos = [];

      for (var photo in photos) {
        if (photo is Map<String, dynamic>) {
          String? localPath = photo['localPath'];
          String? storagePath = photo['storagePath'];
          
          // [Flowchart 4] Chỉ xử lý ảnh có localPath (chưa upload)
          if (localPath != null && localPath.isNotEmpty && storagePath != null) {
            final file = File(localPath);
            if (await file.exists()) {
              try {
                final bytes = await file.readAsBytes();
                // [Flowchart 4] Upload ảnh → Firebase Storage
                final storageRef = FirebaseStorage.instance.ref().child(storagePath);
                await storageRef.putData(bytes);
                final downloadUrl = await storageRef.getDownloadURL();

                // [Flowchart 4] Lưu URL, xóa localPath khỏi phần dữ liệu
                photo['url'] = downloadUrl;
                photo.remove('localPath'); // Xoà trường localPath vì đã upload thành công
                
                try {
                  await file.delete(); // Dọn file cục bộ sau khi upload
                } catch (_) {}
              } catch (e) {
                allUploaded = false;
                debugPrint('Error uploading logbook photo ${doc.id}: $e');
              }
            } else {
              // File mất khỏi đĩa → bỏ qua localPath
              photo.remove('localPath');
            }
          }
        }
        updatedPhotos.add(photo);
      }

      // [Flowchart 4] Cập nhật synced=true nếu tất cả ảnh đầu upload xong
      if (allUploaded) {
        await doc.reference.update({
          'photos': updatedPhotos,
          'synced': true,
        });
      } else {
        await doc.reference.update({
          'photos': updatedPhotos,
        });
      }
    }
  }

  // ── [Flowchart 4] Node: "_syncCheckins: cập nhật synced=true" ──
  // Check-in không có ảnh, dữ liệu text đã được Firestore tự cache offline.
  // Chỉ cần cập nhật cờ synced=true bằng WriteBatch hiệu quả.
  Future<void> _syncCheckins() async {
    final uid = UserSession().uid;
    if (uid.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('checkins')
        .where('createdBy', isEqualTo: uid)
        .where('synced', isEqualTo: false)
        .get();

    // Checkins không có ảnh, dữ liệu text đã được Firestore tự đẩy lên
    // Chỉ cần cập nhật cờ synced
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'synced': true});
    }
    if (snapshot.docs.isNotEmpty) {
      await batch.commit();
    }
  }
}
