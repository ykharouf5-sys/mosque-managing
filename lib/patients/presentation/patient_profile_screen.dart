import 'dart:convert';
import 'dart:io';
import 'package:studentry/patients/data/photo_service.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/patients/data/notification_service.dart';
import 'package:studentry/patients/presentation/appointments_screen.dart';
import 'package:studentry/patients/presentation/providers/patient_providers.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/local_database.dart';
import 'package:studentry/shared/data/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  final PatientProfile patient;
  const PatientProfileScreen({super.key, required this.patient});

  @override
  ConsumerState<PatientProfileScreen> createState() =>
      _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _stepController = TextEditingController();

  void _notifyAndSync() {
    ref.read(patientListProvider.notifier).refresh();
    ref.read(appointmentListProvider.notifier).refresh();
  }

  final _picker = ImagePicker();
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.patient.appointmentDate != null) {
      _selectedDay = widget.patient.appointmentDate!;
      _focusedDay = widget.patient.appointmentDate!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('ملف المريض'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () => _showEditPatientDialog(context),
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_rounded,
              color: AppColors.primary,
            ),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            _buildPatientHeader(),
            TabBar(
              controller: _tabController,
              isScrollable: false,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textGrey,
              indicator: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 14),
              tabs: const [
                Tab(text: 'الملف'),
                Tab(text: 'الخطة'),
                Tab(text: 'الخطة العلاجية'),
                Tab(text: 'الصور'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFileTab(),
                  _buildPlanOverviewTab(),
                  _buildTreatmentPlanTab(),
                  _buildPhotosTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientHeader() {
    final p = widget.patient;
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppShadows.soft,
            ),
            child: CircleAvatar(
              radius: 50.r,
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              child: CircleAvatar(
                radius: 48.r,
                backgroundImage: NetworkImage(p.photoUrl),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                p.phone,
                style: TextStyle(fontSize: 14.sp, color: AppColors.textGrey),
              ),
              SizedBox(height: 2.h),
              Text(
                'العمر: ${p.age} سنة',
                style: TextStyle(fontSize: 14.sp, color: AppColors.textGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileTab() {
    final pad = MediaQuery.of(context).size.width > 600 ? 24.0 : 16.0;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: pad.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: pad),
          _buildGeneralInfo(),
          SizedBox(height: pad),
          _buildCalendarCard(),
          SizedBox(height: pad),
          _buildAccountCard(),
          SizedBox(height: pad),
          _buildAddButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGeneralInfo() {
    final p = widget.patient;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3.w,
                height: 16.h,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'معلومات عامة',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow('رقم الملف', p.id),
          _buildInfoRow('الهاتف', p.phone),
          _buildInfoRow('العنوان', p.address),
          _buildInfoRow('تاريخ التسجيل', p.registrationDate),
          _buildInfoRow('ملاحظات', p.notes),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 13.sp, color: AppColors.textGrey),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(fontSize: 13.sp, color: AppColors.textDark),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          child: const Divider(height: 1, color: AppColors.dividerLine),
        ),
      ],
    );
  }

  Widget _buildCalendarCard() {
    final screenHeight = MediaQuery.of(context).size.height;
    final calendarHeight = screenHeight > 800
        ? 190.0
        : (screenHeight > 600 ? 160.0 : 140.0);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'تحديد الموعد',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          SizedBox(
            height: calendarHeight,
            child: TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              locale: 'ar',
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  widget.patient.appointmentDate = selectedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                leftChevronIcon: const Icon(
                  Icons.chevron_right,
                  color: AppColors.primary,
                  size: 20,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_left,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                defaultTextStyle: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textDark,
                ),
                weekendTextStyle: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textDark,
                ),
                outsideTextStyle: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textGrey,
                ),
                cellMargin: const EdgeInsets.all(2),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontSize: 10,
                  color: AppColors.textGrey,
                ),
                weekendStyle: TextStyle(
                  fontSize: 10,
                  color: AppColors.textGrey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'الموعد المحدد: ${DateFormat('yyyy-MM-dd').format(_selectedDay)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    final p = widget.patient;
    final remaining = p.amountDue - p.amountPaid;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const Text(
                'الحساب',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              GestureDetector(
                onTap: () => _showEditAmountDialog(context),
                child: _buildAmountCard(
                  'المستحق',
                  widget.patient.amountDue,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              _buildAmountCard(
                'المدفوع',
                widget.patient.amountPaid,
                AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: remaining > 0
                  ? AppColors.pending.withValues(alpha: 0.1)
                  : AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Text(
                  'المتبقي:',
                  style: TextStyle(
                    fontSize: 14,
                    color: remaining > 0
                        ? AppColors.pending
                        : AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  NumberFormat('#,###').format(remaining),
                  style: TextStyle(
                    fontSize: 16,
                    color: remaining > 0
                        ? AppColors.pending
                        : AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showPaymentDialog(context),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'إضافة دفعة',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textLight,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: color)),
            const SizedBox(height: 4),
            Text(
              NumberFormat('#,###').format(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'إضافة دفعة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          content: TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'المبلغ',
              prefixIcon: Icon(
                Icons.monetization_on_outlined,
                color: AppColors.textGray,
                size: 20,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: AppColors.textGrey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount <= 0) return;
                final p = widget.patient;
                final maxPay = p.amountDue - p.amountPaid;
                if (maxPay <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('المستحق مدفوع بالكامل'),
                      backgroundColor: AppColors.pending,
                    ),
                  );
                  return;
                }
                if (amount > maxPay) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('المبلغ يتجاوز المتبقي ($maxPay ل.س)'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }
                setState(() {
                  p.amountPaid += amount;
                  p.todayPayment += amount;
                });
                final paymentId = const Uuid().v4();
                await AppDatabase.applyLocalPayment(p.id, amount);
                await LocalDatabaseService.addToQueue(
                  operation: 'insert',
                  tableName: 'patient_payments',
                  recordId: paymentId,
                  payload: jsonEncode({
                    'patientId': p.id,
                    'amount': amount,
                    'method': 'cash',
                    'paidAt': DateTime.now().toUtc().toIso8601String(),
                  }),
                );
                SyncService.syncNowWithJitter();
                _notifyAndSync();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPatientDialog(BuildContext context) {
    final p = widget.patient;
    final nameCtrl = TextEditingController(text: p.name);
    final phoneCtrl = TextEditingController(text: p.phone);
    final ageCtrl = TextEditingController(text: p.age.toString());
    final addressCtrl = TextEditingController(text: p.address);
    final notesCtrl = TextEditingController(text: p.notes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textGrey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'تعديل بيانات المريض',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameCtrl,
                  decoration: _inputDecoration('الاسم'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneCtrl,
                  decoration: _inputDecoration('الهاتف'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ageCtrl,
                  decoration: _inputDecoration('العمر'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: addressCtrl,
                  decoration: _inputDecoration('العنوان'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notesCtrl,
                  decoration: _inputDecoration('ملاحظات'),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        p.name = nameCtrl.text;
                        p.phone = phoneCtrl.text;
                        p.age = int.tryParse(ageCtrl.text) ?? p.age;
                        p.address = addressCtrl.text;
                        p.notes = notesCtrl.text;
                      });
                      _notifyAndSync();
                      Navigator.pop(ctx);
                    },
                    child: const Text('حفظ'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textGrey),
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
    );
  }

  void _showEditAmountDialog(BuildContext context) {
    final ctrl = TextEditingController(
      text: widget.patient.amountDue.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'تعديل المستحق',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'المبلغ المستحق',
              prefixIcon: Icon(
                Icons.monetization_on_outlined,
                color: AppColors.textGray,
                size: 20,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: AppColors.textGrey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(ctrl.text);
                if (amount == null || amount < 0) return;
                setState(() => widget.patient.amountDue = amount);
                _notifyAndSync();
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'الخطة العلاجية الحالية',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.patient.treatmentPlan.map(
          (t) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              title: Text(
                t.procedureName,
                style: const TextStyle(fontSize: 14, color: AppColors.textDark),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: t.statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    t.status,
                    style: TextStyle(
                      fontSize: 12,
                      color: t.statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTreatmentPlanTab() {
    final plan = widget.patient.treatmentPlan;
    return Column(
      children: [
        Expanded(
          child: plan.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.08),
                              AppColors.primary.withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.assignment_outlined,
                          size: 40,
                          color: AppColors.textGray.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'لا توجد خطوات بعد\nأضف الخطوة الأولى أدناه',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: plan.length,
                  itemBuilder: (context, index) {
                    final item = plan[index];
                    final isCompleted = item.status == 'مكتمل';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: AppShadows.card,
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? AppColors.success
                                    : AppColors.pending,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(AppRadius.lg),
                                  bottomRight: Radius.circular(AppRadius.lg),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: isCompleted
                                                ? AppColors.success.withValues(
                                                    alpha: 0.15,
                                                  )
                                                : AppColors.pending.withValues(
                                                    alpha: 0.15,
                                                  ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isCompleted
                                                    ? AppColors.success
                                                    : AppColors.pending,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            item.procedureName,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isCompleted
                                                  ? AppColors.textGrey
                                                  : AppColors.textDark,
                                              decoration: isCompleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: item.statusColor.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            item.status,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: item.statusColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 36,
                                            child: ElevatedButton.icon(
                                              onPressed: isCompleted
                                                  ? null
                                                  : () {
                                                      setState(() {
                                                        item.status = 'مكتمل';
                                                        item.statusColor =
                                                            AppColors.success;
                                                      });
                                                      _notifyAndSync();
                                                    },
                                              icon: const Icon(
                                                Icons.check,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'تم',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.success,
                                                foregroundColor:
                                                    AppColors.textLight,
                                                disabledBackgroundColor:
                                                    AppColors.success
                                                        .withValues(alpha: 0.3),
                                                disabledForegroundColor:
                                                    AppColors.textLight
                                                        .withValues(alpha: 0.5),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppRadius.sm,
                                                      ),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: SizedBox(
                                            height: 36,
                                            child: ElevatedButton.icon(
                                              onPressed: !isCompleted
                                                  ? null
                                                  : () {
                                                      setState(() {
                                                        item.status = 'معلق';
                                                        item.statusColor =
                                                            AppColors.pending;
                                                      });
                                                      _notifyAndSync();
                                                    },
                                              icon: const Icon(
                                                Icons.schedule,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'معلق',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.pending,
                                                foregroundColor:
                                                    AppColors.textLight,
                                                disabledBackgroundColor:
                                                    AppColors.pending
                                                        .withValues(alpha: 0.3),
                                                disabledForegroundColor:
                                                    AppColors.textLight
                                                        .withValues(alpha: 0.5),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppRadius.sm,
                                                      ),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          height: 36,
                                          child: IconButton(
                                            onPressed: () {
                                              setState(
                                                () => plan.removeAt(index),
                                              );
                                              _notifyAndSync();
                                            },
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: AppColors.danger,
                                              size: 20,
                                            ),
                                            style: IconButton.styleFrom(
                                              backgroundColor: AppColors.danger
                                                  .withValues(alpha: 0.08),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.sm,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: AppShadows.soft,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stepController,
                    decoration: InputDecoration(
                      hintText: 'اكتب خطوة جديدة...',
                      prefixIcon: const Icon(
                        Icons.add_task_outlined,
                        color: AppColors.textGray,
                        size: 20,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final text = _stepController.text.trim();
                      if (text.isEmpty) return;
                      setState(() {
                        plan.add(
                          TreatmentItem(
                            procedureName: text,
                            status: 'معلق',
                            statusColor: AppColors.pending,
                          ),
                        );
                        _stepController.clear();
                      });
                      _notifyAndSync();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text(
                      'إضافة',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosTab() {
    final photos = widget.patient.photos;
    return Stack(
      children: [
        if (photos.isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.08),
                        AppColors.primary.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.image_outlined,
                    size: 40,
                    color: AppColors.textGray.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'لا توجد صور بعد',
                  style: TextStyle(fontSize: 16, color: AppColors.textGrey),
                ),
                const SizedBox(height: 4),
                const Text(
                  'اضغط على زر + لإضافة صور',
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final path = photos[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    (path.startsWith('http://') || path.startsWith('https://'))
                        ? Image.network(
                            path,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _imagePlaceholder(),
                          )
                        : Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _imagePlaceholder(),
                          ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => photos.removeAt(index));
                          _notifyAndSync();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _pickImage,
            backgroundColor: AppColors.primary,
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.featureBg,
      child: const Icon(
        Icons.broken_image_outlined,
        color: AppColors.textGray,
        size: 32,
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        final patientId = widget.patient.id;
        final localPath = await PhotoService.saveLocally(patientId, image.path);
        setState(() => widget.patient.photos.add(localPath));
        _notifyAndSync();
      }
    } catch (_) {}
  }

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          final p = widget.patient;
          final now = DateTime.now();
          final timeStr =
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          final apt = Appointment(
            time: timeStr,
            patientName: p.name,
            treatment: p.treatmentPlan.isNotEmpty
                ? p.treatmentPlan.first.procedureName
                : 'كشف',
            status: 'مؤكد',
            patientId: p.id,
            date: _selectedDay,
          );
          ref.read(appointmentListProvider.notifier).add(apt);
          NotificationService.onAppointmentAdded(apt);
          ref.read(patientListProvider.notifier).refresh();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textLight,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: const Text(
          'إضافة موعد',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
