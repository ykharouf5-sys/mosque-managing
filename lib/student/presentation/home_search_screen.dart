import 'package:flutter/material.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/patients/presentation/patient_profile_screen.dart';
import 'package:studentry/patients/presentation/appointments_screen.dart';
import 'package:studentry/student/data/academic_store.dart';
import 'package:studentry/utils/app_input_formatters.dart';
import 'widgets/home_dashboard_widgets.dart';

class HomeSearchScreen extends StatefulWidget {
  const HomeSearchScreen({super.key, this.chooseSection = false});
  final bool chooseSection;
  @override
  State<HomeSearchScreen> createState() => _HomeSearchScreenState();
}

class _HomeSearchScreenState extends State<HomeSearchScreen> {
  String _query = '', _section = 'الكل';
  List<PatientProfile> _patients = [];
  List<Appointment> _appointments = [];
  bool _loading = true, _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final generation = AppDatabase.captureActiveDataGeneration();
      final patients = await AppDatabase.getAllPatients();
      final appointments = await AppDatabase.getAllAppointments();
      AppDatabase.ensureDataGeneration(generation);
      if (!mounted) return;
      setState(() {
        _patients = patients
            .map(patientRowToProfile)
            .whereType<PatientProfile>()
            .toList();
        _appointments = appointments
            .map(appointmentRowToAppointment)
            .whereType<Appointment>()
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  bool _match(String value) =>
      value.toLowerCase().contains(_query.trim().toLowerCase());
  bool _show(String section) => _section == 'الكل' || _section == section;
  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    final hasQuery = _query.trim().isNotEmpty;
    final patients = hasQuery
        ? _patients
              .where((patient) => _match('${patient.name} ${patient.phone}'))
              .toList()
        : <PatientProfile>[];
    final appointments = hasQuery
        ? _appointments
              .where((a) => _match('${a.patientName} ${a.treatment} ${a.time}'))
              .toList()
        : <Appointment>[];
    final subjects = AcademicStore.instance.enrollments
        .where((e) => hasQuery && _match('${e.name} ${e.code} ${e.doctorName}'))
        .toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: p.background,
        appBar: AppBar(
          title: const Text('البحث'),
          backgroundColor: p.background,
          foregroundColor: p.text,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              autofocus: !widget.chooseSection,
              inputFormatters: AppInputFormatters.text(120),
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value),
              style: TextStyle(color: p.text),
              decoration: InputDecoration(
                hintText: 'ابحث عن مريض، موعد، مادة أو منتج...',
                hintStyle: TextStyle(color: p.muted),
                filled: true,
                fillColor: p.surface,
                prefixIcon: Icon(Icons.search_rounded, color: p.muted),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: ['الكل', 'المرضى', 'المواعيد', 'المواد', 'المنتجات']
                  .map(
                    (section) => ChoiceChip(
                      label: Text(section),
                      selected: section == _section,
                      onSelected: (_) => setState(() => _section = section),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_failed)
              const Text(
                'تعذر تحميل البحث المحلي. يمكنك البحث في المتجر أو المحاولة لاحقًا.',
              ),
            if (!hasQuery)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'اكتب كلمة للبحث في بياناتك أو المتجر.',
                  textAlign: TextAlign.center,
                ),
              ),
            if (_show('المرضى'))
              ...patients.map(
                (patient) => ListTile(
                  leading: const Icon(
                    Icons.person_outline_rounded,
                    color: HomePalette.teal,
                  ),
                  title: Text(patient.name),
                  subtitle: Text(patient.phone),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatientProfileScreen(patient: patient),
                    ),
                  ),
                ),
              ),
            if (_show('المواعيد'))
              ...appointments.map(
                (a) => ListTile(
                  leading: const Icon(
                    Icons.event_outlined,
                    color: HomePalette.teal,
                  ),
                  title: Text(a.patientName),
                  subtitle: Text(
                    '${a.time} • ${a.date.day}/${a.date.month}/${a.date.year} • ${a.treatment}',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppointmentsScreen(),
                    ),
                  ),
                ),
              ),
            if (_show('المواد'))
              ...subjects.map(
                (e) => ListTile(
                  leading: const Icon(
                    Icons.school_outlined,
                    color: HomePalette.teal,
                  ),
                  title: Text(e.name),
                  subtitle: Text(e.code),
                  onTap: () => Navigator.pushNamed(context, '/schedule'),
                ),
              ),
            if (hasQuery &&
                !_loading &&
                !_failed &&
                patients.isEmpty &&
                appointments.isEmpty &&
                subjects.isEmpty &&
                _section != 'المنتجات')
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'لا توجد نتائج محلية مطابقة.',
                  textAlign: TextAlign.center,
                ),
              ),
            if (hasQuery && _show('المنتجات'))
              ListTile(
                leading: const Icon(
                  Icons.storefront_outlined,
                  color: HomePalette.teal,
                ),
                title: Text('البحث عن «${_query.trim()}» في المتجر'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/search-results',
                  arguments: _query.trim(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
