import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'user_session.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  void startListening() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi) {
        syncAll();
      }
    });
  }

  void stopListening() {
    _connectivitySub?.cancel();
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _isSyncing = false;
        return;
      }

      await _syncQuickPhotos();
      await _syncLogbookActivities();
      await _syncCheckins(); // Text only, but we update the flag
    } catch (e) {
      debugPrint('SyncService error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncQuickPhotos() async {
    final uid = UserSession().uid;
    if (uid.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('quick_photos')
        .where('createdBy', isEqualTo: uid)
        .where('synced', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      String? localPath = data['localPath'];
      String storagePath = data['storagePath'];

      if (localPath != null && localPath.isNotEmpty) {
        final file = File(localPath);
        if (await file.exists()) {
          try {
            final bytes = await file.readAsBytes();
            final storageRef = FirebaseStorage.instance.ref().child(storagePath);
            await storageRef.putData(bytes);
            final downloadUrl = await storageRef.getDownloadURL();

            await doc.reference.update({
              'url': downloadUrl,
              'localPath': null,
              'synced': true,
            });
            // Tùy chọn: xóa file local sau khi upload xong
            try {
              await file.delete();
            } catch (_) {}
          } catch (e) {
            debugPrint('Error uploading quick photo ${doc.id}: $e');
          }
        } else {
          // File bị mất, chỉ cập nhật synced = true để không bị lặp
          await doc.reference.update({'synced': true});
        }
      } else {
        // Không có ảnh local, có thể là đã upload nhưng cập nhật lỗi
        await doc.reference.update({'synced': true});
      }
    }
  }

  Future<void> _syncLogbookActivities() async {
    final uid = UserSession().uid;
    if (uid.isEmpty) return;

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
          
          if (localPath != null && localPath.isNotEmpty && storagePath != null) {
            final file = File(localPath);
            if (await file.exists()) {
              try {
                final bytes = await file.readAsBytes();
                final storageRef = FirebaseStorage.instance.ref().child(storagePath);
                await storageRef.putData(bytes);
                final downloadUrl = await storageRef.getDownloadURL();

                photo['url'] = downloadUrl;
                photo.remove('localPath'); // Xoá trường localPath vì đã upload thành công
                
                try {
                  await file.delete();
                } catch (_) {}
              } catch (e) {
                allUploaded = false;
                debugPrint('Error uploading logbook photo ${doc.id}: $e');
              }
            } else {
              // File mất
              photo.remove('localPath');
            }
          }
        }
        updatedPhotos.add(photo);
      }

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
