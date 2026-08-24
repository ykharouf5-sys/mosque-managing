import 'package:studentry/management/presentation/settings_screen.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/providers/auth_provider.dart';
import 'package:studentry/store/presentation/store_screen.dart';
import 'package:studentry/student/presentation/lessons_screen.dart';
import 'package:studentry/student/presentation/schedule_screen.dart';
import 'package:studentry/shared/widgets/main_navigation_screen.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _avatarUrl = AuthService().avatarUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 20.h),
            GestureDetector(
              onTap: _changeAvatar,
              child: CircleAvatar(
                radius: 40.r,
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                backgroundImage: _avatarUrl?.isNotEmpty == true
                    ? NetworkImage(_avatarUrl!)
                    : null,
                child: _avatarUrl?.isNotEmpty == true
                    ? null
                    : Icon(
                        Icons.add_a_photo_outlined,
                        size: 32.sp,
                        color: AppColors.primary,
                      ),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              AuthService().fullName ?? 'طبيب أسنان',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 24.h),
            const Divider(height: 1),
            _buildDrawerItem(Icons.home, 'الرئيسية', () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                (_) => false,
              );
            }),
            _buildDrawerItem(Icons.date_range_rounded, 'برنامجي الجامعي', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScheduleScreen()),
              );
            }),
            _buildDrawerItem(Icons.menu_book_rounded, 'دروسي', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LessonsScreen()),
              );
            }),
            _buildDrawerItem(Icons.store_outlined, 'المتجر', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreScreen()),
              );
            }),
            const Spacer(),
            const Divider(height: 1),
            _buildDrawerItem(Icons.settings_outlined, 'الإعدادات', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            }),
            SizedBox(height: 4.h),
            const Divider(height: 1),
            _buildDrawerItem(Icons.logout, 'تسجيل خروج', () {
              Navigator.pop(context);
              _logout(context, ref);
            }, color: AppColors.danger),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Future<void> _changeAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 78,
    );
    if (image == null) return;
    try {
      final url = await AuthService().uploadAvatar(
        await image.readAsBytes(),
        image.name,
      );
      if (mounted) setState(() => _avatarUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر رفع الصورة')));
      }
    }
  }

  void _logout(BuildContext context, WidgetRef ref) async {
    await AuthService().signOut();
    ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  Widget _buildDrawerItem(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: (color ?? AppColors.textDark).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: color ?? AppColors.textDark, size: 20.sp),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: color ?? AppColors.textDark,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 20.w),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
  }
}
