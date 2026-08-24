import 'dart:convert';
import 'dart:typed_data';

import 'package:studentry/auth/data/biometric_service.dart';
import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/utils/app_locale.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _appLanguage = 'ar';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadBiometricStatus() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _loadBiometricStatus();
    if (mounted) {
      setState(() {
        _appLanguage = prefs.getString('app_language') ?? 'ar';
      });
    }
  }

  Future<void> _setLanguage(String code) async {
    await AppLocale.setLocale(code);
    setState(() => _appLanguage = code);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            code == 'ar'
                ? 'تم تغيير اللغة إلى العربية'
                : 'Language changed to English',
          ),
        ),
      );
    }
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.textGray.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'اختيار اللغة',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 16.h),
              ListTile(
                leading: const Icon(Icons.language, color: AppColors.primary),
                title: const Text(
                  'العربية',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('اللغة الافتراضية'),
                trailing: _appLanguage == 'ar'
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () {
                  _setLanguage('ar');
                  Navigator.pop(ctx);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.language, color: AppColors.textGray),
                title: const Text(
                  'English',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Default language'),
                trailing: _appLanguage == 'en'
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () {
                  _setLanguage('en');
                  Navigator.pop(ctx);
                },
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportLogs() async {
    try {
      final logs = StringBuffer();
      logs.writeln('=== Studentry Logs ===');
      logs.writeln('Export Date: ${DateTime.now().toIso8601String()}');
      logs.writeln('App Language: $_appLanguage');
      logs.writeln('Biometric Lock: $_biometricEnabled');

      final bytes = Uint8List.fromList(utf8.encode(logs.toString()));
      await FilePicker.saveFile(
        dialogTitle: 'حفظ ملف السجلات',
        fileName: 'studentry_logs_${DateTime.now().millisecondsSinceEpoch}.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
        bytes: bytes,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تصدير السجلات بنجاح')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('فشل تصدير السجلات')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'الإعدادات',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: EdgeInsets.all(16.r),
          children: [
            _buildSection('اللغة'),
            _buildSettingTile(
              icon: Icons.language,
              title: 'لغة التطبيق',
              subtitle: _appLanguage == 'ar' ? 'العربية' : 'English',
              trailing: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _appLanguage == 'ar' ? 'تغيير' : 'Change',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              onTap: _showLanguagePicker,
            ),
            SizedBox(height: 24.h),
            _buildSection('الأمان'),
            _buildSettingTile(
              icon: Icons.fingerprint,
              title: 'قفل التطبيق بالبصمة',
              subtitle: _biometricAvailable
                  ? 'قفل التطبيق عند التصغير'
                  : 'البصمة غير متوفرة على هذا الجهاز',
              trailing: Switch(
                value: _biometricEnabled,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                activeThumbColor: AppColors.primary,
                onChanged: _biometricAvailable
                    ? (value) async {
                        await BiometricService.setEnabled(value);
                        setState(() => _biometricEnabled = value);
                      }
                    : null,
              ),
            ),
            SizedBox(height: 24.h),
            _buildSection('البيانات'),
            _buildSettingTile(
              icon: Icons.description_outlined,
              title: 'تصدير سجلات التطبيق',
              subtitle: 'حفظ ملف نصي بالسجلات',
              onTap: _exportLogs,
            ),
            SizedBox(height: 24.h),
            _buildSection('حول التطبيق'),
            _buildInfoTile('الإصدار', '1.0.0'),
            _buildInfoTile('اسم التطبيق', 'Studentry'),
            SizedBox(height: 32.h),
          ],
        ),
        bottomNavigationBar: const AppBottomNav(selectedIndex: 0),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 18.h,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20.sp),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14.sp,
            color: AppColors.textDark,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(fontSize: 12.sp, color: AppColors.textGray),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14.sp, color: AppColors.textGray),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14.sp,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
