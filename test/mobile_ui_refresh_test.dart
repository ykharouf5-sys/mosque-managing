import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/auth/presentation/login_screen.dart';
import 'package:studentry/auth/presentation/onboarding_screen.dart';
import 'package:studentry/auth/presentation/register_screen.dart';
import 'package:studentry/auth/presentation/otp_verification_screen.dart';
import 'package:studentry/auth/presentation/password_reset_screen.dart';
import 'package:studentry/shared/widgets/studentry_illustration.dart';
import 'package:studentry/student/presentation/widgets/lecture_time_field.dart';
import 'package:studentry/student/presentation/widgets/student_welcome_card.dart';
import 'package:studentry/utils/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/patients/presentation/providers/patient_providers.dart';
import 'package:studentry/student/presentation/student_home_screen.dart';

class _ReviewPatients extends PatientListNotifier {
  @override
  List<PatientProfile> build() => [
    PatientProfile.fromJson({
      'id': 'review-only-patient',
      'name': 'مريض تجريبي',
    }),
  ];
}

class _ReviewAppointments extends AppointmentListNotifier {
  @override
  List<Appointment> build() => [
    Appointment(
      id: 'review-only-appointment',
      time: '10:00',
      patientName: 'مريض تجريبي',
      patientId: 'review-only-patient',
      date: DateTime.now(),
      treatment: 'جلسة متابعة',
      status: 'pending',
    ),
  ];
}

Widget harness(Widget child, {double scale = 1, bool reducedMotion = true}) =>
    ProviderScope(
      overrides: [
        patientListProvider.overrideWith(_ReviewPatients.new),
        appointmentListProvider.overrideWith(_ReviewAppointments.new),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(fontFamily: 'ReviewArabic').copyWith(
            textTheme: AppTheme.light(
              fontFamily: 'ReviewArabic',
            ).textTheme.apply(fontFamilyFallback: const ['ReviewLatin']),
          ),
          locale: const Locale('ar'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('ar'), Locale('en')],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reducedMotion,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: child,
        ),
      ),
    );

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await render.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/mobile-ui-review-20261029')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    final font = FontLoader('ReviewArabic');
    for (final weight in ['Regular', 'Bold']) {
      font.addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/NotoNaskhArabic-$weight.ttf').readAsBytesSync(),
          ),
        ),
      );
    }
    final latin = FontLoader('ReviewLatin');
    latin.addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/Courgette-Regular.ttf').readAsBytesSync(),
        ),
      ),
    );
    await font.load();
    await latin.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(
      Future.value(await rootBundle.load('fonts/MaterialIcons-Regular.otf')),
    );
    await icons.load();
  });

  final screens = <String, Widget Function()>{
    'login': () => const LoginScreen(),
    'register': () => const RegisterScreen(),
    'onboarding': () => const OnboardingScreen(),
    'verification': () => const OtpVerificationScreen(
      email: 'student@example.test',
      selectedRole: 'student',
    ),
    'password-reset': () =>
        const PasswordResetScreen(email: 'student@example.test'),
    'home-welcome': () => const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: StudentWelcomeCard(
          name: 'أحمد محمد',
          date: 'الخميس ٢٩ أكتوبر ٢٠٢٦',
        ),
      ),
    ),
    'home': () => const StudentHomeScreen(embedded: true, active: false),
  };
  for (final width in [320.0, 390.0, 720.0]) {
    for (final scale in [1.0, 1.5]) {
      for (final entry in screens.entries) {
        testWidgets('${entry.key} fits $width at text scale $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: harness(entry.value(), scale: scale),
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          if (width == 390 && scale == 1) {
            await capture(tester, boundary, entry.key);
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }

  testWidgets('login fits above the keyboard without page scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness(const LoginScreen()));
    await tester.pump(const Duration(seconds: 1));
    final password = find.byType(TextFormField).last;
    await tester.tap(password);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(password, 'password123');
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.getBottomRight(password).dy, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'registration preserves required fields across both non scrolling steps',
    (tester) async {
      await tester.pumpWidget(harness(const RegisterScreen()));
      await tester.pump(const Duration(seconds: 1));
      var form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse);
      await tester.pump();
      expect(find.text('هذا الحقل مطلوب'), findsNWidgets(2));
      var fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'أحمد محمد');
      await tester.enterText(fields.at(1), '+963933123456');
      await tester.tap(find.text('متابعة'));
      await tester.pump();
      form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse);
      await tester.pump();
      expect(find.text('هذا الحقل مطلوب'), findsNWidgets(3));
      fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'student@example.test');
      await tester.enterText(fields.at(1), 'password123');
      await tester.enterText(fields.at(2), 'different');
      expect(form.validate(), isFalse);
      await tester.enterText(fields.at(2), 'password123');
      expect(form.validate(), isTrue);
      expect(find.byType(SingleChildScrollView), findsNothing);
      await tester.tap(find.text('العودة للبيانات الأساسية'));
      await tester.pump();
      fields = find.byType(TextFormField);
      expect(
        tester.widget<TextFormField>(fields.first).controller!.text,
        'أحمد محمد',
      );
      expect(
        tester.widget<TextFormField>(fields.last).controller!.text,
        '+963933123456',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'both registration steps fit a small keyboard viewport without scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(harness(const RegisterScreen()));
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byType(TextFormField).at(0), 'أحمد محمد');
      await tester.enterText(find.byType(TextFormField).at(1), '+963933123456');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(
        tester.getBottomRight(find.text('متابعة')).dy,
        lessThanOrEqualTo(360),
      );
      await tester.tap(find.text('متابعة'));
      await tester.pump();
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(
        tester.getBottomRight(find.text('إنشاء حساب').last).dy,
        lessThanOrEqualTo(360),
      );
      for (final field in find.byType(TextFormField).evaluate()) {
        expect(
          tester.getSize(find.byWidget(field.widget)).height,
          greaterThanOrEqualTo(40),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('lecture time is optional, read only, and can be cleared', (
    tester,
  ) async {
    final controller = TextEditingController(text: '09:00 - 11:00');
    addTearDown(controller.dispose);
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      harness(
        Scaffold(
          body: Form(
            key: key,
            child: LectureTimeField(controller: controller),
          ),
        ),
      ),
    );
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    await tester.tap(find.byTooltip('مسح الوقت'));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(key.currentState!.validate(), isTrue);
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('illustration respects reduced motion', (tester) async {
    await tester.pumpWidget(
      harness(const Scaffold(body: StudentryIllustration())),
    );
    final transform = find.descendant(
      of: find.byType(StudentryIllustration),
      matching: find.byType(Transform),
    );
    final before = tester.widget<Transform>(transform.first).transform.clone();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<Transform>(transform.first).transform, before);
    await tester.pumpWidget(const SizedBox());
  });
}
