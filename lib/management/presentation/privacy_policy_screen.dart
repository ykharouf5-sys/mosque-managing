import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:studentry/utils/variable_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _lastUpdated = '24 آب 2026';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('سياسة الخصوصية'),
          backgroundColor: AppColors.surface,
        ),
        body: ListView(
          padding: EdgeInsets.all(20.r),
          children: const [
            Text(
              'آخر تحديث: $_lastUpdated',
              style: TextStyle(color: AppColors.textGray),
            ),
            SizedBox(height: 18),
            _PolicySection(
              title: 'البيانات التي نعالجها',
              body:
                  'يعالج Studentry بيانات الحساب والملف الدراسي والطلبات، والبيانات السريرية التي يدخلها المستخدم المخوّل، والملفات والصور التي يختار رفعها، ومعرّف الجهاز اللازم للإشعارات.',
            ),
            _PolicySection(
              title: 'لماذا نستخدمها',
              body:
                  'نستخدم البيانات لتسجيل الدخول، مزامنة المواد والنتائج، إدارة المتجر والطلبات، تقديم ميزات العيادة بحسب الصلاحيات، إرسال الإشعارات المطلوبة، وحماية الخدمة من إساءة الاستخدام.',
            ),
            _PolicySection(
              title: 'المشاركة والتخزين',
              body:
                  'لا نبيع البيانات الشخصية. تُرسل البيانات إلى خادم Studentry ومزوّدي البنية التحتية الضروريين لتشغيل الخدمة. تُحفظ بيانات الجلسة محلياً بشكل آمن، وتُعزل بيانات كل حساب وعيادة عن غيرها.',
            ),
            _PolicySection(
              title: 'الصور والملفات',
              body:
                  'لا يصل التطبيق إلى صورة أو ملف إلا بعد أن تختاره. تُرفع الملفات المطلوبة فقط، ويمكن للمستخدم المخوّل حذفها من السجل المرتبط بها.',
            ),
            _PolicySection(
              title: 'الاحتفاظ والحذف',
              body:
                  'يمكن حذف الحساب نهائياً من الإعدادات. يؤدي ذلك إلى حذف بيانات الحساب والجلسات والبيانات الشخصية التابعة له. قد تبقى سجلات مشتركة أو نظامية منزوعة الارتباط بالحساب عندما يلزم الحفاظ على سلامة سجلات العيادة أو المعاملات.',
            ),
            _PolicySection(
              title: 'حقوقك والتواصل',
              body:
                  'يمكنك تصحيح ملفك أو حذف حسابك من داخل التطبيق. لطلبات الخصوصية الأخرى استخدم وسيلة التواصل الرسمية المنشورة في صفحة Studentry على متجر التطبيق.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;

  const _PolicySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              height: 1.65,
              fontSize: 14,
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }
}
