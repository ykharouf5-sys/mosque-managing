import 'dart:convert';
import 'dart:typed_data';

import 'package:studentry/auth/data/biometric_service.dart';
import 'package:studentry/management/presentation/privacy_policy_screen.dart';
import 'package:studentry/patients/data/notification_service.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/shared/providers/auth_provider.dart';
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

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _appLanguage = 'ar';
  bool _deletingAccount = false;
  bool _exactRemindersEnabled = false;
  bool _requestingExactReminders = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadExactReminderStatus();
    }
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
    _loadExactReminderStatus();
    if (mounted) {
      setState(() {
        _appLanguage = prefs.getString('app_language') ?? 'ar';
      });
    }
  }

  Future<void> _loadExactReminderStatus() async {
    final enabled = await NotificationService.exactAlarmsEnabled();
    if (mounted) setState(() => _exactRemindersEnabled = enabled);
  }

  Future<void> _enableExactReminders() async {
    if (_requestingExactReminders) return;
    setState(() => _requestingExactReminders = true);
    final enabled = await NotificationService.requestExactAlarmPermission();
    if (!mounted) return;
    setState(() {
      _exactRemindersEnabled = enabled;
      _requestingExactReminders = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'تم تفعيل المنبهات والتذكيرات الدقيقة'
              : 'لم يتم منح الإذن. ستبقى التذكيرات تعمل بوضع تقريبي.',
        ),
      ),
    );
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

  Future<void> _deleteAccount() async {
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الحساب نهائياً'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيتم حذف حسابك وجلساتك وبياناتك الشخصية التابعة له. لا يمكن التراجع عن هذه العملية.',
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الحالية',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              final value = passwordController.text;
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    if (password == null || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await ref.read(authProvider.notifier).deleteAccount(password);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : 'تعذر حذف الحساب الآن. حاول مرة أخرى.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
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
            if (NotificationService.supportsExactAlarmPermission) ...[
              _buildSection('الإشعارات'),
              _buildSettingTile(
                icon: Icons.alarm_on_outlined,
                title: 'المنبهات والتذكيرات',
                subtitle: _exactRemindersEnabled
                    ? 'مفعّلة بدقة للمواعيد والمحاضرات'
                    : 'تعمل تقريبياً — اضغط لتفعيل الدقة من أندرويد',
                trailing: _requestingExactReminders
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : OutlinedButton(
                        onPressed: _exactRemindersEnabled
                            ? null
                            : _enableExactReminders,
                        child: Text(
                          _exactRemindersEnabled ? 'مفعّلة' : 'تفعيل',
                        ),
                      ),
                onTap: _exactRemindersEnabled ? null : _enableExactReminders,
              ),
              SizedBox(height: 24.h),
            ],
            _buildSection('البيانات'),
            _buildSettingTile(
              icon: Icons.privacy_tip_outlined,
              title: 'سياسة الخصوصية',
              subtitle: 'كيف نعالج بياناتك وحقوقك',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
            _buildSettingTile(
              icon: Icons.description_outlined,
              title: 'تصدير سجلات التطبيق',
              subtitle: 'حفظ ملف نصي بالسجلات',
              onTap: _exportLogs,
            ),
            _buildSettingTile(
              icon: Icons.delete_forever_outlined,
              title: _deletingAccount
                  ? 'جارٍ حذف الحساب...'
                  : 'حذف الحساب نهائياً',
              subtitle: 'حذف الحساب والبيانات الشخصية التابعة له',
              trailing: _deletingAccount
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_left, color: AppColors.danger),
              onTap: _deletingAccount ? null : _deleteAccount,
            ),
            SizedBox(height: 24.h),
            _buildSection('حول التطبيق'),
            _buildInfoTile('الإصدار', '1.0.0'),
            _buildInfoTile('اسم التطبيق', 'Studentry'),
            SizedBox(height: 32.h),
          ],
        ),
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
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
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
