import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum NotificationManagerType { sales, academic }

class NotificationCampaignScreen extends StatefulWidget {
  const NotificationCampaignScreen({super.key, required this.managerType});

  final NotificationManagerType managerType;

  @override
  State<NotificationCampaignScreen> createState() =>
      _NotificationCampaignScreenState();
}

class _NotificationCampaignScreenState
    extends State<NotificationCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _audience = 'students';
  bool _sending = false;

  bool get _isAcademic =>
      widget.managerType == NotificationManagerType.academic;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate() || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiClient.instance.post(
        '/notification-campaigns',
        body: {
          'category': _isAcademic ? 'academic' : 'marketing',
          'audience': _isAcademic ? 'students' : _audience,
          'title': _titleController.text.trim(),
          'body': _bodyController.text.trim(),
          'action_route': _isAcademic ? '/university' : '/store',
        },
        maxRetries: 0,
      );
      if (!mounted) return;
      _titleController.clear();
      _bodyController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت جدولة الإشعار للإرسال على دفعات من 50 مستخدماً'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إرسال الإشعار: $error'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            _isAcademic ? 'إرسال إشعار أكاديمي' : 'إرسال إشعار للمستخدمين',
          ),
          centerTitle: true,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.all(20.r),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInfoCard(),
                      SizedBox(height: 20.h),
                      if (!_isAcademic) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _audience,
                          decoration: _decoration(
                            'الجمهور',
                            Icons.groups_2_outlined,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'students',
                              child: Text('جميع الطلاب'),
                            ),
                            DropdownMenuItem(
                              value: 'pending_order_users',
                              child: Text('أصحاب الطلبات المعلّقة'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _audience = value);
                            }
                          },
                        ),
                        SizedBox(height: 14.h),
                      ],
                      TextFormField(
                        controller: _titleController,
                        maxLength: 120,
                        decoration: _decoration(
                          'عنوان الإشعار',
                          Icons.title_rounded,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'عنوان الإشعار مطلوب'
                            : null,
                      ),
                      SizedBox(height: 14.h),
                      TextFormField(
                        controller: _bodyController,
                        maxLength: 500,
                        minLines: 4,
                        maxLines: 7,
                        decoration: _decoration(
                          'نص الإشعار',
                          Icons.message_outlined,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'نص الإشعار مطلوب'
                            : null,
                      ),
                      SizedBox(height: 20.h),
                      SizedBox(
                        height: 58.h,
                        child: ElevatedButton.icon(
                          onPressed: _sending ? null : _send,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18.r),
                            ),
                          ),
                          icon: _sending
                              ? SizedBox(
                                  width: 21.r,
                                  height: 21.r,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            _sending ? 'جاري الجدولة...' : 'إرسال الإشعار',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active_outlined,
            color: AppColors.primary,
            size: 28.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              _isAcademic
                  ? 'سيصل الإشعار إلى جميع الطلاب بصفته إشعاراً أكاديمياً.'
                  : 'يتم الإرسال عبر FCM على دفعات من 50 مستخدماً لتجنب الضغط على السيرفر.',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 13.sp,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
