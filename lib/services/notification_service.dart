import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';

/// Service gửi thông báo lên Firestore collection 'notifications'
/// để web admin nhận được khi kiểm lâm viên thực hiện các hoạt động.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Gửi thông báo lên Firestore.
  /// [type]        : loại thông báo (checkin / logbook_entry / tree_data)
  /// [title]       : tiêu đề ngắn
  /// [message]     : nội dung chi tiết
  /// [projectName] : tên dự án liên quan
  /// [referenceId] : ID document liên quan (checkin/logbook/tree)
  Future<void> push({
    required String type,
    required String title,
    required String message,
    String projectName = '',
    String referenceId = '',
  }) async {
    try {
      final session = UserSession();
      final ownerId = session.ownerId;
      if (ownerId.isEmpty) return; // Không rõ admin → bỏ qua

      await _db.collection('notifications').add({
        'type': type,
        'title': title,
        'message': message,
        'projectName': projectName,
        'referenceId': referenceId,
        'recipientIds': [ownerId],
        'readBy': [],
        'senderUid': session.uid,
        'senderName': session.fullName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Không làm crash app nếu push thông báo thất bại
      // ignore: avoid_print
      print('[NotificationService] Lỗi gửi thông báo: $e');
    }
  }

  // ─── Các helper cho từng loại hoạt động ───────────────────────

  /// Gửi thông báo sau khi worker check-in thành công.
  Future<void> pushCheckIn({
    required String project,
    required String docId,
    double? lat,
    double? lng,
  }) async {
    final worker = UserSession().fullName;
    final locationStr = (lat != null && lng != null)
        ? '(${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})'
        : '';
    await push(
      type: 'worker_checkin',
      title: 'Check-in mới 📍',
      message: '$worker đã check-in tại dự án "$project" $locationStr',
      projectName: project,
      referenceId: docId,
    );
  }

  /// Gửi thông báo sau khi worker lưu nhật ký hoạt động.
  Future<void> pushLogbookEntry({
    required String project,
    required String activityType,
    required String docId,
  }) async {
    final worker = UserSession().fullName;
    await push(
      type: 'logbook_entry',
      title: 'Nhật ký mới 📝',
      message: '$worker đã ghi nhật ký "$activityType" tại dự án "$project"',
      projectName: project,
      referenceId: docId,
    );
  }

  /// Gửi thông báo sau khi worker thêm dữ liệu cây.
  Future<void> pushTreeData({
    required String project,
    required String plotCode,
    required String species,
    required int quantity,
    required String docId,
  }) async {
    final worker = UserSession().fullName;
    await push(
      type: 'tree_data',
      title: 'Dữ liệu cây mới 🌳',
      message:
          '$worker đã thêm $quantity cây "$species" tại ô mẫu $plotCode (dự án "$project")',
      projectName: project,
      referenceId: docId,
    );
  }
}
