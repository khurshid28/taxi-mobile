import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/storage_helper.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifications = true;
  bool _soundEnabled = true;
  String _language = 'O\'zbek';
  String _theme = 'Yorqin';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final soundEnabled = await StorageHelper.getBool('sound_enabled') ?? true;
    setState(() {
      _soundEnabled = soundEnabled;
      SoundService().setSoundEnabled(soundEnabled);
      _theme = _labelForMode(ThemeController.instance.mode.value);
    });
  }

  String _labelForMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Qorong\'i';
      case ThemeMode.system:
        return 'Tizim';
      case ThemeMode.light:
        return 'Yorqin';
    }
  }

  Future<void> _applyTheme(String label) async {
    final ThemeMode mode;
    switch (label) {
      case 'Qorong\'i':
        mode = ThemeMode.dark;
        break;
      case 'Tizim':
        mode = ThemeMode.system;
        break;
      default:
        mode = ThemeMode.light;
    }
    await ThemeController.instance.setMode(mode);
    setState(() => _theme = label);
  }

  Future<void> _saveSoundSetting(bool value) async {
    await StorageHelper.saveBool('sound_enabled', value);
    setState(() {
      _soundEnabled = value;
      SoundService().setSoundEnabled(value);
    });
    
    // Test sound when enabling
    if (value) {
      await SoundService().playNewOrderSound();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shadowColor: AppColors.shadow,
        surfaceTintColor: Colors.transparent,
        leading: Container(
          margin: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.divider, width: 1.w),
          ),
          child: IconButton(
            icon: Icon(
              Iconsax.arrow_left_2,
              color: AppColors.textPrimary,
              size: 18.sp,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
        title: Text(
          'Sozlamalar',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _buildSection('Bildirishnomalar', [
            _buildSwitchTile(
              'Bildirishnomalar',
              'Yangi buyurtmalar haqida xabarnomalar',
              Iconsax.notification_bing,
              _notifications,
              (value) => setState(() => _notifications = value),
            ),
            _buildSwitchTile(
              'Ovoz',
              'Bildirishnoma ovozlari',
              Iconsax.volume_high,
              _soundEnabled,
              (value) => _saveSoundSetting(value),
            ),
          ]),
          SizedBox(height: 16.h),
          _buildSection('Sozlamalar', [
            _buildSelectTile(
              'Til',
              _language,
              Iconsax.language_square,
              ['O\'zbek', 'Русский', 'English'],
              (value) => setState(() => _language = value),
            ),
            _buildSelectTile(
              'Tema',
              _theme,
              Iconsax.color_swatch,
              ['Yorqin', 'Qorong\'i', 'Tizim'],
              (value) => _applyTheme(value),
            ),
          ]),
          SizedBox(height: 16.h),
          _buildSection('Dastur haqida', [
            _buildInfoTile('Versiya', '1.0.0', Iconsax.info_circle),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 15.r,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      leading: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24.sp),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
      ),
    );
  }

  Widget _buildSelectTile(
    String title,
    String value,
    IconData icon,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      leading: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24.sp),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.divider, width: 1.w),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(width: 4.w),
            Icon(Iconsax.arrow_down_1, size: 20.sp, color: AppColors.textSecondary),
          ],
        ),
      ),
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 16.h),
                ...options.map((option) {
                  return ListTile(
                    title: Text(
                      option,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: option == value
                        ? Icon(Iconsax.tick_circle, color: AppColors.primary)
                        : null,
                    onTap: () {
                      onChanged(option);
                      Navigator.pop(context);
                    },
                  );
                }),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      leading: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24.sp),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
