import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/patients/data/notification_service.dart';
import 'package:studentry/patients/presentation/providers/patient_providers.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:table_calendar/table_calendar.dart';

class AddPatientScreen extends ConsumerStatefulWidget {
  const AddPatientScreen({super.key});

  @override
  ConsumerState<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends ConsumerState<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _dueCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  final _treatmentCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  final List<TreatmentItem> _treatmentPlan = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _dueCtrl.dispose();
    _paidCtrl.dispose();
    _treatmentCtrl.dispose();
    super.dispose();
  }

  DateTime _weekStart(DateTime d) => d.subtract(Duration(days: d.weekday % 7));

  void _pickDateTime() {
    DateTime tempDate = _selectedDate;
    TimeOfDay tempTime = _selectedTime;
    DateTime weekStart = _weekStart(tempDate);
    final dayNames = [
      'أحد',
      'اثنين',
      'ثلاثاء',
      'أربعاء',
      'خميس',
      'جمعة',
      'سبت',
    ];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'اختر الموعد',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(
                  height: 1,
                  color: AppColors.divider.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      onPressed: () => setDialogState(() {
                        weekStart = weekStart.subtract(const Duration(days: 7));
                        if (tempDate.isAfter(
                          weekStart.add(const Duration(days: 6)),
                        )) {
                          tempDate = weekStart;
                        }
                      }),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Text(
                      DateFormat('MMMM yyyy', 'ar').format(weekStart),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_left,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      onPressed: () => setDialogState(() {
                        weekStart = weekStart.add(const Duration(days: 7));
                      }),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (i) {
                    final day = weekStart.add(Duration(days: i));
                    final isSelected = isSameDay(tempDate, day);
                    final isToday = isSameDay(DateTime.now(), day);
                    return GestureDetector(
                      onTap: () => setDialogState(() => tempDate = day),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dayNames[i],
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textGray,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: isSelected ? 4 : 2),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : isToday
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : null,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected || isToday
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textDark,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.access_time_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'اختر الوقت',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: tempTime,
                        );
                        if (t != null) setDialogState(() => tempTime = t);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tempTime.format(context),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.edit_outlined,
                              color: AppColors.primary,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'إلغاء',
                style: TextStyle(
                  color: AppColors.textGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onPressed: () {
                setState(() {
                  _selectedDate = tempDate;
                  _selectedTime = tempTime;
                });
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  void _addTreatmentItem() {
    final text = _treatmentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _treatmentPlan.add(
        TreatmentItem(
          procedureName: text,
          status: 'معلق',
          statusColor: AppColors.pending,
        ),
      );
      _treatmentCtrl.clear();
    });
  }

  void _toggleTreatment(int index) {
    setState(() {
      final item = _treatmentPlan[index];
      if (item.status == 'معلق') {
        item.status = 'مكتمل';
        item.statusColor = AppColors.success;
      } else {
        item.status = 'معلق';
        item.statusColor = AppColors.pending;
      }
    });
  }

  void _deleteTreatment(int index) {
    setState(() => _treatmentPlan.removeAt(index));
  }

  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    final id = generatePatientId();
    final now = DateTime.now();
    final patient = PatientProfile(
      id: id,
      name: name,
      phone: phone,
      age: int.tryParse(_ageCtrl.text) ?? 0,
      address: _addressCtrl.text,
      registrationDate: DateFormat('yyyy-MM-dd').format(now),
      notes: _notesCtrl.text,
      photoUrl: 'https://i.pravatar.cc/150?u=$id',
      amountDue: double.tryParse(_dueCtrl.text) ?? 0,
      amountPaid: double.tryParse(_paidCtrl.text) ?? 0,
      appointmentDate: _selectedDate,
      treatmentPlan: List.from(_treatmentPlan),
    );

    final treatment = _treatmentPlan.isNotEmpty
        ? _treatmentPlan.first.procedureName
        : 'كشف';

    final appointment = Appointment(
      time:
          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
      patientName: name,
      treatment: treatment,
      status: 'مؤكد',
      patientId: id,
      date: _selectedDate,
    );

    NotificationService.onAppointmentAdded(appointment);

    ref.read(patientListProvider.notifier).add(patient);
    ref.read(appointmentListProvider.notifier).add(appointment);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('إضافة مريض جديد'),
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('معلومات المريض'),
                const SizedBox(height: 12),
                _buildField(
                  'الاسم',
                  _nameCtrl,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'الاسم مطلوب';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildField(
                  'رقم الهاتف',
                  _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'رقم الهاتف مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        'العمر',
                        _ageCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickDateTime,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.featureBg,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${DateFormat('yyyy/MM/dd', 'ar').format(_selectedDate)} ${_selectedTime.format(context)}',
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildField('العنوان', _addressCtrl),
                const SizedBox(height: 12),
                _buildField('ملاحظات', _notesCtrl, maxLines: 2),
                const SizedBox(height: 24),
                _sectionTitle('خطة العلاج'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _treatmentCtrl,
                        decoration: InputDecoration(
                          hintText: 'أضف إجراء...',
                          prefixIcon: const Icon(
                            Icons.add_task_outlined,
                            color: AppColors.textGray,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: AppColors.featureBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.divider,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.divider,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InkWell(
                        onTap: _addTreatmentItem,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_treatmentPlan.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(
                            Icons.add_task_outlined,
                            size: 16,
                            color: AppColors.textGray.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'لم يتم إضافة أي إجراء بعد',
                          style: TextStyle(
                            color: AppColors.textGray.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...List.generate(_treatmentPlan.length, (i) {
                    final item = _treatmentPlan[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: AppShadows.soft,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        leading: GestureDetector(
                          onTap: () => _toggleTreatment(i),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: item.statusColor,
                            ),
                            child: item.status == 'مكتمل'
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : const SizedBox(),
                          ),
                        ),
                        title: Text(
                          item.procedureName,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 14,
                          ),
                        ),
                        trailing: GestureDetector(
                          onTap: () => _deleteTreatment(i),
                          child: const Icon(
                            Icons.close,
                            color: AppColors.danger,
                            size: 20,
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                _sectionTitle('المالية'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        'المستحق',
                        _dueCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        'المدفوع',
                        _paidCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'حفظ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    String hint,
    TextEditingController ctrl, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.featureBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
