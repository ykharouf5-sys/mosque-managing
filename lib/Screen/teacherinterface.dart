import 'package:flutter/material.dart';
import 'package:yaman/models/teacher.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/models/message.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/Screen/Chat_screen.dart';
import 'package:yaman/Screen/notification_settings_screen.dart';
import 'package:yaman/Screen/student_details_screen.dart';
import 'package:yaman/Screen/adhkar_categories_screen.dart';
import 'package:yaman/Screen/lessons_screen.dart';
import 'package:yaman/Screen/mushaf_screen.dart';
import 'package:yaman/utils/responsive_helper.dart';
import 'package:yaman/widget/app_footer.dart';
import 'package:yaman/widget/bubble_app_bar.dart';



class StudentCard extends StatefulWidget {
  final Student student;
  final bool attendanceSubmitted;
  final bool? attendanceToday;
  final ValueChanged<bool?> onAttendanceChanged;
  final ValueChanged<int> onAddPointsAmount;
  final ValueChanged<List<String>> onAddPrayer;
  final VoidCallback onLongPress;

  const StudentCard({
    super.key,
    required this.student,
    required this.attendanceSubmitted,
    required this.attendanceToday,
    required this.onAttendanceChanged,
    required this.onAddPointsAmount,
    required this.onAddPrayer,
    required this.onLongPress,
  });

  @override
  State<StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<StudentCard> {
  Color _cardColor() {
    if (widget.attendanceToday == null) {
      return Colors.white.withOpacity(0.05);
    } else if (widget.attendanceToday == true) {
      return Colors.green.withOpacity(0.2);
    } else {
      return Colors.red.withOpacity(0.2);
    }
  }

  Color _borderColor() {
    if (widget.attendanceToday == null) {
      return Colors.white.withOpacity(0.1);
    } else if (widget.attendanceToday == true) {
      return Colors.green.withOpacity(0.5);
    } else {
      return Colors.red.withOpacity(0.5);
    }
  }

  void _showCustomPointsDialog(BuildContext context) {
    final TextEditingController pointsController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: textcolor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إضافة أو خصم نقاط',
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: pointsController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'أدخل القيمة (مثال: 50 أو -50)',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: regsin),
            onPressed: () {
              int? val = int.tryParse(pointsController.text);
              if (val != null) {
                widget.onAddPointsAmount(val);
                Navigator.pop(context);
              }
            },
            child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: _cardColor().withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor().withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header with student name and points
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [regsin, regsin.withOpacity(0.4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: regsin.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.student.name.characters.first,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: responsive.fontSize(26),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Name and Points
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.student.name,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: responsive.fontSize(18),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '${widget.student.points} نقطة',
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                Container(height: 1, color: Colors.white.withOpacity(0.05)),
                const SizedBox(height: 20),
                
                // Action Label
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('إدارة النقاط', 
                      style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Icon(Icons.control_point_duplicate_rounded, color: Colors.white38, size: 14),
                  ],
                ),
                const SizedBox(height: 12),

                // Points buttons organized
                Row(
                  children: [
                    Expanded(child: _TeacherGiftButton(label: '+10', onTap: () => widget.onAddPointsAmount(10))),
                    const SizedBox(width: 8),
                    Expanded(child: _TeacherGiftButton(label: '+15', onTap: () => widget.onAddPointsAmount(15))),
                    const SizedBox(width: 8),
                    Expanded(child: _TeacherGiftButton(label: '+20', onTap: () => widget.onAddPointsAmount(20))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _TeacherGiftButton(label: '-5', color: Colors.orange.withOpacity(0.15), borderColor: Colors.orange.withOpacity(0.3), onTap: () => widget.onAddPointsAmount(-5))),
                    const SizedBox(width: 8),
                    Expanded(child: _TeacherGiftButton(label: '-10', color: Colors.red.withOpacity(0.15), borderColor: Colors.red.withOpacity(0.3), onTap: () => widget.onAddPointsAmount(-10))),
                    const SizedBox(width: 8),
                    Expanded(child: _TeacherGiftButton(label: 'تخصيص', color: Colors.blue.withOpacity(0.15), borderColor: Colors.blue.withOpacity(0.3), onTap: () => _showCustomPointsDialog(context))),
                  ],
                ),
                
                const SizedBox(height: 20),
                Container(height: 1, color: Colors.white.withOpacity(0.05)),
                const SizedBox(height: 20),

                // Attendance Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'سجل الحضور',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.fact_check_outlined, color: Colors.white.withOpacity(0.7), size: 20),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!widget.attendanceSubmitted)
                      Row(
                        children: [
                          Expanded(
                            child: _AttendanceButton(
                              label: 'حاضر',
                              icon: Icons.check_circle_rounded,
                              isSelected: widget.attendanceToday == true,
                              selectedColor: Colors.green,
                              onTap: () => widget.onAttendanceChanged(true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _AttendanceButton(
                              label: 'غائب',
                              icon: Icons.cancel_rounded,
                              isSelected: widget.attendanceToday == false,
                              selectedColor: Colors.red,
                              onTap: () => widget.onAttendanceChanged(false),
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: widget.attendanceToday == true
                              ? Colors.green.withOpacity(0.2)
                              : widget.attendanceToday == false
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: widget.attendanceToday == true
                                ? Colors.green.withOpacity(0.5)
                                : widget.attendanceToday == false
                                    ? Colors.red.withOpacity(0.5)
                                    : Colors.white.withOpacity(0.1),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.attendanceToday == true
                                  ? Icons.check_circle
                                  : widget.attendanceToday == false
                                      ? Icons.cancel
                                      : Icons.help_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              (widget.attendanceToday == true)
                                  ? 'تم تسجيل الحضور'
                                  : (widget.attendanceToday == false)
                                      ? 'تم تسجيل الغياب'
                                      : 'لم يتم التسجيل',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TeacherInterface extends StatefulWidget {
  final Teacher teacher;
  const TeacherInterface({super.key, required this.teacher});

  @override
  State<TeacherInterface> createState() => _TeacherInterfaceState();
}

class _TeacherInterfaceState extends State<TeacherInterface> {
  final StorageService _storage = StorageService();
  List<Student> _students = [];
  Map<String, bool?> _attendanceToday = {};
  bool _isSearching = false;
  bool _attendanceSubmitted = false;
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.teacher.id != 'trial_teacher') {
      _loadStudents();
    } else {
      _students = []; 
      _attendanceToday = {};
      _attendanceSubmitted = false;
    }
  }

  Future<void> _loadStudents() async {
    if (widget.teacher.id == 'trial_teacher') return;
    final students = await _storage.loadStudents();
    final today = DateTime.now().toIso8601String().split('T')[0];

    setState(() {
      _students = students.where((s) => s.teacherName == widget.teacher.name).toList();
      
      _attendanceToday = {};
      bool alreadySubmitted = false;
      
      for (var s in _students) {
        if (s.attendanceDates.isNotEmpty && s.attendanceDates.last == today) {
          _attendanceToday[s.id] = s.attendance.last;
          alreadySubmitted = true;
        } else {
          _attendanceToday[s.id] = null;
        }
      }
      
      _attendanceSubmitted = alreadySubmitted; 
    });
  }

  Future<void> _submitAttendance() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    bool anyUpdated = false;
    bool alreadyRecorded = false;

    for (var s in _students) {
      final present = _attendanceToday[s.id];
      if (present != null) {
        final idx = _students.indexWhere((x) => x.id == s.id);
        
        if (s.attendanceDates.isNotEmpty && s.attendanceDates.last == today) {
          final updatedAttendance = List<bool>.from(s.attendance);
          if (updatedAttendance.isNotEmpty) {
             updatedAttendance.last = present;
          }
          
          _students[idx] = s.copyWith(
            attendance: updatedAttendance,
          );
          anyUpdated = true;
          alreadyRecorded = true;
        } else {
          _students[idx] = s.copyWith(
            points: present ? s.points + 10 : s.points,
            attendance: [...s.attendance, present],
            attendanceDates: [...s.attendanceDates, today],
          );
          anyUpdated = true;
        }
      }
    }

    if (anyUpdated) {
      await _storage.saveStudents(_students);
      setState(() {
        _attendanceSubmitted = true;
      });
      if (mounted) {
        if (alreadyRecorded) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث الحضور لهذا اليوم ✅')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تثبيت الحضور والغياب ✅')),
          );
        }
      }
    }
  }

  Future<void> _addPoints(Student s, int amount) async {
    final idx = _students.indexWhere((x) => x.id == s.id);
    if (idx == -1) return;
    int newPoints = (s.points + amount);
    if (newPoints < 0) newPoints = 0; // Prevent negative total points
    _students[idx] = s.copyWith(points: newPoints);
    setState(() {});
    await _storage.saveStudents(_students);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(amount > 0 ? 'تمت إضافة $amount نقطة لنجمنا ${s.name} 🌟' : 'تم خصم ${amount.abs()} نقطة من الطالب ${s.name}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _addPrayer(Student s, List<String> prayers) async {
    final idx = _students.indexWhere((x) => x.id == s.id);
    if (idx == -1) return;
    final currentDate = DateTime.now().toIso8601String().split('T')[0];
    _students[idx] = Student(
      id: s.id,
      name: s.name,
      phone: s.phone,
      teacherName: s.teacherName,
      teacherPhone: s.teacherPhone,
      points: s.points,
      attendance: s.attendance,
      attendanceDates: s.attendanceDates,
      email: s.email,
      password: s.password,
      prayers: [...s.prayers, prayers],
      prayerDates: [...s.prayerDates, currentDate],
      memorization: s.memorization,
    );
    setState(() {});
    await _storage.saveStudents(_students);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true,
      child: Scaffold(
        backgroundColor: backcolor,
        appBar: AppBar(
          title: _isSearching
              ? Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'بحث عن طالب...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: () {
                          setState(() {
                            _isSearching = false;
                            _searchController.clear();
                          });
                        },
                      ),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                )
              : Text(
                  textDirection: TextDirection.rtl,
                  "الأستاذ: ${widget.teacher.name}",
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
          leading: _isSearching
              ? null
              : IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white70),
                  onPressed: () async {
                    try {
                      await StorageService().logout();
                    } catch (e) {}
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/welscreen',
                        (route) => false,
                      );
                    }
                  },
                ),
          backgroundColor: backcolor,
          elevation: 4,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (!_isSearching)
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () => setState(() => _isSearching = true),
              ),
            IconButton(
              icon: const Icon(Icons.settings_rounded),
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
            _buildBodyContent(),
            
            Align(
              alignment: Alignment.bottomCenter,
              child: BubbleAppBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),
            ),
          ],
        ),
        floatingActionButton: _currentIndex == 0 ? (_attendanceSubmitted ? null : Padding(
          padding: const EdgeInsets.only(bottom: 90.0),
          child: FloatingActionButton.extended(
            onPressed: () {
                final someMarked = _students.any((s) => _attendanceToday[s.id] != null);
                if (!someMarked) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى تسجيل حضور أو غياب لبعض الطلاب على الأقل')),
                  );
                  return;
                }
                _submitAttendance();
            }, 
            label: const Text('حفظ السجل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            icon: const Icon(Icons.save_rounded),
            backgroundColor: regsin,
            foregroundColor: Colors.white,
            elevation: 8,
          ),
        )) : null,
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_currentIndex) {
      case 1:
        return const AdhkarCategoriesScreen();
      case 2:
        return const LessonsScreen();
      case 3:
        return const MushafScreen();
      case 4:
        return _TeacherChatsScreen(teacher: widget.teacher);
      case 0:
      default:
        return _buildMainDashboard();
    }
  }

  Widget _buildMainDashboard() {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backcolor, textcolor.withOpacity(0.8)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                // Summary Card - Glassmorphism
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSummaryStat(
                        icon: Icons.group,
                        title: 'الطلاب',
                        value: '${_students.length}',
                        color: Colors.blueAccent,
                      ),
                      Container(height: 40, width: 1, color: Colors.white.withOpacity(0.2)),
                      _buildSummaryStat(
                        icon: Icons.how_to_reg,
                        title: 'حضور',
                        value: '${_attendanceToday.values.where((v) => v == true).length}',
                        color: Colors.greenAccent,
                      ),
                      Container(height: 40, width: 1, color: Colors.white.withOpacity(0.2)),
                      _buildSummaryStat(
                        icon: Icons.person_off,
                        title: 'غياب',
                        value: '${_attendanceToday.values.where((v) => v == false).length}',
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Search and Controls
                if (!_attendanceSubmitted && _students.any((s) => _attendanceToday[s.id] == null))
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'اختصارات الحضور',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz, color: Colors.white70, size: 20),
                            color: textcolor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (value) {
                              setState(() {
                                if (value == 'all_present') {
                                  for (var s in _students) {
                                    _attendanceToday[s.id] = true;
                                  }
                                } else if (value == 'all_absent') {
                                  for (var s in _students) {
                                    _attendanceToday[s.id] = false;
                                  }
                                }
                              });
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'all_present', child: Text('تحديد الكل حضور', style: TextStyle(color: Colors.white))),
                              const PopupMenuItem(value: 'all_absent', child: Text('تحديد الكل غياب', style: TextStyle(color: Colors.white))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _students.where((s) => s.name.contains(_searchController.text)).length,
                    itemBuilder: (context, index) {
                      final s = _students.where((s) => s.name.contains(_searchController.text)).elementAt(index);
                      return StudentCard(
                        student: s,
                        attendanceSubmitted: _attendanceSubmitted,
                        attendanceToday: _attendanceToday[s.id],
                        onAttendanceChanged: (value) {
                          setState(() {
                            _attendanceToday[s.id] = value;
                          });
                        },
                        onAddPointsAmount: (amount) => _addPoints(s, amount),
                        onAddPrayer: (prayers) => _addPrayer(s, prayers),
                        onLongPress: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudentDetailsScreen(student: s),
                            ),
                          ).then((_) => _loadStudents());
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 120), // Extra space for BubbleAppBar
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildSummaryStat({required IconData icon, required String title, required String value, required Color color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
        ),
      ],
    );
  }
}

class _TeacherChatsScreen extends StatefulWidget {
  const _TeacherChatsScreen({required this.teacher});
  final Teacher teacher;

  @override
  State<_TeacherChatsScreen> createState() => _TeacherChatsScreenState();
}

class _TeacherChatsScreenState extends State<_TeacherChatsScreen> {
  final StorageService _storage = StorageService();
  List<Student> _students = [];
  List<Message> _messages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final students = (await _storage.loadStudents())
        .where((s) => s.teacherName == widget.teacher.name)
        .toList();
    final messages = await _storage.loadMessages();
    setState(() {
      _students = students;
      _messages = messages;
    });
  }

  List<_Thread> _threads() {
    final threads = <_Thread>[];
    for (final s in _students) {
      final conv = _messages.where((Message m) =>
          (m.senderId == s.id && m.receiverName == widget.teacher.name) ||
          (m.senderName == widget.teacher.name && m.receiverId == s.id));
      if (conv.isNotEmpty) {
        final latest = conv.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
        threads.add(_Thread(student: s, last: latest));
      } else {
        threads.add(_Thread(student: s, last: null));
      }
    }
    threads.sort((a, b) {
      final at = a.last?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.last?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return threads;
  }

  @override
  Widget build(BuildContext context) {
    final list = _threads();
    return Scaffold(
      backgroundColor: backcolor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'محادثات الطلاب',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backcolor, textcolor.withOpacity(0.8)],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: regsin,
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final t = list[index];
                final subtitle = t.last?.text ?? 'ابدأ المحادثة';
                final time = t.last?.timestamp;
                return Card(
                  color: Colors.white.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: regsin.withOpacity(0.2),
                      child: Text(t.student.name[0], style: TextStyle(color: regsin, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(t.student.name, textDirection: TextDirection.rtl, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(subtitle, textDirection: TextDirection.rtl, style: const TextStyle(color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: time != null
                        ? Text('${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}', style: const TextStyle(color: Colors.white54))
                        : const SizedBox.shrink(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            studentId: t.student.id,
                            studentName: t.student.name,
                            teacherName: widget.teacher.name,
                            teacherId: widget.teacher.id ?? '', isTeacher: false,
                          ),
                        ),
                      ).then((_) => _load());
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Thread {
  _Thread({required this.student, required this.last});
  final Student student;
  final Message? last;
}

class _PrayerStatus extends StatelessWidget {
  const _PrayerStatus({required this.prayer, required this.status});
  final String prayer;
  final String status;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (status) {
      case 'جماعة':
        icon = Icons.groups;
        color = Colors.green;
        break;
      case 'أداء':
        icon = Icons.check_circle;
        color = Colors.lightBlueAccent;
        break;
      case 'قضاء':
        icon = Icons.timelapse;
        color = Colors.orangeAccent;
        break;
      case 'غياب':
        icon = Icons.cancel;
        color = Colors.redAccent;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    return Column(
      children: [
        Text(prayer, style: const TextStyle(color: Colors.white, fontSize: 12)),
        const SizedBox(height: 4),
        Icon(icon, color: color, size: 20),
      ],
    );
  }
}

class _TeacherGiftButton extends StatelessWidget {
  const _TeacherGiftButton({
    required this.label,
    required this.onTap,
    this.color,
    this.borderColor,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 42,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          highlightColor: regsin.withOpacity(0.2),
          splashColor: regsin.withOpacity(0.3),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _AttendanceButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? selectedColor.withOpacity(0.15) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? selectedColor.withOpacity(0.5) : Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: selectedColor.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ] : [],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? icon : Icons.circle_outlined,
              color: isSelected ? selectedColor : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
