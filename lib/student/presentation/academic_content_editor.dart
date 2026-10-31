import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:studentry/student/data/academic_store.dart';
import 'package:studentry/student/data/academic_document_service.dart';
import 'package:studentry/student/data/subject_models.dart';
import 'package:studentry/utils/variable_colors.dart';

class AcademicContentEditor extends StatefulWidget {
  const AcademicContentEditor({super.key, required this.subject});
  final Subject subject;
  @override
  State<AcademicContentEditor> createState() => _AcademicContentEditorState();
}

class _AcademicContentEditorState extends State<AcademicContentEditor> {
  late Subject _subject = widget.subject;
  bool _saving = false;

  Future<void> _save(List<SubjectLecture> entries) async {
    setState(() => _saving = true);
    try {
      final next = _subject.copyWith(
        lectures: entries,
        totalLectures: entries.where((e) => e.isLecture).length,
      );
      final stored = await AcademicStore.instance.updateSubject(next);
      if (mounted) setState(() => _subject = stored);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر النشر. تحقق من الاتصال، وأعد فتح المادة إذا عُدّلت من جهاز آخر.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit({SubjectLecture? item, String kind = 'lecture'}) async {
    final entryKind = item?.kind ?? kind;
    final numbers = _subject.lectures.map((e) => e.number).toSet();
    final range = entryKind == 'lecture'
        ? List.generate(500, (i) => i + 1)
        : List.generate(500, (i) => i + 501);
    final number =
        item?.number ?? range.where((n) => !numbers.contains(n)).firstOrNull;
    if (number == null) return;
    final result = await showModalBottomSheet<SubjectLecture>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ContentForm(
        item: item ?? SubjectLecture(number: number, kind: entryKind),
      ),
    );
    if (!mounted || result == null) return;
    final entries = [..._subject.lectures];
    final index = entries.indexWhere((e) => e.number == result.number);
    if (index < 0) {
      entries.add(result);
    } else {
      entries[index] = result;
    }
    await _save(entries);
  }

  Future<void> _remove(SubjectLecture item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزالة المحتوى؟'),
        content: Text(item.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _save(
        _subject.lectures.where((e) => e.number != item.number).toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: Text(_subject.name),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'المحاضرات'),
            Tab(text: 'ملخصات ودورات'),
          ],
        ),
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(children: [_list(true), _list(false)]),
    ),
  );

  Widget _list(bool lectures) {
    final entries = lectures ? _subject.publishedLectures : _subject.resources;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lectures
                    ? 'المحاضرات المنشورة: ${entries.length}'
                    : 'ملخصات ودورات يضيفها مدير الطلاب',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (lectures)
                FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة محاضرة واحدة'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _edit(kind: 'summary'),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة ملخص'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _edit(kind: 'course'),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة دورة'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('لا يوجد محتوى منشور بعد'))
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final item = entries[i];
                    return ListTile(
                      title: Text(
                        item.title.isEmpty ? 'محاضرة ${i + 1}' : item.title,
                      ),
                      subtitle: Text(
                        item.kind == 'summary'
                            ? 'ملخص'
                            : item.kind == 'course'
                            ? 'دورة'
                            : 'محاضرة ${i + 1}',
                      ),
                      leading: const Icon(
                        Icons.description_outlined,
                        color: AppColors.primary,
                      ),
                      onTap: () => _edit(item: item),
                      trailing: IconButton(
                        tooltip: 'إزالة',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(item),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ContentForm extends StatefulWidget {
  const _ContentForm({required this.item});
  final SubjectLecture item;
  @override
  State<_ContentForm> createState() => _ContentFormState();
}

class _ContentFormState extends State<_ContentForm> {
  final _key = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.item.title);
  late final _url = TextEditingController(
    text: widget.item.pdfReference?.startsWith('academic/') == true
        ? ''
        : widget.item.pdfReference,
  );
  late final _links = TextEditingController(
    text: widget.item.links.where((l) => l != widget.item.pdfUrl).join('\n'),
  );
  late String? _reference = widget.item.pdfReference;
  bool _uploading = false;
  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _links.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
            ['http', 'https'].contains(uri.scheme) &&
            uri.host.isNotEmpty
        ? null
        : 'أدخل رابط HTTP أو HTTPS صالحاً';
  }

  Future<void> _upload() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'html', 'htm'],
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final ref = await const AcademicDocumentService().uploadDocument(path);
      if (mounted) {
        setState(() {
          _reference = ref;
          _url.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر رفع الملف. اختر PDF أو HTML حتى 20 ميغابايت.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      16,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'محتوى مستقل لهذه المحاضرة أو المورد',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'العنوان'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'العنوان مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _url,
              maxLength: 2048,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رابط ملف PDF أو HTML (اختياري)',
              ),
              validator: _validateUrl,
            ),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _upload,
              icon: const Icon(Icons.upload_file),
              label: Text(
                _uploading
                    ? 'جارٍ الرفع…'
                    : _reference?.startsWith('academic/') == true
                    ? 'تم رفع الملف — استبدال'
                    : 'رفع ملف PDF أو HTML مستقل',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _links,
              minLines: 2,
              maxLines: 4,
              maxLength: 20000,
              decoration: const InputDecoration(
                labelText: 'روابط إضافية (اختياري)، كل رابط بسطر',
              ),
              validator: (v) {
                final lines = (v ?? '')
                    .split('\n')
                    .where((l) => l.trim().isNotEmpty);
                if (lines.length > 20) return 'الحد الأقصى 20 رابطاً';
                for (final l in lines) {
                  if (l.length > 2048 || _validateUrl(l) != null) {
                    return 'تأكد من صحة الروابط';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _uploading
                  ? null
                  : () {
                      if (!_key.currentState!.validate()) return;
                      final hasDocument =
                          _url.text.trim().isNotEmpty ||
                          _reference?.isNotEmpty == true;
                      if (!hasDocument && _links.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'أضف ملف PDF أو HTML أو رابط المحتوى قبل النشر.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(
                        context,
                        widget.item.copyWith(
                          title: _title.text.trim(),
                          pdfReference: _url.text.trim().isEmpty
                              ? _reference
                              : _url.text.trim(),
                          links: _links.text
                              .split('\n')
                              .map((l) => l.trim())
                              .where((l) => l.isNotEmpty)
                              .toList(),
                        ),
                      );
                    },
              child: const Text('حفظ ونشر'),
            ),
          ],
        ),
      ),
    ),
  );
}
