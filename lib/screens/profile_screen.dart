import 'package:flutter/material.dart';
import '../main.dart';
import '../services/user_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _logbookCount = 0;
  int _checkinCount = 0;
  int _projectCount = 0;
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final logbooks = await FirebaseFirestore.instance.collection('logbook_activities').where('user', isEqualTo: UserSession().uid).count().get();
      final checkins = await FirebaseFirestore.instance.collection('checkins').where('createdBy', isEqualTo: UserSession().uid).count().get();
      final projectsSnap = await FirebaseFirestore.instance.collection('forest_projects').where('ownerUid', isEqualTo: UserSession().ownerId).where('workerUids', arrayContains: UserSession().uid).get();

      if (mounted) {
        setState(() {
          _logbookCount = logbooks.count ?? 0;
          _checkinCount = checkins.count ?? 0;
          _projectCount = projectsSnap.docs.length;
          _projects = projectsSnap.docs.map((d) => d.data()).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Chỉnh sửa hồ sơ',
            onPressed: () => _showEditProfileDialog(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(UserSession().uid).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildProfileHeader(context, userData),
                      const SizedBox(height: 20),
                      _buildInfoSection(context, userData),
                      const SizedBox(height: 16),
                      _buildProjectsSection(context),
                      const SizedBox(height: 16),
                      _buildSettingsSection(context),
                      const SizedBox(height: 24),
                      _buildLogoutButton(context),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, Map<String, dynamic> userData) {
    final String name = userData['fullName'] ?? 'Không rõ';
    final String role = userData['role'] ?? 'Forest Worker';
    
    String initials = 'U';
    if (name.isNotEmpty) {
      final parts = name.split(' ');
      if (parts.length > 1) {
        initials = '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      } else {
        initials = name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Center(
                  child: Text(initials, style: const TextStyle(color: AppTheme.background, fontSize: 28, fontWeight: FontWeight.w700)),
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primary, width: 2)),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(role, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatBadge(label: 'Nhật ký', value: '$_logbookCount'),
              Container(width: 0.5, height: 36, color: Colors.white38),
              _StatBadge(label: 'Check-in', value: '$_checkinCount'),
              Container(width: 0.5, height: 36, color: Colors.white38),
              _StatBadge(label: 'Dự án', value: '$_projectCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, Map<String, dynamic> userData) {
    return _Section(
      title: 'Thông tin cá nhân',
      children: [
        _InfoRow(icon: Icons.email_outlined, label: 'Email', value: userData['email'] ?? 'Chưa cập nhật'),
        _InfoRow(icon: Icons.phone_outlined, label: 'Điện thoại', value: userData['phone'] ?? 'Chưa cập nhật'),
        _InfoRow(icon: Icons.location_on_outlined, label: 'Khu vực', value: 'Đắk Lắk'),
        _InfoRow(icon: Icons.calendar_today_outlined, label: 'Gia nhập', value: '01/01/2023'),
      ],
    );
  }

  Widget _buildProjectsSection(BuildContext context) {
    if (_projects.isEmpty) {
      return const _Section(
        title: 'Dự án được phân công',
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Chưa có dự án nào', style: TextStyle(color: AppTheme.textSecondary)),
          )
        ],
      );
    }
    return _Section(
      title: 'Dự án được phân công',
      children: _projects.map((p) => _ProjectRow(
        name: p['projectName'] ?? p['name'] ?? 'Không rõ',
        status: p['status'] ?? 'Không rõ',
      )).toList(),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return _Section(
      title: 'Cài đặt',
      children: [
        _SettingsRow(icon: Icons.notifications_outlined, label: 'Thông báo', trailing: Switch(value: true, onChanged: (_) {}, activeColor: AppTheme.accent)),
        _SettingsRow(icon: Icons.language_outlined, label: 'Ngôn ngữ', trailing: const Text('Tiếng Việt', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        _SettingsRow(
          icon: Icons.lock_outline, 
          label: 'Đổi mật khẩu', 
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
          onTap: () => _showChangePasswordDialog(context),
        ),
      ],
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ChangePasswordSheet(uid: UserSession().uid),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    // Trần màn hình nấy lên dialog chỉnh sửa hồ sơ
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditProfileSheet(uid: UserSession().uid),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: () {
          UserSession().logout();
          Navigator.pushReplacementNamed(context, '/login');
        },
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('Đăng xuất'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.danger,
          side: const BorderSide(color: AppTheme.danger, width: 0.5),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Column(
              children: children.asMap().entries.map((e) {
                final isLast = e.key == children.length - 1;
                return Column(children: [
                  e.value,
                  if (!isLast) const Divider(height: 0, indent: 48),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 18),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final String name;
  final String status;
  const _ProjectRow({required this.name, required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'Active';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.forest_outlined, color: AppTheme.accent, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isActive ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(status, style: TextStyle(color: isActive ? AppTheme.success : AppTheme.warning, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;
  const _SettingsRow({required this.icon, required this.label, required this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ── Bottom Sheet chỉnh sửa hồ sơ ─────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final String uid;
  const _EditProfileSheet({required this.uid});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving     = false;
  bool _loading    = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        _nameCtrl.text  = data['fullName']  ?? '';
        _emailCtrl.text = data['email'] ?? '';
        _phoneCtrl.text = data['phone'] ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập họ tên')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'fullName':  _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Hồ sơ đã được cập nhật!', style: TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.textMuted, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Chỉnh sửa hồ sơ', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                    : const Text('Lưu', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          else ...[
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Số điện thoại',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Bottom Sheet Đổi mật khẩu ────────────────────────────────────────────────
class _ChangePasswordSheet extends StatefulWidget {
  final String uid;
  const _ChangePasswordSheet({required this.uid});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _saving = false;

  @override
  void dispose() {
    _currentPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final currentPwd = _currentPwdCtrl.text.trim();
    final newPwd = _newPwdCtrl.text.trim();

    if (currentPwd.isEmpty || newPwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin')),
      );
      return;
    }

    if (newPwd.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu mới phải có ít nhất 6 ký tự')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (!doc.exists) {
        throw Exception('Không tìm thấy tài khoản');
      }

      final data = doc.data() as Map<String, dynamic>;
      final dbPassword = data['password'] ?? '';

      if (currentPwd != dbPassword) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mật khẩu hiện tại không đúng'), backgroundColor: AppTheme.danger),
          );
        }
        setState(() => _saving = false);
        return;
      }

      // Cập nhật mật khẩu trong Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        try {
          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: currentPwd,
          );
          // Xác thực lại trước khi đổi mật khẩu
          await user.reauthenticateWithCredential(credential);
          await user.updatePassword(newPwd);
        } catch (authError) {
          // Bỏ qua lỗi nếu user dùng fallback login (không có Auth)
          debugPrint('Firebase Auth update failed: $authError');
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'password': newPwd,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đổi mật khẩu thành công!', style: TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.textMuted, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Đổi mật khẩu', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: _saving ? null : _changePassword,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                    : const Text('Lưu', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _currentPwdCtrl,
            obscureText: _obscureCurrent,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Mật khẩu hiện tại',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppTheme.textSecondary),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _newPwdCtrl,
            obscureText: _obscureNew,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Mật khẩu mới',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppTheme.textSecondary),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
