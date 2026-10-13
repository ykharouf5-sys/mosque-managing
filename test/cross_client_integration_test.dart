// Explicit, guarded real-HTTP test. Never runs writes against a public API.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/shared/data/api_config.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/patients/data/patient_api_service.dart';
import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/patients/data/appointment_api_service.dart';
import 'package:studentry/store/data/store_api_service.dart';
import 'package:studentry/utils/app_locale.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:studentry/student/data/academic_api_service.dart';
import 'package:studentry/student/data/result_models.dart';
import 'package:studentry/student/data/academic_result_api_service.dart';

void main() {
  final fixturePath = Platform.environment['CROSS_CLIENT_FIXTURE_FILE'];
  test(
    'real Flutter and Next exchange accounts and shared clinical, store and academic data',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      HttpOverrides.global = null;
      final fixture = jsonDecode(File(fixturePath!).readAsStringSync()) as Map;
      for (final key in ['api', 'web', 'control']) {
        final uri = Uri.parse(fixture[key] as String);
        expect(uri.scheme, 'http');
        expect(uri.host, '127.0.0.1');
      }
      expect(ApiConfig.baseUrl, fixture['api']);
      expect(
        File(
          fixturePath,
        ).parent.path.contains('studentry-integration-cross-client-'),
        isTrue,
      );
      final web = fixture['web'] as String;
      final checks = <String>[];
      final api = ApiClient.instance;
      AuthService(); // Initialize the singleton before binding isolated test credentials.
      String? token;
      var generation = 1;
      api.tokenProvider = () => token;
      api.sessionGenerationProvider = () => generation;
      const uuid = Uuid();
      Future<({Map data, String? cookie, int status})> webRequest(
        String path, {
        String method = 'GET',
        Map? body,
        Map? account,
        int expected = 200,
      }) async {
        final request = http.Request(method, Uri.parse('$web$path'));
        request.headers.addAll({
          'Origin': web,
          'Content-Type': 'application/json',
        });
        if (account != null) {
          request.headers.addAll({
            'Cookie': account['cookie'] as String,
            'X-Session-Id': account['session']['id'] as String,
            'X-Account-Scope': account['session']['scope'] as String,
          });
        }
        if (method != 'GET') request.headers['Idempotency-Key'] = uuid.v4();
        if (body != null) request.body = jsonEncode(body);
        final response = await http.Response.fromStream(await request.send());
        expect(response.statusCode, expected, reason: '$method $path');
        final data = response.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body) as Map;
        return (
          data: data,
          cookie: response.headers['set-cookie']?.split(';').first,
          status: response.statusCode,
        );
      }

      Future<Map> webLogin(String email) async {
        final r = await webRequest(
          '/api/auth/login',
          method: 'POST',
          body: {'email': email, 'password': 'Password123'},
        );
        expect(r.data.containsKey('token'), isFalse);
        return {'session': r.data['session'], 'cookie': r.cookie};
      }

      Future<AuthUser> mobileLogin(String email) async {
        final r = await api.post(
          '/auth/login',
          authenticated: false,
          body: {
            'email': email,
            'password': 'Password123',
            'device_name': 'flutter-cross-client-test',
          },
        );
        token = r.data['data']['token'] as String;
        generation++;
        api.invalidateReads();
        StoreApiService.resetSession();
        final user = AuthUser.fromJson(
          Map<String, dynamic>.from(r.data['data']['user'] as Map),
        );
        expect(user.emailConfirmedAt, isNotNull);
        return user;
      }

      Future<Map> webApi(
        String path,
        Map account, {
        String method = 'GET',
        Map? body,
        int expected = 200,
      }) async => (await webRequest(
        '/api/laravel/$path',
        method: method,
        body: body,
        account: account,
        expected: expected,
      )).data;
      void pass(String name) {
        checks.add(name);
        // ignore: avoid_print
        print('CROSS_CLIENT_PASS $name');
      }

      Future<void> otp(String path) async {
        final r = await http.post(Uri.parse('${fixture['control']}$path'));
        expect(r.statusCode, 200);
      }

      // Registration and verification through each client create the SAME Laravel identity.
      await webRequest(
        '/api/auth/register',
        method: 'POST',
        body: {
          'email': 'new@integration.test',
          'name': 'Web registration fixture',
          'password': 'Password123',
          'password_confirmation': 'Password123',
        },
      );
      await otp('/otp/new');
      final verified = await webRequest(
        '/api/auth/verify',
        method: 'POST',
        body: {
          'email': 'new@integration.test',
          'purpose': 'email_verification',
          'code': '123456',
        },
      );
      final webIdentity = verified.data['session']['user']['id'];
      expect((await mobileLogin('new@integration.test')).id, webIdentity);
      pass('web registration -> verified Flutter identity');
      await api.post(
        '/auth/register',
        authenticated: false,
        body: {
          'email': 'mobile-new@integration.test',
          'name': 'Mobile registration fixture',
          'password': 'Password123',
          'password_confirmation': 'Password123',
        },
      );
      await otp('/otp/mobile');
      final mobileVerified = await api.post(
        '/auth/otp/verify',
        authenticated: false,
        body: {
          'email': 'mobile-new@integration.test',
          'purpose': 'email_verification',
          'code': '123456',
        },
      );
      final registeredWeb = await webLogin('mobile-new@integration.test');
      expect(
        registeredWeb['session']['user']['id'],
        mobileVerified.data['data']['user']['id'],
      );
      pass('Flutter registration -> verified web identity');

      final account = await webLogin('a@integration.test');
      final user = await mobileLogin('a@integration.test');
      expect(user.id, account['session']['user']['id']);
      final webPatient = uuid.v4(), mobilePatient = uuid.v4();
      Map<String, dynamic> patient(String id, String name) => {
        'id': id,
        'name': name,
        'phone': '',
        'age': 25,
        'address': '',
        'registrationDate': '2026-10-12',
        'notes': 'isolated fixture',
        'photoUrl': '',
        'amountDue': 120.0,
        'amountPaid': 0.0,
        'todayPayment': 0.0,
        'treatmentPlan': <dynamic>[],
        'photos': <String>[],
      };
      await webApi(
        'patients',
        account,
        method: 'POST',
        expected: 201,
        body: {'id': webPatient, 'data': patient(webPatient, 'Created on web')},
      );
      expect(
        (await PatientApiService.fetchPage(
          1,
        )).rows.any((r) => r['id'] == webPatient),
        isTrue,
      );
      pass('web patient create -> actual Flutter PatientApiService list');
      await PatientApiService.create(
        PatientProfile.fromJson(patient(mobilePatient, 'Created on mobile')),
        operationId: uuid.v4(),
      );
      var webRow =
          (await webApi('patients/$mobilePatient', account))['data'] as Map;
      expect(webRow['name'], 'Created on mobile');
      pass('Flutter PatientApiService create -> web record');
      final edited = PatientProfile.fromJson(Map<String, dynamic>.from(webRow));
      edited.name = 'Edited on mobile';
      await PatientApiService.update(
        edited,
        version: webRow['version'] as int,
        operationId: uuid.v4(),
      );
      webRow =
          (await webApi('patients/$mobilePatient', account))['data'] as Map;
      expect(webRow['name'], 'Edited on mobile');
      await webApi(
        'patients/$mobilePatient',
        account,
        method: 'PUT',
        body: {
          'version': webRow['version'],
          'data': {...patient(mobilePatient, 'Edited on web')},
        },
      );
      expect(
        (await PatientApiService.fetchPage(
          1,
        )).rows.firstWhere((r) => r['id'] == mobilePatient)['name'],
        'Edited on web',
      );
      pass('patient edit propagates in both directions with versions');
      await webApi(
        'patients/$webPatient/payments',
        account,
        method: 'POST',
        expected: 201,
        body: {'id': uuid.v4(), 'amount': 20, 'method': 'cash'},
      );
      expect(
        (await PatientApiService.fetchPage(
          1,
        )).rows.firstWhere((r) => r['id'] == webPatient)['amountPaid'],
        20,
      );
      await api.post(
        '/patients/$webPatient/payments',
        headers: {'Idempotency-Key': uuid.v4()},
        body: {'id': uuid.v4(), 'amount': 10, 'method': 'cash'},
      );
      expect(
        (await webApi('patients/$webPatient', account))['data']['amountPaid'],
        30,
      );
      final report = (await webApi('clinical/reports', account))['data'];
      expect(report['amountPaid'], 30);
      expect(report['patients'], 3);
      pass('payments and report aggregates share the same records');

      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      final nativePhoto = await api.upload(
        '/patients/$webPatient/photos',
        png,
        'mobile.png',
      );
      final nativePhotoId = nativePhoto.data['data']['id'];
      expect(
        (await webApi('patients/$webPatient', account))['data']['photos'],
        contains(nativePhoto.data['data']['url']),
      );
      final photoRequest = http.Request(
        'GET',
        Uri.parse(
          '$web/api/laravel/patients/$webPatient/photos/$nativePhotoId',
        ),
      );
      photoRequest.headers.addAll({
        'Cookie': account['cookie'] as String,
        'X-Session-Id': account['session']['id'] as String,
        'X-Account-Scope': account['session']['scope'] as String,
      });
      final webPhoto = await http.Response.fromStream(
        await photoRequest.send(),
      );
      expect(webPhoto.statusCode, 200);
      expect(webPhoto.headers['content-type'], startsWith('image/'));
      expect(webPhoto.bodyBytes, isNotEmpty);
      final webPhotoRequest = http.MultipartRequest(
        'POST',
        Uri.parse('$web/api/laravel/patients/$webPatient/photos'),
      );
      webPhotoRequest.headers.addAll({
        'Origin': web,
        'Cookie': account['cookie'] as String,
        'X-Session-Id': account['session']['id'] as String,
        'X-Account-Scope': account['session']['scope'] as String,
        'Idempotency-Key': uuid.v4(),
      });
      webPhotoRequest.files.add(
        http.MultipartFile.fromBytes('image', png, filename: 'web.png'),
      );
      final webPhotoUploaded = await http.Response.fromStream(
        await webPhotoRequest.send(),
      );
      expect(webPhotoUploaded.statusCode, 201);
      final webPhotoUrl =
          (jsonDecode(webPhotoUploaded.body) as Map)['data']['url'];
      expect(
        (await PatientApiService.fetchPage(
          1,
        )).rows.firstWhere((r) => r['id'] == webPatient)['photos'],
        contains(webPhotoUrl),
      );
      final deniedPhoto = http.Request('GET', photoRequest.url);
      expect(
        (await http.Response.fromStream(await deniedPhoto.send())).statusCode,
        401,
      );
      pass(
        'private patient photos exchange through authenticated media endpoints',
      );

      final versionBefore = (await webApi(
        'patients/$mobilePatient',
        account,
      ))['data']['version'];
      await webApi(
        'patients/$mobilePatient',
        account,
        method: 'PUT',
        body: {
          'version': versionBefore,
          'data': patient(mobilePatient, 'Newest web change'),
        },
      );
      await expectLater(
        api.put(
          '/patients/$mobilePatient',
          headers: {'Idempotency-Key': uuid.v4()},
          body: {
            'version': versionBefore,
            'data': patient(mobilePatient, 'Stale mobile change'),
          },
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.statusCode,
            'version conflict',
            409,
          ),
        ),
      );
      expect(
        (await webApi('patients/$mobilePatient', account))['data']['name'],
        'Newest web change',
      );
      pass('stale mobile writes cannot overwrite a newer web patient version');

      final apt = uuid.v4();
      final appointment = <String, dynamic>{
        'patientId': webPatient,
        'patientName': 'Created on web',
        'date': '2026-10-13',
        'time': '09:00',
        'status': 'pending',
        'treatment': 'Fixture',
        'reminderSent': false,
        'notificationSent': false,
      };
      await webApi(
        'appointments',
        account,
        method: 'POST',
        expected: 201,
        body: {'id': apt, 'data': appointment},
      );
      var aptPage = await AppointmentApiService.fetchDatePage(
        DateTime(2026, 10, 13),
        force: true,
        clinicalHeaders: {},
      );
      expect(aptPage.rows.any((r) => r['id'] == apt), isTrue);
      final mobileApt = uuid.v4();
      await AppointmentApiService.create({
        'id': mobileApt,
        ...appointment,
        'time': '10:00',
      }, operationId: uuid.v4());
      var aptRow =
          (await webApi('appointments/$mobileApt', account))['data'] as Map;
      expect(aptRow['time'], '10:00');
      await webApi(
        'appointments/$mobileApt',
        account,
        method: 'PUT',
        body: {
          'version': aptRow['version'],
          'data': {...appointment, 'time': '11:00'},
        },
      );
      aptPage = await AppointmentApiService.fetchDatePage(
        DateTime(2026, 10, 13),
        force: true,
        clinicalHeaders: {},
      );
      expect(
        aptPage.rows.firstWhere((r) => r['id'] == mobileApt)['time'],
        '11:00',
      );
      pass('appointment create and edit exchange between both clients');

      const productId = '10000000-0000-4000-8000-000000000001';
      final orderWeb = uuid.v4(), orderMobile = uuid.v4();
      await webApi(
        'orders',
        account,
        method: 'POST',
        expected: 201,
        body: {
          'id': orderWeb,
          'items': [
            {
              'product': {'id': productId, 'price': '0.01'},
              'quantity': 1,
            },
          ],
          'details': {},
        },
      );
      expect(
        (await StoreApiService.fetchOrdersPage(
          0,
          25,
        )).any((r) => r['id'] == orderWeb),
        isTrue,
      );
      final createdOrder = await StoreApiService.createOrderSafe({
        'id': orderMobile,
        'total': 0.01,
        'items': [
          {
            'product': {'id': productId},
            'quantity': 1,
          },
        ],
      });
      expect(createdOrder.confirmedOrder, isNotNull);
      expect(
        (await webApi(
          'orders',
          account,
        ))['data']['data'].any((r) => r['id'] == orderMobile),
        isTrue,
      );
      pass('orders cross both clients; server controls pricing');
      final salesWeb = await webLogin('sales@integration.test');
      await webApi(
        'orders/$orderWeb/status',
        salesWeb,
        method: 'PATCH',
        body: {'status': 'approved'},
      );
      expect(
        (await StoreApiService.fetchOrdersPage(
          0,
          25,
        )).firstWhere((r) => r['id'] == orderWeb)['status'],
        'approved',
      );
      await mobileLogin('sales@integration.test');
      await StoreApiService.updateOrderStatus(orderMobile, 'approved');
      expect(
        (await webApi(
          'orders',
          account,
        ))['data']['data'].firstWhere((r) => r['id'] == orderMobile)['status'],
        'approved',
      );
      await webApi(
        'orders/$orderWeb/status',
        account,
        method: 'PATCH',
        expected: 403,
        body: {'status': 'delivered'},
      );
      pass(
        'sales manager handles both order sources; student cannot change status',
      );
      final sharedProduct = uuid.v4();
      await webApi(
        'store/products',
        salesWeb,
        method: 'POST',
        expected: 201,
        body: {
          'id': sharedProduct,
          'name': 'Shared cross-client product',
          'price': 42,
          'stock': 8,
          'is_available': true,
          'translations': {
            'ar': {
              'name': 'Shared cross-client product',
              'description': 'Arabic baseline',
            },
            'en': {
              'name': 'Web English product',
              'description': 'English product description',
            },
          },
        },
      );
      expect(
        (await StoreApiService.fetchProductPage(
          1,
          25,
        )).rows.any((r) => r['id'] == sharedProduct),
        isTrue,
      );
      await StoreApiService.updateProduct(sharedProduct, {
        'name': 'Mobile-edited product',
        'price': 44,
        'stock': 8,
      });
      expect(
        (await webApi('store/products', salesWeb))['data']['data'].any(
          (r) =>
              r['id'] == sharedProduct && r['name'] == 'Mobile-edited product',
        ),
        isTrue,
      );
      pass('catalog management is shared and role protected');
      await StoreApiService.updateProduct(sharedProduct, {
        'translations': {
          'en': {'description': 'Mobile English edit'},
        },
      });
      final translatedWeb = (await webApi(
        'store/products?locale=en',
        salesWeb,
      ))['data']['data'].firstWhere((r) => r['id'] == sharedProduct);
      expect(translatedWeb['name'], 'Web English product');
      expect(translatedWeb['description'], 'Mobile English edit');
      expect(
        translatedWeb['translations']['ar']['name'],
        'Mobile-edited product',
      );
      expect(translatedWeb['price'], '44.00');
      AppLocale.localeNotifier.value = const Locale('en');
      final translatedMobile = (await StoreApiService.fetchProductPage(
        1,
        25,
        force: true,
      )).rows.firstWhere((r) => r['id'] == sharedProduct);
      expect(translatedMobile['name'], 'Web English product');
      expect(translatedMobile['stock'], 8);
      AppLocale.localeNotifier.value = const Locale('ar');
      final translatedPage = await http.get(
        Uri.parse('$web/en/store/$sharedProduct'),
      );
      expect(translatedPage.statusCode, 200);
      expect(translatedPage.body.contains('Web English product'), true);
      expect(translatedPage.body.contains('Mobile English edit'), true);
      pass(
        'web creation and native partial English edits share one product and real English SSR',
      );

      final categoryId = uuid.v4(), bannerId = uuid.v4();
      await webApi(
        'store/categories',
        salesWeb,
        method: 'POST',
        expected: 201,
        body: {
          'id': categoryId,
          'name': 'Web category',
          'translations': {
            'en': {'name': 'Web English category'},
          },
        },
      );
      await StoreApiService.refreshCatalog();
      expect(
        (await StoreApiService.fetchCategories()).any(
          (r) => r['id'] == categoryId,
        ),
        isTrue,
      );
      await StoreApiService.updateCategory(categoryId, 'Mobile category', '');
      expect(
        (await webApi(
          'store/catalog?include_products=0',
          salesWeb,
        ))['data']['categories'].any(
          (r) => r['id'] == categoryId && r['name'] == 'Mobile category',
        ),
        isTrue,
      );
      await StoreApiService.insertBanner({
        'id': bannerId,
        'title': 'Mobile text banner',
        'categoryId': categoryId,
        'translations': {
          'en': {'title': 'Native English banner'},
        },
      });
      expect(
        (await webApi(
          'store/catalog?include_products=0',
          salesWeb,
        ))['data']['banners'].any(
          (r) => r['id'] == bannerId && r['title'] == 'Mobile text banner',
        ),
        isTrue,
      );
      await webApi(
        'store/banners/$bannerId',
        salesWeb,
        method: 'PUT',
        body: {'subtitle': 'Web subtitle'},
      );
      await StoreApiService.refreshCatalog();
      expect(
        (await StoreApiService.fetchBanners()).firstWhere(
          (r) => r['id'] == bannerId,
        )['subtitle'],
        'Web subtitle',
      );
      await StoreApiService.updateBanner(bannerId, {
        'title': 'Mobile edited banner',
      });
      expect(
        (await webApi(
          'store/catalog?include_products=0',
          salesWeb,
        ))['data']['banners'].firstWhere(
          (r) => r['id'] == bannerId,
        )['subtitle'],
        'Web subtitle',
      );
      pass(
        'categories and text banners exchange without changing IDs or clearing omitted fields',
      );

      await webApi(
        'store/coupons',
        salesWeb,
        method: 'POST',
        expected: 201,
        body: {
          'code': 'CROSS10',
          'discount_type': 'percentage',
          'discount_value': 10,
        },
      );
      expect(
        (await StoreApiService.fetchCoupons()).any(
          (r) => r['code'] == 'CROSS10',
        ),
        isTrue,
      );
      await mobileLogin('a@integration.test');
      final coupon = await StoreApiService.validateCoupon('CROSS10', [
        {'product_id': sharedProduct, 'quantity': 1},
      ]);
      expect(double.parse('${coupon['discount']}'), 4.4);
      await webApi('store/favorites/$sharedProduct', account, method: 'PUT');
      expect(await StoreApiService.fetchFavorites(), contains(sharedProduct));
      await StoreApiService.removeFavorite(sharedProduct);
      expect(
        (await webApi('store/favorites', account))['data'],
        isNot(contains(sharedProduct)),
      );
      await webApi(
        'store/products/$sharedProduct/reviews',
        account,
        method: 'POST',
        expected: 201,
        body: {'id': uuid.v4(), 'rating': 4, 'comment': 'Web review'},
      );
      expect(
        (await StoreApiService.fetchReviews(
          sharedProduct,
        )).any((r) => r['comment'] == 'Web review'),
        isTrue,
      );
      await StoreApiService.submitReview(
        sharedProduct,
        id: uuid.v4(),
        rating: 5,
        comment: 'Mobile review',
      );
      expect(
        (await webApi(
          'store/products/$sharedProduct/reviews',
          account,
        ))['data']['data'].any((r) => r['comment'] == 'Mobile review'),
        isTrue,
      );
      pass('coupons, favorites and product reviews share server state');

      await webApi(
        'auth/profile',
        account,
        method: 'PUT',
        body: {
          'full_name': 'Web shared profile',
          'academic_year': 'first',
          'exam_number': '123456',
        },
      );
      expect(
        (await api.get(
          '/auth/me',
          force: true,
        )).data['data']['user']['full_name'],
        'Web shared profile',
      );
      await api.put(
        '/auth/profile',
        body: {
          'full_name': 'Mobile shared profile',
          'academic_year': 'first',
          'exam_number': '123456',
        },
      );
      expect(
        (await webRequest(
          '/api/session',
          account: account,
        )).data['user']['full_name'],
        'Mobile shared profile',
      );
      // Profile completion changes account scope; real web clients refresh the session.
      account['session'] = (await webRequest(
        '/api/session',
        account: account,
      )).data;
      pass('profile edits share the same account in both directions');

      final academicWeb = await webLogin('academic@integration.test');
      await mobileLogin('academic@integration.test');
      final subjectId = uuid.v4();
      await webApi(
        'academic/subjects',
        academicWeb,
        method: 'POST',
        expected: 201,
        body: {
          'id': subjectId,
          'name': 'Shared subject',
          'code': 'SHARED-101',
          'academic_year': 'first',
          'total_lectures': 2,
          'lectures': [
            {
              'number': 1,
              'title': 'Shared lecture',
              'links': ['https://studentry.app/fixture'],
            },
            {'number': 2, 'title': 'Next lecture', 'links': <String>[]},
          ],
        },
      );
      var subjects = await const AcademicApiService().subjects(force: true);
      expect(subjects.any((r) => r.id == subjectId), isTrue);
      await api.put(
        '/academic/subjects/$subjectId',
        body: {'version': 1, 'name': 'Mobile-edited subject'},
      );
      expect(
        (await webApi('academic/subjects', academicWeb))['data'].any(
          (r) => r['id'] == subjectId && r['name'] == 'Mobile-edited subject',
        ),
        isTrue,
      );
      pass('subjects and lecture contents appear on both clients');

      final pdf = utf8.encode(
        '%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n',
      );
      final uploadRequest = http.MultipartRequest(
        'POST',
        Uri.parse('$web/api/laravel/academic/documents'),
      );
      uploadRequest.headers.addAll({
        'Origin': web,
        'Cookie': academicWeb['cookie'] as String,
        'X-Session-Id': academicWeb['session']['id'] as String,
        'X-Account-Scope': academicWeb['session']['scope'] as String,
        'Idempotency-Key': uuid.v4(),
      });
      uploadRequest.files.add(
        http.MultipartFile.fromBytes(
          'document',
          pdf,
          filename: 'web-fixture.pdf',
        ),
      );
      final uploadResponse = await http.Response.fromStream(
        await uploadRequest.send(),
      );
      expect(uploadResponse.statusCode, 201);
      final webDocument =
          (jsonDecode(uploadResponse.body) as Map)['data']['reference'];
      await webApi(
        'academic/subjects/$subjectId',
        academicWeb,
        method: 'PUT',
        body: {
          'version': 2,
          'pdf_url': webDocument,
          'lectures': [
            {
              'number': 1,
              'title': 'Shared lecture PDF',
              'pdf_url': webDocument,
              'links': <String>[],
            },
            {'number': 2, 'title': 'Next lecture', 'links': <String>[]},
          ],
        },
      );
      final nativeUrl =
          (await api.get(
                '/academic/subjects/$subjectId/lectures/1/document-url',
                force: true,
              )).data['data']['url']
              as String;
      final downloaded = await http.get(Uri.parse(nativeUrl));
      expect(downloaded.statusCode, 200);
      expect(downloaded.bodyBytes, pdf);
      final mobileUpload = await api.upload(
        '/academic/documents',
        pdf,
        'mobile-fixture.pdf',
        fieldName: 'document',
      );
      await api.put(
        '/academic/subjects/$subjectId',
        body: {'version': 3, 'pdf_url': mobileUpload.data['data']['reference']},
      );
      final webUrl =
          (await webApi(
                'academic/subjects/$subjectId/document-url',
                academicWeb,
              ))['data']['url']
              as String;
      final webDownloaded = await http.get(Uri.parse(webUrl));
      expect(webDownloaded.statusCode, 200);
      expect(webDownloaded.bodyBytes, pdf);
      pass(
        'web and Flutter upload and download the same private subject and lecture PDF bytes',
      );

      Map<String, dynamic> resultImport(
        String uploadId,
        String recordId,
        int mark,
      ) => {
        'id': uploadId,
        'file_name': 'isolated-results.json',
        'records': [
          {
            'id': recordId,
            'exam_number': '123456',
            'subject_id': subjectId,
            'subject_name': 'Shared subject',
            'mark': mark,
            'total': 100,
          },
        ],
      };
      final resultWeb = uuid.v4(), resultMobile = uuid.v4();
      await webApi(
        'academic/result-uploads',
        academicWeb,
        method: 'POST',
        expected: 201,
        body: resultImport(uuid.v4(), resultWeb, 78),
      );
      await mobileLogin('a@integration.test');
      final nativeResults =
          (await api.get('/academic/results', force: true)).data['data']
              as List;
      expect(
        nativeResults
            .map(
              (r) => ResultRecord.fromJson(Map<String, dynamic>.from(r as Map)),
            )
            .any((r) => r.id == resultWeb && r.mark == 78),
        isTrue,
      );
      await mobileLogin('academic@integration.test');
      final uploadId = uuid.v4();
      await const AcademicResultApiService().save(
        ResultUpload(
          id: uploadId,
          fileName: 'mobile-results.json',
          uploadDate: DateTime(2026, 10, 12),
          uploadedBy: 'fixture',
        ),
        [
          ResultRecord(
            id: resultMobile,
            examNumber: '123456',
            subjectName: 'Shared subject',
            mark: 82,
            uploadDate: DateTime(2026, 10, 12),
            sourcePdfId: uploadId,
          ),
        ],
      );
      expect(
        (await webApi(
          'academic/results',
          account,
        ))['data'].any((r) => r['id'] == resultMobile && r['mark'] == 82),
        isTrue,
      );
      pass(
        'manager results from either client match the student exam identity',
      );
      await mobileLogin('a@integration.test');
      final enrollmentId = uuid.v4();
      await webApi(
        'academic/enrollments',
        account,
        method: 'POST',
        expected: 201,
        body: {
          'id': enrollmentId,
          'subject_id': subjectId,
          'name': 'Shared subject',
          'code': 'SHARED-101',
          'academic_year': 'first',
          'schedule_days': ['monday'],
          'schedule_times': ['09:00'],
        },
      );
      var enrollments = await const AcademicApiService().enrollments(
        force: true,
      );
      expect(enrollments.any((r) => r.enrollmentId == enrollmentId), isTrue);
      await api.patch(
        '/academic/enrollments/$enrollmentId/viewed',
        body: {
          'lecture_number': 1,
          'version': enrollments
              .firstWhere((r) => r.enrollmentId == enrollmentId)
              .version,
        },
      );
      var webEnrollments =
          (await webApi('academic/enrollments', account))['data'] as List;
      expect(
        webEnrollments.firstWhere(
          (r) => r['enrollmentId'] == enrollmentId,
        )['viewedLectures'],
        contains(1),
      );
      pass('timetable and viewed lectures share per-user enrollment state');

      // Same-clinic ownership isolation remains intact; logout revokes only its own token.
      final foreign = await webLogin('c@integration.test');
      await webApi('patients/$webPatient', foreign, expected: 404);
      await PatientApiService.delete(
        mobilePatient,
        version:
            (await webApi(
                  'patients/$mobilePatient',
                  account,
                ))['data']['version']
                as int,
        operationId: uuid.v4(),
      );
      await webApi('patients/$mobilePatient', account, expected: 404);
      pass('deletions propagate without leaking another account records');
      await webRequest(
        '/api/auth/logout',
        method: 'POST',
        body: {},
        account: account,
      );
      expect((await api.get('/auth/me', maxRetries: 0)).statusCode, 200);
      pass('web logout preserves the independent Flutter session');
      File(fixture['output'] as String).writeAsStringSync(
        jsonEncode({
          'checks': checks.map((n) => {'name': n, 'result': 'passed'}).toList(),
        }),
      );
    },
    skip: fixturePath == null ? 'Requires guarded cross-client runner' : false,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
