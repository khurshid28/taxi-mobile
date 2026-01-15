import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../core/constants/app_constants.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _name = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final name = await StorageHelper.getString('user_name') ?? 'Haydovchi';
    final phone = await StorageHelper.getString(AppConstants.keyUserPhone) ?? '';

    setState(() {
      _name = name;
      _phone = phone;
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chiqish'),
        content: const Text('Hisobingizdan chiqmoqchimisiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Yo\'q'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Ha',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageHelper.clear();
      if (mounted) {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Profile Header
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary,
              child: Text(
                _name.isNotEmpty ? _name[0].toUpperCase() : 'H',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _phone,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Profile Options
            _buildOptionTile(
              icon: Icons.person,
              title: 'Profil ma\'lumotlari',
              onTap: () {},
            ),
            _buildOptionTile(
              icon: Icons.history,
              title: 'Tarix',
              onTap: () {},
            ),
            _buildOptionTile(
              icon: Icons.settings,
              title: 'Sozlamalar',
              onTap: () {},
            ),
            _buildOptionTile(
              icon: Icons.help_outline,
              title: 'Yordam',
              onTap: () {},
            ),
            _buildOptionTile(
              icon: Icons.info_outline,
              title: 'Ilova haqida',
              onTap: () {},
            ),
            _buildOptionTile(
              icon: Icons.logout,
              title: 'Chiqish',
              onTap: _logout,
              textColor: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Icon(
          icon,
          color: textColor ?? AppColors.primary,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: textColor ?? AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }
}
