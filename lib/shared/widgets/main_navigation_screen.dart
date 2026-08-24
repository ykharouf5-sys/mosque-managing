import 'package:dentalcare/patients/presentation/appointments_screen.dart';
import 'package:dentalcare/patients/presentation/reports_screen.dart';
import 'package:dentalcare/shared/widgets/app_bottom_nav.dart';
import 'package:dentalcare/store/presentation/store_screen.dart';
import 'package:dentalcare/student/presentation/student_home_screen.dart';
import 'package:dentalcare/student/presentation/university_screen.dart';
import 'package:flutter/material.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 4);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        onPageChanged: (index) => setState(() => _index = index),
        children: const [
          StudentHomeScreen(embedded: true),
          AppointmentsScreen(embedded: true),
          UniversityScreen(embedded: true),
          StoreScreen(embedded: true),
          ReportsScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _index,
        showAddButton: _index == 0 || _index == 1,
        onSelected: _select,
      ),
    );
  }
}
