import 'package:flutter/material.dart';
import '../main.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(context),
            const SizedBox(height: 20),
            _buildInfoSection(context),
            const SizedBox(height: 16),
            _buildProjectsSection(context),
            const SizedBox(height: 16),
            _buildSettingsSection(context),
            const SizedBox(height: 24),
            _buildLogoutButton(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
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
                child: const Center(
                  child: Text('TB', style: TextStyle(color: AppTheme.background, fontSize: 28, fontWeight: FontWeight.w700)),
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
          const Text('Trần Văn B', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Forest Worker', style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatBadge(label: 'Nhật ký', value: '127'),
              Container(width: 0.5, height: 36, color: AppTheme.border),
              _StatBadge(label: 'Check-in', value: '89'),
              Container(width: 0.5, height: 36, color: AppTheme.border),
              _StatBadge(label: 'Dự án', value: '3'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return _Section(
      title: 'Thông tin cá nhân',
      children: [
        _InfoRow(icon: Icons.email_outlined, label: 'Email', value: 'tranvanb@forest.vn'),
        _InfoRow(icon: Icons.phone_outlined, label: 'Điện thoại', value: '0901 234 567'),
        _InfoRow(icon: Icons.location_on_outlined, label: 'Khu vực', value: 'Đắk Lắk'),
        _InfoRow(icon: Icons.calendar_today_outlined, label: 'Gia nhập', value: '01/01/2023'),
      ],
    );
  }

  Widget _buildProjectsSection(BuildContext context) {
    return _Section(
      title: 'Dự án được phân công',
      children: [
        _ProjectRow(name: 'Dak Lak Project 01', status: 'Active'),
        _ProjectRow(name: 'Lam Dong Project 02', status: 'Active'),
        _ProjectRow(name: 'Gia Lai Project 01', status: 'Surveying'),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return _Section(
      title: 'Cài đặt',
      children: [
        _SettingsRow(icon: Icons.notifications_outlined, label: 'Thông báo', trailing: Switch(value: true, onChanged: (_) {}, activeColor: AppTheme.accent)),
        _SettingsRow(icon: Icons.cloud_sync_outlined, label: 'Tự động đồng bộ', trailing: Switch(value: true, onChanged: (_) {}, activeColor: AppTheme.accent)),
        _SettingsRow(icon: Icons.wifi_off_outlined, label: 'Offline Mode', trailing: Switch(value: false, onChanged: (_) {}, activeColor: AppTheme.accent)),
        _SettingsRow(icon: Icons.language_outlined, label: 'Ngôn ngữ', trailing: const Text('Tiếng Việt', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        _SettingsRow(icon: Icons.lock_outline, label: 'Đổi mật khẩu', trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18)),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
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
      Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
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
          const Spacer(),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
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
              color: (isActive ? AppTheme.success : AppTheme.warning).withOpacity(0.15),
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
  const _SettingsRow({required this.icon, required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
          trailing,
        ],
      ),
    );
  }
}
