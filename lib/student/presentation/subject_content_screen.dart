import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:studentry/student/data/academic_store.dart';
import 'package:studentry/student/data/academic_document_service.dart';
import 'package:studentry/student/data/subject_models.dart';
import 'package:studentry/utils/variable_colors.dart';

/// The subject and enrollment continue to come from the account-scoped store.
class SubjectContentScreen extends StatefulWidget {
  const SubjectContentScreen({
    super.key,
    required this.subjectId,
    required this.enrollmentId,
    this.resources = false,
  });
  final String subjectId, enrollmentId;
  final bool resources;
  @override
  State<SubjectContentScreen> createState() => _SubjectContentScreenState();
}

class _SubjectContentScreenState extends State<SubjectContentScreen> {
  final _store = AcademicStore.instance;
  final _busy = <int>{};
  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    super.dispose();
  }

  Future<void> _open(
    Subject subject,
    SubjectLecture item, {
    String? link,
  }) async {
    try {
      final uri = link == null
          ? await const AcademicDocumentService().lectureUrl(subject.id, item)
          : Uri.parse(link);
      if (!['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const FormatException('Invalid document link');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح الملف. تحقق من الاتصال وحاول مجدداً.'),
          ),
        );
      }
    }
  }

  Future<void> _mark(StudentSubject enrollment, SubjectLecture item) async {
    setState(() => _busy.add(item.number));
    try {
      await _store.markLectureViewed(enrollment, item.number);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر حفظ متابعة المحاضرة. حاول مجدداً.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(item.number));
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = _store.subjects
        .where((s) => s.id == widget.subjectId)
        .firstOrNull;
    final enrollment = _store.enrollments
        .where((s) => s.enrollmentId == widget.enrollmentId)
        .firstOrNull;
    return DefaultTabController(
      length: 2,
      initialIndex: widget.resources ? 1 : 0,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(subject?.name ?? 'محتوى المادة'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'المحاضرات'),
              Tab(text: 'ملخصات ودورات'),
            ],
          ),
        ),
        body: subject == null
            ? const Center(child: Text('المادة لم تعد متاحة'))
            : TabBarView(
                children: [
                  _list(subject, subject.publishedLectures, enrollment),
                  _list(subject, subject.resources, enrollment),
                ],
              ),
      ),
    );
  }

  Widget _list(
    Subject subject,
    List<SubjectLecture> items,
    StudentSubject? enrollment,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'لا يوجد محتوى منشور بعد. يظهر هنا عند إضافته من مدير الطلاب.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final viewed = enrollment?.viewedLectures.contains(item.number) == true;
        final links = item.links
            .where((l) => l.trim().isNotEmpty && l != item.pdfUrl)
            .toList();
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFE8F6F7),
                      foregroundColor: AppColors.primary,
                      child: Icon(
                        item.isLecture
                            ? Icons.menu_book_outlined
                            : Icons.library_books_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.title.isEmpty ? 'محاضرة ${index + 1}' : item.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                if (item.pdfReference != null || item.pdfUrl != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _open(subject, item),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('فتح ملف PDF / HTML'),
                  ),
                ],
                for (var i = 0; i < links.length; i++)
                  TextButton.icon(
                    onPressed: () => _open(subject, item, link: links[i]),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text('ملف أو رابط ${i + 1}'),
                  ),
                if (item.isLecture && enrollment != null)
                  TextButton.icon(
                    onPressed: viewed || _busy.contains(item.number)
                        ? null
                        : () => _mark(enrollment, item),
                    icon: Icon(
                      viewed ? Icons.check_circle : Icons.check_circle_outline,
                    ),
                    label: Text(
                      viewed ? 'تمت المتابعة' : 'تحديد كمحاضرة تمت متابعتها',
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
