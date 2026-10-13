import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/patients/presentation/providers/patient_providers.dart';
import 'package:studentry/patients/presentation/widgets/appointment_datetime_picker.dart';
import 'package:studentry/patients/presentation/widgets/appointment_form_overview.dart';
import 'package:studentry/utils/variable_colors.dart';

class NewAppointmentScreen extends ConsumerStatefulWidget {
  const NewAppointmentScreen({
    super.key,
    this.initialDate,
    this.appointment,
    this.initialPatient,
  });

  final DateTime? initialDate;
  final Appointment? appointment;
  final PatientProfile? initialPatient;

  @override
  ConsumerState<NewAppointmentScreen> createState() =>
      _NewAppointmentScreenState();
}

class _NewAppointmentScreenState extends ConsumerState<NewAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _treatmentController = TextEditingController();
  String? _patientId;
  late DateTime _date;
  late TimeOfDay _time;
  bool _saving = false;

  bool get _editing => widget.appointment != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.appointment;
    final suggested = DateTime.now().add(const Duration(hours: 1));
    _date = existing?.date ?? widget.initialDate ?? suggested;
    final parts = existing?.time.split(':');
    _time = parts != null && parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? suggested.hour,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : TimeOfDay(hour: suggested.hour, minute: 0);
    _patientId = existing?.patientId ?? widget.initialPatient?.id;
    _treatmentController.text = existing?.treatment ?? '';
    Future.microtask(
      () => ref.read(patientDirectoryProvider.notifier).loadFirstPage(),
    );
  }

  @override
  void dispose() {
    _treatmentController.dispose();
    super.dispose();
  }

  Future<void> _chooseDateTime() async {
    final selection = await showAppointmentDateTimePicker(
      context: context,
      initialDate: _date,
      initialTime: _time,
    );
    if (selection != null && mounted) {
      setState(() {
        _date = selection.date;
        _time = selection.time;
      });
    }
  }

  Future<void> _save(List<PatientProfile> patients) async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final selectedId = _patientId;
    if (selectedId == null) return;
    final selected = patients.where((p) => p.id == selectedId).firstOrNull;
    final existing = widget.appointment;
    final patientName = selected?.name ?? existing?.patientName;
    if (patientName == null) return;

    setState(() => _saving = true);
    final status =
        existing?.status ??
        (selected?.whatsappOptIn == true ? 'بانتظار التأكيد' : 'مؤكد');
    final appointment = Appointment(
      id: existing?.id,
      patientId: selectedId,
      patientName: patientName,
      treatment: _treatmentController.text.trim(),
      status: status,
      date: _date,
      time:
          '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
      reminderSent: existing?.reminderSent ?? false,
      notificationSent: existing?.notificationSent ?? false,
    );
    try {
      final notifier = ref.read(appointmentListProvider.notifier);
      if (existing == null) {
        await notifier.add(appointment);
      } else {
        await notifier.update(existing.id, appointment);
      }
      if (mounted) Navigator.pop(context, true);
    } on AppointmentTimeConflictException {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا الوقت محجوز. اختر وقتاً آخر.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر حفظ الموعد: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(patientDirectoryProvider);
    final patients = [
      ...directory,
      if (widget.initialPatient != null &&
          !directory.any((p) => p.id == widget.initialPatient!.id))
        widget.initialPatient!,
    ];
    final patientItems = <String, String>{
      for (final patient in patients) patient.id: patient.name,
      if (_editing &&
          !patients.any((p) => p.id == widget.appointment!.patientId))
        widget.appointment!.patientId: widget.appointment!.patientName,
    };
    final selectedName = patientItems[_patientId] ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_editing ? 'تعديل الموعد' : 'موعد جديد')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: patientItems.containsKey(_patientId)
                    ? _patientId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'المريض',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: patientItems.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _editing
                    ? null
                    : (value) => setState(() => _patientId = value),
                validator: (value) => value == null ? 'اختر المريض' : null,
              ),
              if (patients.isEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'لا يوجد مرضى بعد. أضف المريض أولاً ثم أنشئ موعده.',
                  style: TextStyle(color: AppColors.textGray),
                ),
              ],
              const SizedBox(height: 16),
              AppointmentFormOverview(
                patientName: selectedName,
                date: _date,
                time: _time,
                onChooseDateTime: _chooseDateTime,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _treatmentController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'سبب الزيارة (اختياري)',
                  prefixIcon: Icon(Icons.medical_services_outlined),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving || patients.isEmpty && !_editing
                    ? null
                    : () => _save(patients),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.event_available_rounded),
                label: Text(_editing ? 'حفظ التعديلات' : 'إنشاء الموعد'),
              ),
              if (ref.read(patientDirectoryProvider.notifier).hasMore)
                TextButton(
                  onPressed: () =>
                      ref.read(patientDirectoryProvider.notifier).loadMore(),
                  child: const Text('تحميل المزيد من المرضى'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
