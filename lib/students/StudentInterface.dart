import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:pdf/pdf.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:yaman/models/student.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/services/supabase_service.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/Screen/Chat_screen.dart';
import 'package:yaman/Screen/adhkar_categories_screen.dart';
import 'package:yaman/Screen/lessons_screen.dart';
import 'package:yaman/Screen/mushaf_screen.dart';
import 'package:yaman/Screen/prays.dart';
import 'package:yaman/Screen/prayer_stats_screen.dart';
import 'package:yaman/Screen/badges_screen.dart';
import 'package:yaman/Screen/leaderboard_screen.dart';
import 'package:yaman/Screen/notification_settings_screen.dart';
import 'package:yaman/utils/responsive_helper.dart';
import 'package:yaman/widget/app_footer.dart';
import 'package:yaman/widget/bubble_app_bar.dart';
import 'package:yaman/widget/prayer_times_widget.dart';

class StudentInterface extends StatefulWidget {
  const StudentInterface({super.key, required this.student});

  final Student student;
  @override
  State<StudentInterface> createState() => _StudentInterfaceState();
}

class _StudentInterfaceState extends State<StudentInterface>
    with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();

  late Student _student;
  bool _isLoading = true;
  int _currentIndex = 0;
  PageController _pageController = PageController();

  final ScrollController _scrollController = ScrollController();

  final GlobalKey _attendanceChartKey = GlobalKey();

  final GlobalKey _prayerChartKey = GlobalKey();

  final SupabaseService _supabase = SupabaseService();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _fadeController.forward();
    setState(() => _student = widget.student);

    // Skip sync for trial mode
    if (_student.id != 'trial_student') {
      _setupRealtimeSync();
      _checkForUpdates();
    }
  }

  void _setupRealtimeSync() {
    // Listen for ANY student changes, filter for THIS student
    _supabase.subscribeToStudents().listen((students) {
      if (!mounted) return;
      try {
        final cloudStudent = students.firstWhere((s) => s.id == _student.id);

        // New, robust merge logic using Maps
        final localPrayerMap = _student.getPrayerMap();
        final cloudPrayerMap = cloudStudent.getPrayerMap();

        // Merge: Start with cloud data, then overwrite with local data.
        // This ensures local optimistic updates are always preserved.
        final mergedPrayerMap = {...cloudPrayerMap, ...localPrayerMap};

        final mergedStudent = cloudStudent.copyWithPrayerMap(mergedPrayerMap);

        setState(() => _student = mergedStudent);
        _storage.updateStudent(mergedStudent);
        print(
          '⚡ Student Interface: Received realtime update for ${_student.name}',
        );
      } catch (e) {
        // Not found or other error is fine (maybe another student updated)
      }
    });
  }

  Future<void> _checkForUpdates() async {
    try {
      // 1. Try to pull fresh data from cloud
      final cloudStudents = await _supabase.loadStudents();
      final cloudStudent = cloudStudents.firstWhere((s) => s.id == _student.id);

      if (mounted) {
        // Use the same robust merge logic on startup
        final localPrayerMap = _student.getPrayerMap();
        final cloudPrayerMap = cloudStudent.getPrayerMap();

        // Merge: Start with cloud data, then overwrite with local data.
        final mergedPrayerMap = {...cloudPrayerMap, ...localPrayerMap};

        final updatedStudent = cloudStudent.copyWithPrayerMap(mergedPrayerMap);

        setState(() => _student = updatedStudent);
        print('☁️ Student Interface: Synced from cloud on startup');
        await _storage.updateStudent(updatedStudent);
      }
    } catch (e) {
      print('⚠️ Student Sync: checking local storage fallback');
      // Fallback to local storage refresh if cloud fails
      _refreshLocalStudent();
    }
  }

  Future<void> _refreshLocalStudent() async {
    try {
      final students = await _storage.loadStudents();
      final idx = students.indexWhere((s) => s.id == _student.id);
      if (idx != -1) {
        setState(() {
          _student = students[idx];
        });
      }
    } catch (e) {
      // ignore refresh errors
    }
  }

  Future<void> _showTransferTeacherDialog() async {
    try {
      // Load teachers list
      final teachers = await _storage.loadTeachers();

      if (teachers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لا يوجد أساتذة متاحون'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      String? selectedTeacherId;
      String? selectedTeacherName;

      await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('تغيير الأستاذ'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'اختر الأستاذ الجديد:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedTeacherId,
                        decoration: InputDecoration(
                          labelText: 'الأستاذ',
                          border: OutlineInputBorder(),
                        ),
                        items: teachers
                            .where(
                              (t) => t.id != _student.teacherId,
                            ) // Exclude current teacher
                            .map((teacher) {
                              return DropdownMenuItem<String>(
                                value: teacher.id,
                                child: Text(teacher.name),
                              );
                            })
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedTeacherId = value;
                            selectedTeacherName = teachers
                                .firstWhere((t) => t.id == value)
                                .name;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (selectedTeacherName != null)
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'سيتم نقلك من "${_student.teacherName}" إلى "$selectedTeacherName"',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: selectedTeacherId == null
                        ? null
                        : () async {
                            try {
                              Navigator.pop(context);

                              // Show loading indicator
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('جاري تغيير الأستاذ...'),
                                    ],
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );

                              // Perform transfer
                              final newTeacher = teachers.firstWhere(
                                (t) => t.id == selectedTeacherId,
                              );

                              final updatedStudent = _student.copyWith(
                                teacherId: selectedTeacherId,
                                teacherName: newTeacher.name,
                                teacherPhone: newTeacher.number,
                              );

                              await _storage.updateStudent(updatedStudent);

                              // Update local state
                              setState(() {
                                _student = updatedStudent;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم تغيير الأستاذ إلى $selectedTeacherName بنجاح!',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'خطأ في تغيير الأستاذ: ${e.toString()}',
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                    child: Text('تأكيد'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل قائمة الأساتذة: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _exportAsPdf() async {
    print('📥 PDF Export: Starting process...');
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('جاري تجهيز ملف PDF...')));
    }
    final pdf = pw.Document();

    try {
      // Use Cairo font for Arabic support
      final font = await PdfGoogleFonts.cairoRegular();
      final fontBold = await PdfGoogleFonts.cairoBold();

      // Prepare data
      final student = _student;
      final int window = 30;
      final int startIndex = student.attendance.length > window
          ? student.attendance.length - window
          : 0;

      final last30Attendance = student.attendance.sublist(startIndex);
      final int presentDays = last30Attendance.where((d) => d).length;
      final int totalDays = last30Attendance.length;
      final double percentage = totalDays == 0
          ? 0
          : (presentDays / totalDays) * 100;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return [
              // Header section
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.only(bottom: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.teal, width: 2),
                  ),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'تقرير متابعة الطالب',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      student.name,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Info cards section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: _buildPdfInfoCard(
                      'المعلم',
                      student.teacherName,
                      font,
                    ),
                  ),
                  pw.SizedBox(width: 15),
                  pw.Expanded(
                    child: _buildPdfInfoCard(
                      'النقاط',
                      '${student.points}',
                      font,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: _buildPdfInfoCard(
                      'رقم المعلم',
                      student.teacherPhone,
                      font,
                    ),
                  ),
                  pw.SizedBox(width: 15),
                  pw.Expanded(
                    child: _buildPdfInfoCard('رقم الطالب', student.phone, font),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Stats summary section
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildPdfStat(
                      'أيام الحضور',
                      '$presentDays',
                      PdfColors.green,
                    ),
                    _buildPdfStat(
                      'أيام الغياب',
                      '${totalDays - presentDays}',
                      PdfColors.red,
                    ),
                    _buildPdfStat(
                      'نسبة الالتزام',
                      '${percentage.toStringAsFixed(1)}%',
                      PdfColors.blue,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Prayers section header
              pw.Text(
                'سجل الصلاة (آخر 30 يوم)',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal,
                ),
              ),
              pw.SizedBox(height: 10),

              // Manual Table for better RTL handling
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(1),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal),
                    children: [
                      _buildPdfTableCell('التاريخ', fontBold, isHeader: true),
                      _buildPdfTableCell('فجر', fontBold, isHeader: true),
                      _buildPdfTableCell('ظهر', fontBold, isHeader: true),
                      _buildPdfTableCell('عصر', fontBold, isHeader: true),
                      _buildPdfTableCell('مغرب', fontBold, isHeader: true),
                      _buildPdfTableCell('عشاء', fontBold, isHeader: true),
                    ],
                  ),
                  // Table Data
                  ...List.generate(
                    student.prayers.length > window
                        ? window
                        : student.prayers.length,
                    (index) {
                      final realIndex = startIndex + index;
                      final dayPrayers = student.prayers[realIndex];
                      final date = student.prayerDates.length > realIndex
                          ? student.prayerDates[realIndex]
                          : 'يوم ${realIndex + 1}';

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: index % 2 == 0
                              ? PdfColors.white
                              : PdfColors.grey50,
                        ),
                        children: [
                          _buildPdfTableCell(date, font),
                          ...dayPrayers.map((p) => _buildPdfTableCell(p, font)),
                        ],
                      );
                    },
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Memorization section header
              pw.Text(
                'سجل الحفظ (آخر 30 يوم)',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal,
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal),
                    children: [
                      _buildPdfTableCell('التاريخ', fontBold, isHeader: true),
                      _buildPdfTableCell('التقييم', fontBold, isHeader: true),
                    ],
                  ),
                  ...List.generate(
                    student.memorization.length > window
                        ? window
                        : student.memorization.length,
                    (index) {
                      final realIndex = startIndex + index;
                      final eval = student.memorization[realIndex];
                      final date = student.prayerDates.length > realIndex
                          ? student.prayerDates[realIndex]
                          : 'يوم ${realIndex + 1}';

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: index % 2 == 0
                              ? PdfColors.white
                              : PdfColors.grey50,
                        ),
                        children: [
                          _buildPdfTableCell(date, font),
                          _buildPdfTableCell(eval, font),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      print('PDF Export Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في تصدير PDF: $e')));
      }
    }
  }

  pw.Widget _buildPdfInfoCard(String label, String value, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
              font: font,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              font: font,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfStat(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfTableCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Center(
        child: pw.Text(
          text,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            font: font,
            fontSize: isHeader ? 12 : 10,
            color: isHeader ? PdfColors.white : PdfColors.black,
          ),
        ),
      ),
    );
  }

  static const List<String> dayNames = [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final responsive = context.responsive;
    final student = _student;
    final List<bool> all = student.attendance;
    final int window = 30;
    final int startIndex = all.length > window ? all.length - window : 0;
    final List<bool> last30 = all.sublist(startIndex);
    final int presentDays = last30.where((d) => d).length;
    final int totalDays = last30.length;
    final int absentDays = totalDays - presentDays;
    final double attendancePct = totalDays == 0
        ? 0
        : (presentDays / totalDays) * 100.0;

    // حساب آمن للمسافة بين تسميات الأسفل

    final double bottomInterval = last30.length <= 6
        ? 1.0
        : (last30.length / 6).ceilToDouble();

    // Get current week dates (Sunday to Saturday)
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7)); // Sunday
    final endOfWeek = startOfWeek.add(const Duration(days: 6)); // Saturday

    // Filter prayers for current week
    final List<List<String>> currentWeekPrayers = [];
    final List<String> weekDates = [];
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      weekDates.add(dateStr);
      final prayerIndex = student.prayerDates.indexOf(dateStr);
      if (prayerIndex != -1 && prayerIndex < student.prayers.length) {
        currentWeekPrayers.add(student.prayers[prayerIndex]);
      } else {
        currentWeekPrayers.add([
          'غير مكتمل',
          'غير مكتمل',
          'غير مكتمل',
          'غير مكتمل',
          'غير مكتمل',
        ]);
      }
    }

    final List<List<String>> last7Prayers = currentWeekPrayers;

    final List<int> prayerCounts = last7Prayers
        .map(
          (day) => day
              .where((prayer) => prayer != 'غياب' && prayer != 'غير مكتمل')
              .length,
        )
        .toList();

    final List<String> last30Prayers = student.prayers
        .sublist(startIndex)
        .map((day) => day.join(' - '))
        .toList();
    return SafeArea(
      top: false,
      bottom: true,
      child: Scaffold(
      backgroundColor: backcolor,
      appBar: AppBar(
        title: const Text(
          "ملف الطالب",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: backcolor,
        elevation: 4,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.white70),
          onPressed: () async {
            try {
              await StorageService().logout();
            } catch (e) {
              print('Logout error: $e');
            }
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/welscreen',
                (route) => false,
              );
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            tooltip: 'إعدادات الإشعارات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBodyContent(
            student,
            totalDays,
            presentDays,
            absentDays,
            attendancePct,
            last30,
            sw,
            sh,
            responsive,
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: BubbleAppBar(
              currentIndex: _currentIndex,
              onTap: (index) async {
                if (index == 4) {
                  var teacherId = student.teacherId ?? '';
                  if (teacherId.isEmpty && student.teacherName.isNotEmpty) {
                    final teacher = await _storage.getTeacherByName(
                      student.teacherName,
                    );
                    if (teacher != null) {
                      teacherId = teacher.id ?? '';
                      if (_student.id == student.id) {
                        _student = _student.copyWith(teacherId: teacherId);
                        _storage.updateStudent(_student);
                      }
                    }
                  }
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          studentId: student.id,
                          studentName: student.name,
                          teacherName: student.teacherName,
                          teacherId: teacherId,
                          isTeacher: false,
                        ),
                      ),
                    );
                  }
                  return;
                }
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 90.0),
              child: FloatingActionButton(
                backgroundColor: regsin,
                onPressed: () async {
                  await _exportAsPdf();
                },
                child: const Icon(Icons.picture_as_pdf, color: Colors.black),
              ),
            )
          : null,
    ),
    );
  }

  Widget _buildBodyContent(
    Student student,
    int totalDays,
    int presentDays,
    int absentDays,
    double attendancePct,
    List<bool> last30,
    double sw,
    double sh,
    ResponsiveHelper responsive,
  ) {
    switch (_currentIndex) {
      case 1:
        return const AdhkarCategoriesScreen();
      case 2:
        return const LessonsScreen();
      case 3:
        return const MushafScreen();
      case 0:
      default:
        return _buildMainDashboard(
          student,
          totalDays,
          presentDays,
          absentDays,
          attendancePct,
          last30,
          sw,
          sh,
          responsive,
        );
    }
  }

  Widget _buildMainDashboard(
    Student student,
    int totalDays,
    int presentDays,
    int absentDays,
    double attendancePct,
    List<bool> last30,
    double sw,
    double sh,
    ResponsiveHelper responsive,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [backcolor, textcolor.withOpacity(0.8)],
        ),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(12.0),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              const PrayerTimesWidget(),
              const SizedBox(height: 20),
              // Teacher Info Container
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Icon(
                          Icons.person,
                          color: Colors.white70,
                          size: 28,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          student.teacherName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "الأستاذ",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    Container(height: 40, width: 1, color: Colors.white24),
                    Column(
                      children: [
                        const Icon(
                          Icons.phone,
                          color: Colors.white70,
                          size: 28,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          student.teacherPhone,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "رقم التواصل",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              FadeTransition(
                opacity: _fadeAnimation,
                child: GestureDetector(
                  onTap: () {
                    List<List<String>> editablePrayers = student.prayers.isEmpty
                        ? []
                        : student.prayers
                              .map((day) => List<String>.from(day))
                              .toList();
                    List<String> editableMemorization = List<String>.from(
                      student.memorization,
                    );
                    List<bool> editableAttendance = List<bool>.from(
                      student.attendance,
                    );

                    showDialog(
                      context: context,
                      builder: (context) => StatefulBuilder(
                        builder: (context, setState) => AlertDialog(
                          title: Text(
                            'جدول متابعة ${student.name}',
                            style: TextStyle(
                              fontSize: responsive.fontSize(16),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width < 700
                                  ? MediaQuery.of(context).size.width - 40
                                  : 700,
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.8,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  // جدول الصلاة
                                  const Text(
                                    'الصلاة',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  // -- تحسين الأداء: استخدام ListView.builder بدلاً من Table --
                                  Container(
                                    height: 250, // تحديد ارتفاع ثابت للحاوية
                                    decoration: BoxDecoration(
                                      color: textcolor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        // --- رأس الجدول ---
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8.0,
                                          ),
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.white24,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: const [
                                              Expanded(
                                                flex: 2,
                                                child: Center(
                                                  child: Text(
                                                    'اليوم',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Center(
                                                  child: Text(
                                                    'الفجر',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Center(
                                                  child: Text(
                                                    'الظهر',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Center(
                                                  child: Text(
                                                    'العصر',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Center(
                                                  child: Text(
                                                    'المغرب',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Center(
                                                  child: Text(
                                                    'العشاء',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // --- جسم الجدول (القائمة) ---
                                        Expanded(
                                          child: editablePrayers.isEmpty
                                              ? const Center(
                                                  child: Text(
                                                    'لا توجد بيانات',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                )
                                              : ListView.builder(
                                                  itemCount:
                                                      editablePrayers.length,
                                                  itemBuilder: (context, dayIndex) {
                                                    List<String> dayPrayers =
                                                        editablePrayers[dayIndex];
                                                    return Container(
                                                      decoration:
                                                          const BoxDecoration(
                                                            border: Border(
                                                              bottom: BorderSide(
                                                                color: Colors
                                                                    .white10,
                                                              ),
                                                            ),
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            flex: 2,
                                                            child: Center(
                                                              child: Text(
                                                                'يوم ${dayIndex + 1}',
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          ...dayPrayers.asMap().entries.map((
                                                            prayerEntry,
                                                          ) {
                                                            int prayerIndex =
                                                                prayerEntry.key;
                                                            String prayer =
                                                                prayerEntry
                                                                    .value;
                                                            return Expanded(
                                                              flex: 3,
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          2.0,
                                                                    ),
                                                                child: DropdownButton<String>(
                                                                  value: prayer,
                                                                  dropdownColor:
                                                                      textcolor,
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                                  isExpanded:
                                                                      true,
                                                                  underline:
                                                                      const SizedBox.shrink(),
                                                                  isDense: true,
                                                                  items:
                                                                      [
                                                                            'جماعة',
                                                                            'أداء',
                                                                            'قضاء',
                                                                            'فائتة',
                                                                            'غياب',
                                                                          ]
                                                                          .map(
                                                                            (
                                                                              option,
                                                                            ) => DropdownMenuItem(
                                                                              value: option,
                                                                              child: Center(
                                                                                child: Text(
                                                                                  option,
                                                                                  style: const TextStyle(
                                                                                    color: Colors.white,
                                                                                    fontSize: 12,
                                                                                  ),
                                                                                  overflow: TextOverflow.ellipsis,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          )
                                                                          .toList(),
                                                                  onChanged: (value) {
                                                                    setState(() {
                                                                      editablePrayers[dayIndex][prayerIndex] =
                                                                          value!;
                                                                    });
                                                                  },
                                                                ),
                                                              ),
                                                            );
                                                          }),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // الكود القديم للجدول
                                  /*
                                  ...
                                  ...
                                  ...
                                  */
                                  /*
                                  Container(
                                    decoration: BoxDecoration(
                                      color: textcolor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Table(
                                        border: TableBorder.all(
                                          color: Colors.white24,
                                        ),
                                        defaultColumnWidth:
                                            const FixedColumnWidth(80),
                                        children: [
                                          ...
                                          ...editablePrayers.asMap().entries.map((
                                            entry,
                                          ) {
                                            int dayIndex = entry.key;
                                            List<String> dayPrayers =
                                                entry.value;
                                            return TableRow(
                                                children: [
                                                  Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: Text(
                                                      'يوم ${dayIndex + 1}',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  ...dayPrayers.asMap().entries.map((
                                                    prayerEntry,
                                                  ) {
                                                    int prayerIndex =
                                                        prayerEntry.key;
                                                    String prayer =
                                                        prayerEntry.value;
                                                    return Padding(
                                                      padding: EdgeInsets.all(
                                                        4,
                                                      ),
                                                      child: DropdownButton<String>(
                                                        value: prayer,
                                                        dropdownColor:
                                                            textcolor,
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                        ),
                                                        isDense: true,
                                                        items:
                                                            [
                                                                  'جماعة',
                                                                  'أداء',
                                                                  'قضاء',
                                                                  'فائتة',
                                                                  'غياب',
                                                                ]
                                                                .map(
                                                                  (
                                                                    option,
                                                                  ) => DropdownMenuItem(
                                                                    value:
                                                                        option,
                                                                    child: Text(
                                                                      option,
                                                                      style: TextStyle(
                                                                        color: Colors
                                                                            .white,
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                )
                                                                .toList(),
                                                        onChanged: (value) {
                                                          setState(() {
                                                            editablePrayers[dayIndex][prayerIndex] =
                                                                value!;
                                                          });
                                                        },
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              );
                                            }),
                                        ],),),),),
                                  */
                                  const SizedBox(height: 20),
                                  // جدول الحضور
                                  const Text(
                                    'الحضور',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: textcolor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Table(
                                        border: TableBorder.all(
                                          color: Colors.white24,
                                        ),
                                        defaultColumnWidth:
                                            const FixedColumnWidth(100),
                                        children: [
                                          const TableRow(
                                            children: [
                                              Padding(
                                                padding: EdgeInsets.all(4),
                                                child: Text(
                                                  'اليوم',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.all(4),
                                                child: Text(
                                                  'الحالة',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (editableAttendance.isEmpty)
                                            const TableRow(
                                              children: [
                                                Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Text(
                                                    'لا توجد بيانات',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Text(
                                                    '',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            ...editableAttendance.asMap().entries.map((
                                              entry,
                                            ) {
                                              int dayIndex = entry.key;
                                              bool present = entry.value;
                                              return TableRow(
                                                children: [
                                                  Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: Text(
                                                      'يوم ${dayIndex + 1}',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: DropdownButton<bool>(
                                                      value: present,
                                                      dropdownColor: textcolor,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                      ),
                                                      isDense: true,
                                                      items: [
                                                        DropdownMenuItem(
                                                          value: true,
                                                          child: Text(
                                                            'حاضر',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                        DropdownMenuItem(
                                                          value: false,
                                                          child: Text(
                                                            'غائب',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                      onChanged: (value) {
                                                        setState(() {
                                                          editableAttendance[dayIndex] =
                                                              value!;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  // جدول الحفظ
                                  const Text(
                                    'الحفظ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: textcolor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Table(
                                        border: TableBorder.all(
                                          color: Colors.white24,
                                        ),
                                        defaultColumnWidth:
                                            const FixedColumnWidth(100),
                                        children: [
                                          const TableRow(
                                            children: [
                                              Padding(
                                                padding: EdgeInsets.all(4),
                                                child: Text(
                                                  'اليوم',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.all(4),
                                                child: Text(
                                                  'التقييم',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (editableMemorization.isEmpty)
                                            const TableRow(
                                              children: [
                                                Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Text(
                                                    'لا توجد بيانات',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Text(
                                                    '',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            ...editableMemorization.asMap().entries.map((
                                              entry,
                                            ) {
                                              int dayIndex = entry.key;
                                              String memorization = entry.value;
                                              return TableRow(
                                                children: [
                                                  Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: Text(
                                                      'يوم ${dayIndex + 1}',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: DropdownButton<String>(
                                                      value: memorization,
                                                      dropdownColor: textcolor,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                      ),
                                                      isDense: true,
                                                      items:
                                                          [
                                                                'ممتاز',
                                                                'جيد',
                                                                'ضعيف',
                                                                'غياب',
                                                              ]
                                                              .map(
                                                                (
                                                                  option,
                                                                ) => DropdownMenuItem(
                                                                  value: option,
                                                                  child: Text(
                                                                    option,
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                  ),
                                                                ),
                                                              )
                                                              .toList(),
                                                      onChanged: (value) {
                                                        setState(() {
                                                          editableMemorization[dayIndex] =
                                                              value!;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ), // end Column
                            ), // end SingleChildScrollView
                          ), // end ConstrainedBox
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('إلغاء'),
                            ),
                            TextButton(
                              onPressed: () async {
                                // حفظ التغييرات مع قفل تسجيل الحضور لليوم
                                final storage = StorageService();
                                final students = await storage.loadStudents();
                                final idx = students.indexWhere(
                                  (s) => s.id == student.id,
                                );
                                if (idx != -1) {
                                  final prev = students[idx];
                                  final today = DateTime.now();
                                  final todayStr =
                                      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

                                  // إذا تم تسجيل الحضور اليوم مسبقًا، امنع التعديل وأعلم المستخدم
                                  if (prev.attendanceDates.contains(todayStr)) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'تم تسجيل الحضور لهذا اليوم بالفعل',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  // حدد حالة الحضور لليوم من آخر صف في editableAttendance إن وُجد
                                  final bool todaysStatus =
                                      editableAttendance.isNotEmpty
                                      ? editableAttendance.last
                                      : false;

                                  final updatedAttendance = [
                                    ...prev.attendance,
                                    todaysStatus,
                                  ];
                                  final updatedAttendanceDates = [
                                    ...prev.attendanceDates,
                                    todayStr,
                                  ];

                                  students[idx] = Student(
                                    id: prev.id,
                                    name: prev.name,
                                    phone: prev.phone,
                                    teacherName: prev.teacherName,
                                    teacherPhone: prev.teacherPhone,
                                    email: prev.email,
                                    password: prev.password,
                                    points: prev.points,
                                    attendance: updatedAttendance,
                                    attendanceDates: updatedAttendanceDates,
                                    prayers: editablePrayers,
                                    prayerDates: prev.prayerDates,
                                    memorization: editableMemorization,
                                    dailyPointsAdded: prev.dailyPointsAdded,
                                    lastPointsDate: prev.lastPointsDate,
                                  );
                                  await storage.saveStudents(students);
                                }
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم حفظ التغييرات'),
                                  ),
                                );
                              },
                              child: const Text('حفظ'),
                            ),
                          ],
                        ), // end AlertDialog
                      ), // end StatefulBuilder
                    );
                  },
                  child: Card(
                    elevation: 6,

                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(children: [
                           
                          
                          ],
                        ),
                    ),
                  ),
                ),
              ),

              // Prayer Table Button
              Directionality(
                textDirection: TextDirection.rtl,
                child: Align(
                  alignment: Alignment.center,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: regsin,
                      foregroundColor: const Color.fromARGB(255, 255, 255, 255),
                      padding: EdgeInsets.symmetric(
                        horizontal: math.max(16, sw * 0.06),
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PraysScreen(
                            student: student,
                            onUpdate: (updatedStudent) {
                              // This callback updates the StudentInterface's state and
                              // persists the change locally.
                              if (mounted) {
                                // Also save to local storage to ensure persistence
                                // if the user closes the app right after.
                                _storage.updateStudent(updatedStudent);
                                setState(() => _student = updatedStudent);
                              }
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.mosque),
                    label: const Text(
                      'إدخال صلاة اليوم',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // أزرار جديدة: الإحصائيات والأوسمة
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: regsin,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PrayerStatsScreen(student: student),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bar_chart),
                      label: const Text(
                        'الإحصائيات',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: regsin,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BadgesScreen(student: student),
                          ),
                        );
                      },
                      icon: const Icon(Icons.emoji_events),
                      label: const Text(
                        'الأوسمة',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Attendance Chart
              ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _fadeController,
                    curve: Curves.easeOut,
                  ),
                ),
                child: Container(
                  key: _attendanceChartKey,
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),

                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'الحضور (آخر 30 يوم)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 17,
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,

                                MaterialPageRoute(
                                  builder: (_) => PraysScreen(student: student),
                                ),
                              );
                              await _refreshLocalStudent();
                            },
                            icon: Icon(
                              Icons.mosque,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        height: math.min(350, sh * 0.36),

                        child: BarChart(
                          BarChartData(
                            barGroups: last30.asMap().entries.map((entry) {
                              int day = entry.key;

                              bool present = entry.value;

                              return BarChartGroupData(
                                x: day,

                                barRods: [
                                  BarChartRodData(
                                    toY: present ? 1 : 0,

                                    gradient: LinearGradient(
                                      colors: present
                                          ? [Colors.greenAccent, Colors.green]
                                          : [Colors.redAccent, Colors.red],

                                      begin: Alignment.bottomCenter,

                                      end: Alignment.topCenter,
                                    ),

                                    width: 12,

                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              );
                            }).toList(),

                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,

                                  getTitlesWidget: (value, meta) => Text(
                                    '${value.toInt() + 1}',

                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),

                                  interval: last30.length > 10
                                      ? (last30.length / 10).ceilToDouble()
                                      : 1,
                                ),
                              ),

                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,

                                  getTitlesWidget: (value, meta) => Text(
                                    value == 1 ? 'حاضر' : 'غائب',

                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),

                                  reservedSize: 50,
                                ),
                              ),

                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),

                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),

                            borderData: FlBorderData(show: false),

                            gridData: FlGridData(
                              show: true,

                              drawVerticalLine: false,

                              horizontalInterval: 0.5,

                              getDrawingHorizontalLine: (value) =>
                                  FlLine(color: Colors.white10, strokeWidth: 1),
                            ),

                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Prayer Chart Stats
              Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatCard(
                            title: 'الحضور (آخر 30 يوم)',
                            value: presentDays.toString(),
                            icon: Icons.event_available,
                            color: Colors.greenAccent,
                          ),
                          _StatCard(
                            title: 'الغياب',
                            value: absentDays.toString(),
                            icon: Icons.event_busy,
                            color: Colors.redAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          '   نسبة الحضور: ${attendancePct.toStringAsFixed(1)}%'
                          '     ${totalDays == 0 ? '' : ' من أصل $totalDays يوم'} ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 120), // Extra space for BubbleAppBar
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color? color;
  const _StatCard({
    required this.title,
    required this.value,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            if (icon != null)
              Icon(icon, color: color ?? Colors.white, size: 28)
            else
              const SizedBox(height: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
