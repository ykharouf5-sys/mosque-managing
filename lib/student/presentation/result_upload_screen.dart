import 'dart:convert';
import 'dart:io';
import 'package:studentry/student/data/pdf_parser_service.dart';
import 'package:studentry/student/data/result_models.dart';
import 'package:studentry/student/data/result_local_repository.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:studentry/student/data/json_parser_service.dart';
import 'package:uuid/uuid.dart';

// Top-level function for isolate-based PDF extraction
@pragma('vm:entry-point')
String _extractPdfTextIsolate(List<int> bytes) {
  return PdfParserService.extractTextFromBytes(bytes);
}

class ResultUploadScreen extends ConsumerStatefulWidget {
  const ResultUploadScreen({super.key});

  @override
  ConsumerState<ResultUploadScreen> createState() => _ResultUploadScreenState();
}

class _ResultUploadScreenState extends ConsumerState<ResultUploadScreen> {
  static const _repository = ResultLocalRepository();
  final List<ResultUpload> _uploads = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadUploads();
  }

  @override
  void dispose() {
    if (_initialized) {}
    super.dispose();
  }

  Future<void> _loadUploads() async {
    final uploads = await _repository.uploads();
    if (!mounted) return;
    setState(() {
      _uploads
        ..clear()
        ..addAll(uploads);
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'إدارة نتائج الامتحانات',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: AppColors.surface,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.textDark),
              onPressed: () => setState(() {}),
            ),
          ],
        ),
        body: _uploads.isEmpty
            ? _buildEmptyState()
            : Column(
                children: [
                  _buildStatsBar(),
                  SizedBox(height: 8.h),
                  Expanded(child: _buildUploadsList()),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: _showUploadOptions,
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.upload_file_outlined,
            size: 80.sp,
            color: AppColors.textGray.withValues(alpha: 0.3),
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد ملفات نتائج',
            style: TextStyle(fontSize: 18.sp, color: AppColors.textGray),
          ),
          SizedBox(height: 8.h),
          Text(
            'اضغط على الزر أدناه لرفع ملف PDF',
            style: TextStyle(fontSize: 13.sp, color: AppColors.textGray),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
            label: const Text('رفع ملف نتائج'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
            ),
            onPressed: _pickAndUploadPdf,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final total = _uploads.length;
    final completed = _uploads.where((u) => u.status == 'completed').length;
    final failed = _uploads.where((u) => u.status == 'failed').length;
    final processing = _uploads
        .where((u) => u.status == 'processing' || u.status == 'upload-ready')
        .length;
    return Container(
      margin: EdgeInsets.all(16.r),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          _buildStatItem(
            Icons.description_outlined,
            '$total',
            'إجمالي',
            AppColors.primary,
          ),
          _buildStatDivider(),
          _buildStatItem(
            Icons.check_circle_outline,
            '$completed',
            'مكتمل',
            AppColors.success,
          ),
          _buildStatDivider(),
          _buildStatItem(
            Icons.hourglass_top,
            '$processing',
            'قيد المعالجة',
            AppColors.pending,
          ),
          _buildStatDivider(),
          _buildStatItem(
            Icons.error_outline,
            '$failed',
            'فشل',
            AppColors.danger,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10.sp, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 40.h, color: AppColors.divider);
  }

  Widget _buildUploadsList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: _uploads.length,
      itemBuilder: (_, i) => _buildUploadCard(_uploads[i]),
    );
  }

  Widget _buildUploadCard(ResultUpload upload) {
    final statusColor = _statusColor(upload.status);
    final statusTxt = statusLabel(upload.status);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.picture_as_pdf_outlined,
                  color: statusColor,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      upload.fileName,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            statusTxt,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        if (upload.importedRecords > 0)
                          Text(
                            '${upload.importedRecords} سجل',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppColors.textGray,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: AppColors.textGray,
                  size: 20.sp,
                ),
                onSelected: (v) => _handleMenuAction(v, upload),
                itemBuilder: (_) => [
                  if (upload.status == 'failed')
                    const PopupMenuItem(
                      value: 'reprocess',
                      child: Text('إعادة معالجة'),
                    ),
                  if (upload.status == 'completed') ...[
                    const PopupMenuItem(
                      value: 'view_records',
                      child: Text('عرض النتائج'),
                    ),
                    const PopupMenuItem(
                      value: 'view_logs',
                      child: Text('عرض السجلات'),
                    ),
                  ],
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('حذف', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
          if (upload.status == 'processing') ...[
            SizedBox(height: 8.h),
            const LinearProgressIndicator(
              backgroundColor: AppColors.divider,
              color: AppColors.primary,
            ),
          ],
          if (upload.errorMessage != null) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 14.sp,
                    color: AppColors.danger,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      upload.errorMessage!,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (upload.warnings.isNotEmpty && upload.status == 'completed') ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: AppColors.pending.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14.sp,
                        color: AppColors.pending,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'تحذيرات (${upload.warnings.length})',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.pending,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  ...upload.warnings
                      .take(3)
                      .map(
                        (w) => Padding(
                          padding: EdgeInsets.only(top: 2.h),
                          child: Text(
                            '• $w',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppColors.textGray,
                            ),
                          ),
                        ),
                      ),
                  if (upload.warnings.length > 3)
                    Text(
                      '+${upload.warnings.length - 3} تحذيرات أخرى',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.textGray,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'upload-ready':
        return AppColors.primary;
      case 'processing':
        return AppColors.pending;
      case 'completed':
        return AppColors.success;
      case 'failed':
        return AppColors.danger;
      default:
        return AppColors.textGray;
    }
  }

  void _handleMenuAction(String action, ResultUpload upload) {
    switch (action) {
      case 'reprocess':
        _reprocessUpload(upload);
        break;
      case 'view_records':
        _showRecords(upload.id);
        break;
      case 'view_logs':
        _showLogs(upload.id);
        break;
      case 'delete':
        _deleteUpload(upload);
        break;
    }
  }

  Future<void> _reprocessUpload(ResultUpload upload) async {}

  Future<void> _showRecords(String uploadId) async {
    final records = await _repository.records(uploadId);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('النتائج (${records.length})'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: records.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (_, index) {
                final record = records[index];
                return ListTile(
                  title: Text(
                    record.studentName.isEmpty
                        ? record.examNumber
                        : record.studentName,
                  ),
                  subtitle: Text(
                    '${record.examNumber} • ${record.subjectName} • ${record.statusLabel}',
                  ),
                  trailing: Text('${record.mark}/${record.total}'),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  // Reserved for the detailed records view once server-side pagination lands.
  // ignore: unused_element
  Widget _buildRecordTableHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30.w,
            child: Text(
              '#',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'الرقم الامتحاني',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'المادة',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'العلامة',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'الحالة',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildRecordRow(ResultRecord record) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30.w,
            child: Text(
              record.examNumber,
              style: TextStyle(fontSize: 11.sp, color: AppColors.textDark),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              record.examNumber,
              style: TextStyle(
                fontSize: 11.sp,
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              record.subjectName,
              style: TextStyle(fontSize: 11.sp, color: AppColors.textDark),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              record.mark.toStringAsFixed(0),
              style: TextStyle(fontSize: 11.sp, color: AppColors.textDark),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              record.statusLabel,
              style: TextStyle(fontSize: 11.sp, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogs(String uploadId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ImportLogsScreen(uploadId: uploadId)),
    );
  }

  Future<void> _deleteUpload(ResultUpload upload) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'حذف الملف',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'هل أنت متأكد من حذف "${upload.fileName}"؟\nسيتم حذف جميع النتائج المستوردة منه.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _repository.delete(upload.id);
      if (mounted) {
        setState(() => _uploads.removeWhere((item) => item.id == upload.id));
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح')));
      }
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'اختر طريقة الإضافة',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: _UploadOptionCard(
                        icon: Icons.picture_as_pdf_outlined,
                        label: 'رفع ملف PDF',
                        subtitle: 'استخراج العلامات تلقائياً',
                        color: Colors.red,
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickAndUploadPdf();
                        },
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _UploadOptionCard(
                        icon: Icons.data_object_outlined,
                        label: 'ملف JSON',
                        subtitle: 'إضافة علامات يدوياً',
                        color: AppColors.primary,
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickAndUploadJson();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadJson() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    final sessionInfo = await _showSessionDialog();
    if (sessionInfo == null) return;

    if (!mounted) return;

    _showLoadingDialog('جاري قراءة الملف...');
    try {
      String jsonStr;
      if (file.path != null) {
        jsonStr = await File(file.path!).readAsString();
      } else {
        final data = await file.readAsBytes();
        jsonStr = utf8.decode(data);
      }

      _updateLoadingMessage('جاري معالجة البيانات...');
      final parsed = JsonParserService.parseJson(
        jsonStr,
        examSession: sessionInfo['examSession'],
      );

      if (parsed.records.isEmpty) {
        _dismissLoadingDialog();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'لم يتم العثور على سجلات صالحة. تأكد من تنسيق JSON',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      await _saveParsedResults(file.name, sessionInfo, parsed);

      // Create upload record
      _dismissLoadingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم استيراد ${parsed.records.length} سجل بنجاح من JSON',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      _dismissLoadingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل معالجة JSON: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    // Show dialog to enter exam session info
    final sessionInfo = await _showSessionDialog();
    if (sessionInfo == null) return;

    if (!mounted) return;
    _processUpload(file, sessionInfo);
  }

  Future<Map<String, String>?> _showSessionDialog() async {
    final sessionC = TextEditingController();
    final yearC = TextEditingController();
    final subjectC = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('معلومات الامتحان'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectC,
                decoration: const InputDecoration(
                  labelText: 'اسم المادة (اختياري)',
                  hintText: 'مثال: الجراحة العامة',
                ),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: sessionC,
                decoration: const InputDecoration(
                  labelText: 'الدورة الامتحانية (اختياري)',
                  hintText: 'مثال: الدورة الأولى 2025',
                ),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: yearC,
                decoration: const InputDecoration(
                  labelText: 'السنة الدراسية (اختياري)',
                  hintText: 'مثال: الثالثة',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx, {
                  'examSession': sessionC.text.trim(),
                  'academicYear': yearC.text.trim(),
                  'subjectName': subjectC.text.trim(),
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('رفع الملف'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processUpload(
    PlatformFile file,
    Map<String, String> sessionInfo,
  ) async {
    _showLoadingDialog('جاري قراءة الملف...');

    try {
      _updateLoadingMessage('جاري قراءة الملف...');
      final bytes = await File(file.path!).readAsBytes();

      _updateLoadingMessage('جاري استخراج النصوص...');
      final extractedText = await compute(_extractPdfTextIsolate, bytes);
      final hasText = PdfParserService.hasSufficientContent(extractedText);

      if (hasText) {
        _updateLoadingMessage('جاري معالجة النتائج...');
        final parsed = PdfParserService.parseGrades(
          extractedText,
          examSession: sessionInfo['examSession'],
        );

        if (parsed.records.isNotEmpty) {
          await _saveParsedResults(file.name, sessionInfo, parsed);
          _dismissLoadingDialog();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'تم استخراج ${parsed.records.length} نتيجة بنجاح',
                ),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } else {
          _dismissLoadingDialog();
          if (mounted) {
            _showNoResultsDialog(extractedText, file.name);
          }
        }
      } else {
        _dismissLoadingDialog();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم استخراج نصوص من الملف'),
              backgroundColor: Color(0xFFFF9800),
            ),
          );
        }
      }
    } catch (e) {
      _dismissLoadingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _saveParsedResults(
    String fileName,
    Map<String, String> sessionInfo,
    ParsedResult parsed,
  ) async {
    final uploadId = const Uuid().v4();
    final now = DateTime.now();
    final subjectName = sessionInfo['subjectName']?.trim();
    final academicYear = sessionInfo['academicYear']?.trim();
    final examSession = sessionInfo['examSession']?.trim();
    final records = parsed.records
        .map(
          (record) => ResultRecord(
            id: record.id,
            examNumber: record.examNumber,
            studentName: record.studentName,
            subjectName: subjectName?.isNotEmpty == true
                ? subjectName!
                : record.subjectName,
            subjectCode: record.subjectCode,
            mark: record.mark,
            total: record.total,
            status: record.status,
            examSession: examSession?.isNotEmpty == true
                ? examSession
                : record.examSession,
            academicYear: academicYear?.isNotEmpty == true
                ? academicYear
                : record.academicYear,
            uploadDate: now,
            sourcePdfId: uploadId,
            notes: record.notes,
          ),
        )
        .toList();
    final upload = ResultUpload(
      id: uploadId,
      fileName: fileName,
      status: 'completed',
      totalRecords: records.length + parsed.issues.length,
      importedRecords: records.length,
      failedRecords: parsed.issues.length,
      warnings: parsed.issues
          .map((issue) => issue.message ?? issue.type)
          .toList(),
      uploadDate: now,
      processedDate: now,
      uploadedBy: AuthService().userId ?? 'local-user',
      examSession: examSession,
      academicYear: academicYear,
    );
    await _repository.save(upload, records);
    if (mounted) setState(() => _uploads.insert(0, upload));
  }

  void _showNoResultsDialog(
    String extractedText,
    String fileName, [
    String? uploadId,
  ]) {
    final preview = extractedText.length > 2000
        ? '${extractedText.substring(0, 2000)}\n\n... (${extractedText.length - 2000} حرف إضافي)'
        : extractedText;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('لم يتم العثور على نتائج'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تم استخراج نص من الملف لكن لم نتمكن من التعرف على أرقام الامتحانات والعلامات.',
                  style: TextStyle(fontSize: 13.sp, color: AppColors.textGray),
                ),
                SizedBox(height: 8.h),
                Text(
                  'النص المستخرج من $fileName:',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  constraints: BoxConstraints(maxHeight: 300.h),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.textGray.withValues(alpha: 0.2),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(12.r),
                    child: Text(
                      preview,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontFamily: 'monospace',
                        color: AppColors.textDark,
                        height: 1.4,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: AppColors.textGray),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showLogs(uploadId ?? '');
              },
              child: const Text('عرض سجل المعالجة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(width: 16.w),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateLoadingMessage(String message) {
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}
    _showLoadingDialog(message);
  }

  void _dismissLoadingDialog() {
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}
  }
}

// ─── Upload Option Card ───

class _UploadOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _UploadOptionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36.sp, color: color),
            SizedBox(height: 10.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10.sp, color: AppColors.textGray),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Import Logs Viewer Screen ───

class _ImportLogsScreen extends StatelessWidget {
  final String uploadId;
  const _ImportLogsScreen({required this.uploadId});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('سجل المعالجة'),
          centerTitle: true,
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: Center(
          child: Text(
            'سجل المعالجة غير متاح',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textGray),
          ),
        ),
      ),
    );
  }
}
