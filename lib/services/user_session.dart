/// Singleton lưu thông tin kiểm lâm đang đăng nhập.
/// Dùng chung trong toàn bộ app mà không cần truyền qua constructor.
class UserSession {
  // ── Singleton ──
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  // ── Dữ liệu user ──
  String? _uid;
  String? _fullName;
  String? _email;
  String? _phone;
  String? _role;
  String? _status;
  String? _ownerId;

  // ── Getters ──
  String get uid => _uid ?? '';
  String get fullName => _fullName ?? '';
  String get email => _email ?? '';
  String get phone => _phone ?? '';
  String get role => _role ?? '';
  String get status => _status ?? '';
  String get ownerId => _ownerId ?? '';

  bool get isLoggedIn => _uid != null && _uid!.isNotEmpty;

  /// Tên viết tắt (initials) để hiển thị avatar.
  String get initials {
    if (_fullName == null || _fullName!.isEmpty) return '??';
    final parts = _fullName!.trim().split(' ');
    if (parts.length > 1) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return _fullName!.substring(0, _fullName!.length >= 2 ? 2 : 1).toUpperCase();
  }

  // ── Methods ──

  /// Lưu thông tin user sau khi đăng nhập thành công.
  void login({
    required String uid,
    required String fullName,
    required String email,
    required String phone,
    required String role,
    required String status,
    required String ownerId,
  }) {
    _uid = uid;
    _fullName = fullName;
    _email = email;
    _phone = phone;
    _role = role;
    _status = status;
    _ownerId = ownerId;
  }

  /// Xoá toàn bộ thông tin khi đăng xuất.
  void logout() {
    _uid = null;
    _fullName = null;
    _email = null;
    _phone = null;
    _role = null;
    _status = null;
    _ownerId = null;
  }
}
