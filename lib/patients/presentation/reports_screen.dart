import 'dart:io';

import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/patients/presentation/providers/patient_providers.dart';
import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row;

class ReportsScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const ReportsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _exporting = false;

  bool _isCompleted(PatientProfile patient) =>
      patient.treatmentPlan.isNotEmpty &&
      patient.treatmentPlan.every((item) => item.status == 'مكتمل');

  String _money(num value) => NumberFormat('#,##0.##', 'ar').format(value);

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(patientListProvider.notifier).refreshFromApi(),
      ref.read(appointmentListProvider.notifier).loadFromDb(),
    ]);
  }

  Future<void> _exportExcel(List<PatientProfile> patients) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final workbook = Workbook(2);
      final summary = workbook.worksheets[0]..name = 'الملخص';
      final details = workbook.worksheets[1]..name = 'المرضى';

      final due = patients.fold<double>(0, (sum, p) => sum + p.amountDue);
      final paid = patients.fold<double>(0, (sum, p) => sum + p.amountPaid);
      final remaining = patients.fold<double>(
        0,
        (sum, p) =>
            sum + (p.amountDue - p.amountPaid).clamp(0, double.infinity),
      );
      final completed = patients.where(_isCompleted).length;

      summary.getRangeByName('A1:B1').merge();
      summary.getRangeByName('A1').setText('تقرير المرضى والحسابات');
      summary.getRangeByName('A2').setText('تاريخ التصدير');
      summary
          .getRangeByName('B2')
          .setText(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()));
      summary.getRangeByName('A4').setText('المؤشر');
      summary.getRangeByName('B4').setText('القيمة');
      final summaryRows = <List<Object>>[
        ['عدد المرضى', patients.length],
        ['المرضى المنجزون', completed],
        ['إجمالي الحسابات المستحقة', due],
        ['إجمالي المدفوع', paid],
        ['إجمالي الحسابات المتبقية', remaining],
      ];
      for (var index = 0; index < summaryRows.length; index++) {
        final row = index + 5;
        summary
            .getRangeByIndex(row, 1)
            .setText(summaryRows[index][0] as String);
        summary
            .getRangeByIndex(row, 2)
            .setNumber((summaryRows[index][1] as num).toDouble());
      }
      summary.getRangeByName('A1:B1').cellStyle
        ..backColor = '#15A9BC'
        ..fontColor = '#FFFFFF'
        ..bold = true
        ..fontSize = 16
        ..hAlign = HAlignType.center;
      summary.getRangeByName('A4:B4').cellStyle
        ..backColor = '#15A9BC'
        ..fontColor = '#FFFFFF'
        ..bold = true
        ..hAlign = HAlignType.center;
      summary.getRangeByName('B5:B9').numberFormat = '#,##0.00';
      summary.getRangeByName('A1:A9').columnWidth = 34;
      summary.getRangeByName('B1:B9').columnWidth = 22;

      final headers = [
        'رقم المريض',
        'اسم المريض',
        'الهاتف',
        'العمر',
        'تاريخ التسجيل',
        'الحساب المستحق',
        'المدفوع',
        'المتبقي',
        'حالة العلاج',
      ];
      for (var column = 0; column < headers.length; column++) {
        details.getRangeByIndex(1, column + 1).setText(headers[column]);
        details.getRangeByIndex(1, column + 1).columnWidth = column == 1
            ? 24
            : 18;
      }
      details.getRangeByName('A1:I1').cellStyle
        ..backColor = '#15A9BC'
        ..fontColor = '#FFFFFF'
        ..bold = true
        ..hAlign = HAlignType.center;
      for (var index = 0; index < patients.length; index++) {
        final patient = patients[index];
        final row = index + 2;
        final values = [
          patient.id,
          patient.name,
          patient.phone,
          patient.age.toString(),
          patient.registrationDate,
        ];
        for (var column = 0; column < values.length; column++) {
          details.getRangeByIndex(row, column + 1).setText(values[column]);
        }
        details.getRangeByIndex(row, 6).setNumber(patient.amountDue);
        details.getRangeByIndex(row, 7).setNumber(patient.amountPaid);
        details
            .getRangeByIndex(row, 8)
            .setNumber(
              (patient.amountDue - patient.amountPaid)
                  .clamp(0, double.infinity)
                  .toDouble(),
            );
        details
            .getRangeByIndex(row, 9)
            .setText(_isCompleted(patient) ? 'منجز' : 'قيد العلاج');
      }
      if (patients.isNotEmpty) {
        details.getRangeByName('F2:H${patients.length + 1}').numberFormat =
            '#,##0.00';
      }

      final bytes = workbook.saveAsStream();
      workbook.dispose();
      final directory = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File('${directory.path}/studentry_report_$stamp.xlsx');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          subject: 'تقرير Studentry',
          text: 'تقرير المرضى والحسابات',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تصدير التقرير: $error')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientListProvider);
    final due = patients.fold<double>(0, (sum, p) => sum + p.amountDue);
    final paid = patients.fold<double>(0, (sum, p) => sum + p.amountPaid);
    final remaining = patients.fold<double>(
      0,
      (sum, p) => sum + (p.amountDue - p.amountPaid).clamp(0, double.infinity),
    );
    final completed = patients.where(_isCompleted).length;
    final active = patients.length - completed;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: !widget.embedded,
          title: const Text(
            'التقارير',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'تصدير Excel',
              onPressed: _exporting ? null : () => _exportExcel(patients),
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.file_download_outlined,
                      color: AppColors.primary,
                    ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: ListView(
            padding: EdgeInsets.all(16.r),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      'المتبقي',
                      _money(remaining),
                      Icons.account_balance_wallet_outlined,
                      AppColors.danger,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _metricCard(
                      'المستحق',
                      _money(due),
                      Icons.receipt_long_outlined,
                      AppColors.pending,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      'عدد المرضى',
                      '${patients.length}',
                      Icons.groups_rounded,
                      AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _metricCard(
                      'تم إنجازهم',
                      '$completed',
                      Icons.task_alt_rounded,
                      AppColors.success,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),
              _chartCard(
                title: 'حالة الحسابات',
                child: BarChart(
                  BarChartData(
                    maxY:
                        [
                          due,
                          paid,
                          remaining,
                          1,
                        ].reduce((a, b) => a > b ? a : b) *
                        1.2,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const labels = ['مستحق', 'مدفوع', 'متبقي'];
                            final index = value.toInt();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                index < labels.length ? labels[index] : '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textGray,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      _bar(0, due, AppColors.pending),
                      _bar(1, paid, AppColors.success),
                      _bar(2, remaining, AppColors.danger),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              _chartCard(
                title: 'إنجاز المرضى',
                child: patients.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد بيانات لعرضها',
                          style: TextStyle(color: AppColors.textGray),
                        ),
                      )
                    : PieChart(
                        PieChartData(
                          centerSpaceRadius: 42.r,
                          sectionsSpace: 3,
                          sections: [
                            PieChartSectionData(
                              value: completed.toDouble(),
                              color: AppColors.success,
                              title: '$completed\nمنجز',
                              radius: 48.r,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            PieChartSectionData(
                              value: active.toDouble(),
                              color: AppColors.primary,
                              title: '$active\nقيد العلاج',
                              radius: 48.r,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              SizedBox(height: 16.h),
              FilledButton.icon(
                onPressed: _exporting ? null : () => _exportExcel(patients),
                icon: const Icon(Icons.table_view_rounded),
                label: const Text('تصدير التقرير كملف Excel'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: widget.embedded
            ? null
            : const AppBottomNav(selectedIndex: 4),
      ),
    );
  }

  BarChartGroupData _bar(int x, double value, Color color) => BarChartGroupData(
    x: x,
    barRods: [
      BarChartRodData(
        toY: value,
        width: 25.w,
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
      ),
    ],
  );

  Widget _metricCard(String title, String value, IconData icon, Color color) =>
      Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: color, size: 22.sp),
            ),
            SizedBox(height: 10.h),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 19.sp,
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12.sp, color: AppColors.textGray),
            ),
          ],
        ),
      );

  Widget _chartCard({required String title, required Widget child}) =>
      Container(
        height: 260.h,
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 16.h),
            Expanded(child: child),
          ],
        ),
      );
}
