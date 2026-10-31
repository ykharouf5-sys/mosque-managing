import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'home_dashboard_widgets.dart';

Widget _preview({bool dark = false}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData(useMaterial3: true),
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Builder(
      builder: (context) {
        final palette = HomePalette.of(context);
        return Scaffold(
          backgroundColor: palette.background,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const HomeHeader(
                name: 'معاينة الواجهة',
                reminders: 1,
                onProfile: _previewAdd,
                onNotifications: _previewAdd,
                onMenu: _previewAdd,
              ),
              const SizedBox(height: 16),
              const HomeSearchBar(onSearch: _previewAdd, onFilter: _previewAdd),
              const SizedBox(height: 16),
              const HomeBannerCarousel(banners: [], onAction: _previewAction),
              const SizedBox(height: 16),
              HomeStatisticsGrid(
                stats: const [
                  HomeStat(
                    title: 'محاضرات اليوم',
                    value: '—',
                    icon: Icons.school_rounded,
                    color: HomePalette.teal,
                    onTap: _previewAdd,
                  ),
                  HomeStat(
                    title: 'المواعيد اليوم',
                    value: '—',
                    icon: Icons.calendar_month_rounded,
                    color: HomePalette.teal,
                    onTap: _previewAdd,
                  ),
                  HomeStat(
                    title: 'مرضى اليوم',
                    value: '—',
                    icon: Icons.groups_rounded,
                    color: HomePalette.teal,
                    onTap: _previewAdd,
                  ),
                  HomeStat(
                    title: 'مصروفات اليوم',
                    value: '—',
                    icon: Icons.account_balance_wallet_rounded,
                    color: HomePalette.teal,
                    onTap: _previewAdd,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              HomeTodayCard(
                showAddButton: false,
                appointments: const [],
                onAdd: _previewAdd,
                onAppointment: _previewAppointment,
              ),
              const SizedBox(height: 12),
              const HomeDashboardActions(
                onAddAppointment: _previewAdd,
                onAddPatient: _previewAdd,
              ),
            ],
          ),
        );
      },
    ),
  ),
);
void _previewAction(dynamic banner) {}
void _previewAdd() {}
void _previewAppointment(dynamic appointment) {}

@Preview(
  name: 'الرئيسية المرجعية — فاتح',
  group: 'Home reference',
  size: Size(390, 700),
)
Widget homeReferenceLightPreview() => _preview();
@Preview(
  name: 'الرئيسية المرجعية — داكن',
  group: 'Home reference',
  size: Size(390, 700),
)
Widget homeReferenceDarkPreview() => _preview(dark: true);
