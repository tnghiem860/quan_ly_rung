import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../services/user_session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _errorMessage;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập đầy đủ email và mật khẩu');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Sử dụng Firebase Auth để đăng nhập
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      // Lấy thông tin user từ Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        // Fallback: Thử tìm theo email nếu uid không khớp (do data cũ)
        final fallbackSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
            
        if (fallbackSnap.docs.isEmpty) {
          setState(() {
            _loading = false;
            _errorMessage = 'Tài khoản không tồn tại trong hệ thống';
          });
          return;
        } else {
          // Lấy user từ fallback
          final userData = fallbackSnap.docs.first.data();
          _proceedLogin(uid, userData);
        }
      } else {
        final userData = userDoc.data()!;
        _proceedLogin(uid, userData);
      }
    } catch (e) {
      // Fallback: Thử tìm trực tiếp trong Firestore nếu Firebase Auth thất bại (ví dụ: user cũ chưa có tài khoản Auth)
      try {
        final fallbackSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
            
        if (fallbackSnap.docs.isNotEmpty) {
          final userData = fallbackSnap.docs.first.data();
          final storedPassword = userData['password'] ?? '';
          if (storedPassword == password) {
             // Mật khẩu khớp -> Cho phép đăng nhập
             _proceedLogin(userData['uid'] ?? fallbackSnap.docs.first.id, userData);
             return;
          }
        }
      } catch (_) {}

      // Nếu fallback cũng không được, báo lỗi
      setState(() {
        _loading = false;
        if (e is FirebaseAuthException && (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential')) {
           _errorMessage = 'Email hoặc mật khẩu không đúng';
        } else {
           _errorMessage = 'Email hoặc mật khẩu không đúng'; // Tránh hiện lỗi raw pigeon
        }
      });
    }
  }

  void _proceedLogin(String uid, Map<String, dynamic> userData) {
    // Kiểm tra trạng thái tài khoản
    final status = userData['status'] ?? '';
    if (status != 'active' && status != 'Active') {
      setState(() {
        _loading = false;
        _errorMessage = 'Tài khoản đã bị khoá';
      });
      return;
    }

    // Đăng nhập thành công → lưu vào UserSession
    UserSession().login(
      uid: uid, // Use auth uid
      fullName: userData['fullName'] ?? userData['name'] ?? 'Không rõ',
      email: userData['email'] ?? '',
      phone: userData['phone'] ?? '',
      role: userData['role'] ?? '',
      status: status,
      ownerId: userData['ownerId'] ?? userData['createdBy'] ?? '',
    );

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFDCFCE7), // xanh lục bảo nhạt
              Color(0xFFF8FAFC), // AppTheme.background
              Color(0xFFF8FAFC),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),
                  _buildLogo(),
                  const SizedBox(height: 48),
                  _buildHeader(),
                  const SizedBox(height: 36),
                  _buildForm(),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorMessage(),
                  ],
                  const SizedBox(height: 32),
                  _buildLoginButton(),
                  const SizedBox(height: 32),
                  _buildVersionInfo(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.accent, AppTheme.accentDark],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Icon(Icons.forest, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Forest Carbon',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              'Hệ thống Quản lý Rừng',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.accent,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Xin chào,\nKiểm lâm! 👋',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 32,
                height: 1.2,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Đăng nhập để tiếp tục làm việc',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'Nhập email của bạn',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passCtrl,
          obscureText: _obscure,
          keyboardType: TextInputType.text,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Mật khẩu',
            hintText: 'Nhập mật khẩu',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppTheme.textSecondary,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Quên mật khẩu?',
            style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _loading ? null : _login,
      child: _loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : const Text('Đăng nhập'),
    );
  }

  Widget _buildVersionInfo() {
    return Center(
      child: Text(
        'Forest Worker App v1.0.0',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
