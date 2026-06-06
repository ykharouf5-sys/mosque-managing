import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as ex;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/widget/variable.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class StudentDetailsScreen extends StatefulWidget {
  final Student student;

  const StudentDetailsScreen({super.key, required this.student});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  final TextEditingController _pagesController = TextEditingController();
  final StorageService _storage = StorageService();
  late Student _currentStudent;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _currentStudent = widget.student;
  }

  @override
  void dispose() {
    _pagesController.dispose();
    super.dispose();
  }

  Future<void> _saveMemorization() async {
    final pagesText = _pagesController.text.trim();
    if (pagesText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء إدخال عدد الصفحات')));
      return;
    }

    final pagesValue = 'حفظ $pagesText صفحة';

    final updatedStudent = _currentStudent.copyWith(
      memorization: [..._currentStudent.memorization, pagesValue],
    );

    final students = await _storage.loadStudents();
    final idx = students.indexWhere((s) => s.id == updatedStudent.id);
    if (idx != -1) {
      students[idx] = updatedStudent;
      await _storage.saveStudents(students);

      setState(() {
        _currentStudent = updatedStudent;
      });

      if (mounted) {
        _pagesController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ عدد الصفحات بنجاح ✅')),
        );
      }
    }
  }

  Future<void> _exportStudentDataToExcel() async {
    setState(() {
      _isExporting = true;
    });

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'جاري إنشاء ملف Excel للطالب ${_currentStudent.name}...',
          ),
        ),
      );

      final excel = ex.Excel.createExcel();

      final attendanceSheet = excel['الحضور'];
      attendanceSheet.isRTL = true;
      attendanceSheet.appendRow([
        ex.TextCellValue('التاريخ'),
        ex.TextCellValue('الحالة'),
      ]);
      for (int i = 0; i < _currentStudent.attendanceDates.length; i++) {
        final date = _currentStudent.attendanceDates[i];
        final isPresent = i < _currentStudent.attendance.length
            ? _currentStudent.attendance[i]
            : null;
        final status = isPresent == true
            ? 'حاضر'
            : (isPresent == false ? 'غائب' : 'غير مسجل');
        attendanceSheet.appendRow([
          ex.TextCellValue(date),
          ex.TextCellValue(status),
        ]);
      }

      final prayersSheet = excel['الصلوات'];
      prayersSheet.isRTL = true;
      prayersSheet.appendRow([
        ex.TextCellValue('التاريخ'),
        ex.TextCellValue('الفجر'),
        ex.TextCellValue('الظهر'),
        ex.TextCellValue('العصر'),
        ex.TextCellValue('المغرب'),
        ex.TextCellValue('العشاء'),
      ]);
      for (int i = 0; i < _currentStudent.prayerDates.length; i++) {
        final date = _currentStudent.prayerDates[i];
        final prayers = i < _currentStudent.prayers.length
            ? _currentStudent.prayers[i]
            : [];
        final row = <ex.CellValue>[ex.TextCellValue(date)];
        for (int j = 0; j < 5; j++) {
          final status = j < prayers.length ? prayers[j] : 'غير مسجل';
          row.add(ex.TextCellValue(status));
        }
        prayersSheet.appendRow(row);
      }

      final memorizationSheet = excel['التسميع والحفظ'];
      memorizationSheet.isRTL = true;
      memorizationSheet.appendRow([
        ex.TextCellValue('رقم التسجيل'),
        ex.TextCellValue('كمية الحفظ (صفحات / تقييم)'),
      ]);
      for (int i = 0; i < _currentStudent.memorization.length; i++) {
        memorizationSheet.appendRow([
          ex.TextCellValue((i + 1).toString()),
          ex.TextCellValue(_currentStudent.memorization[i]),
        ]);
      }

      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final directory = await getApplicationDocumentsDirectory();
      final sanitizedName = _currentStudent.name.replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );
      final fileName =
          'تقرير_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${directory.path}/$fileName';

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        // ignore: deprecated_member_use
        await Share.shareXFiles([
          XFile(filePath),
        ], text: 'تقرير وإنجازات الطالب ${_currentStudent.name}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تصدير الملف: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  // Helper to parse pages from "حفظ 5 صفحة" or just return a default value
  double _parsePages(String input) {
    final regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(input);
    if (match != null) {
      return double.tryParse(match.group(0) ?? '0') ?? 0;
    }
    // If it's a string like "متاز", return a fixed point value
    switch (input) {
      case 'ممتاز':
        return 5.0;
      case 'جيد جدا':
        return 4.0;
      case 'جيد':
        return 3.0;
      default:
        return 1.0;
    }
  }

  // Chart data generators
  List<FlSpot> _getAttendanceSpots() {
    if (_currentStudent.attendance.isEmpty) return [const FlSpot(0, 0)];
    List<FlSpot> spots = [];
    for (int i = 0; i < _currentStudent.attendance.length; i++) {
      spots.add(FlSpot(i.toDouble(), _currentStudent.attendance[i] ? 1 : 0));
    }
    return spots;
  }

  List<FlSpot> _getPrayerSpots() {
    if (_currentStudent.prayers.isEmpty) return [const FlSpot(0, 0)];
    List<FlSpot> spots = [];
    for (int i = 0; i < _currentStudent.prayers.length; i++) {
      int performedCount = _currentStudent.prayers[i]
          .where((p) => p == 'جماعة' || p == 'أداء' || p == 'قضاء')
          .length;
      spots.add(FlSpot(i.toDouble(), performedCount.toDouble()));
    }
    return spots;
  }

  List<FlSpot> _getMemorizationSpots() {
    if (_currentStudent.memorization.isEmpty) return [const FlSpot(0, 0)];
    List<FlSpot> spots = [];
    for (int i = 0; i < _currentStudent.memorization.length; i++) {
      spots.add(
        FlSpot(i.toDouble(), _parsePages(_currentStudent.memorization[i])),
      );
    }
    return spots;
  }

  Widget _buildLineChart(
    String title,
    List<FlSpot> spots,
    Color lineColor,
    double maxY,
    String yLabel,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: max(spots.length.toDouble() - 1, 1),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: lineColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: lineColor.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backcolor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'ملف الطالب الشامل',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backcolor, textcolor.withOpacity(0.7)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Header
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [regsin, regsin.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: regsin.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: Text(
                          _currentStudent.name[0],
                          style: TextStyle(
                            color: regsin,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentStudent.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.stars_rounded,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_currentStudent.points} نقطة',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Statistics Row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'إجمالي المحفوظ',
                        '${_currentStudent.memorization.fold<double>(0, (sum, item) => sum + _parsePages(item)).toInt()} صفحة',
                        Icons.menu_book_rounded,
                        Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'أيام الحضور',
                        '${_currentStudent.attendance.where((a) => a == true).length} يوم',
                        Icons.event_available_rounded,
                        Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Charts Section Title
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'التحليل البياني',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.analytics_outlined, color: Colors.white),
                  ],
                ),

                // Charts
                _buildLineChart(
                  'معدل الحضور',
                  _getAttendanceSpots(),
                  Colors.blueAccent,
                  1.2,
                  '',
                ),
                _buildLineChart(
                  'الصلوات الخمس المكتملة',
                  _getPrayerSpots(),
                  Colors.greenAccent,
                  5.5,
                  '',
                ),
                _buildLineChart(
                  'معدل التسميع (عدد الصفحات)',
                  _getMemorizationSpots(),
                  Colors.orangeAccent,
                  max(
                    _getMemorizationSpots().map((e) => e.y).fold(0.0, max) + 2,
                    5.0,
                  ),
                  '',
                ),

                const SizedBox(height: 24),

                // Memorization Input Card
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'إضافة سجل حفظ جديد',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.menu_book, color: Colors.white),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _pagesController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.3),
                          hintText: 'عدد الصفحات (مثال: 5)',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _saveMemorization,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: regsin,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 5,
                          ),
                          child: const Text(
                            'حفظ ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Export Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    icon: _isExporting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Icon(Icons.file_download, size: 28),
                    label: Text(
                      _isExporting
                          ? 'جاري تصدير التقرير...'
                          : 'تصدير التقرير إلى Excel',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                    ),
                    onPressed: _isExporting ? null : _exportStudentDataToExcel,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
