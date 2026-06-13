import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    final phone = _passCtrl.text.trim();

    if (email.isEmpty || phone.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập đầy đủ email và số điện thoại');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Query Firestore: tìm user có email khớp
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _loading = false;
          _errorMessage = 'Tài khoản không tồn tại';
        });
        return;
      }

      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data();

      // Kiểm tra mật khẩu (dùng phone làm mật khẩu)
      final storedPhone = userData['phone'] ?? '';
      if (storedPhone != phone) {
        setState(() {
          _loading = false;
          _errorMessage = 'Mật khẩu không đúng';
        });
        return;
      }

      // Kiểm tra trạng thái tài khoản
      final status = userData['status'] ?? '';
      if (status != 'active') {
        setState(() {
          _loading = false;
          _errorMessage = 'Tài khoản đã bị khoá';
        });
        return;
      }

      // Đăng nhập thành công → lưu vào UserSession
      UserSession().login(
        uid: userData['uid'] ?? userDoc.id,
        fullName: userData['fullName'] ?? userData['name'] ?? 'Không rõ',
        email: userData['email'] ?? '',
        phone: userData['phone'] ?? '',
        role: userData['role'] ?? '',
        status: userData['status'] ?? '',
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Lỗi kết nối: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
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
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.forest, color: AppTheme.background, size: 28),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Forest Carbon',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
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
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Mật khẩu (Số điện thoại)',
            hintText: 'Nhập số điện thoại',
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
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.danger.withOpacity(0.3), width: 0.5),
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
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.background,
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
