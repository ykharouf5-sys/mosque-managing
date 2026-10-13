import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/api_request_queue.dart';

void main() {
  test(
    'expired cache uses ETag and a 304 reuses payload, then force bypasses validation',
    () async {
      var now = DateTime(2026);
      var calls = 0;
      final api = ApiClient.forTesting(
        MockClient((request) async {
          calls++;
          if (request.headers['If-None-Match'] == '"v1"') {
            return http.Response('', 304);
          }
          return http.Response('{"data":[1]}', 200, headers: {'etag': '"v1"'});
        }),
        now: () => now,
      );
      const age = Duration(minutes: 5);
      await api.get('/store/products', freshness: age);
      now = now.add(const Duration(minutes: 6));
      final validated = await api.get('/store/products', freshness: age);
      expect(validated.data['data'], [1]);
      expect(validated.statusCode, 200);
      await api.get('/store/products', freshness: age);
      expect(calls, 2);
      await api.get('/store/products', freshness: age, force: true);
      expect(calls, 3);
    },
  );

  test('freshness honors a shorter requested lifetime', () async {
    var now = DateTime(2026);
    var calls = 0;
    final api = ApiClient.forTesting(
      MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
      now: () => now,
    );
    await api.get('/store/products', freshness: const Duration(hours: 1));
    now = now.add(const Duration(minutes: 10));
    await api.get('/store/products', freshness: const Duration(minutes: 5));
    expect(calls, 2);
  });

  test(
    'identical concurrent GETs share one transport request, sorted filters',
    () async {
      var calls = 0;
      final gate = Completer<void>();
      final api = ApiClient.forTesting(
        MockClient((request) async {
          calls++;
          await gate.future;
          return http.Response('{"data":[]}', 200);
        }),
      );
      final a = api.get('/store/products', query: {'page': '1', 'search': 'x'});
      final b = api.get('/store/products', query: {'search': 'x', 'page': '1'});
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      gate.complete();
      expect(identical(await a, await b), isTrue);
    },
  );

  test(
    'freshness is opt-in, separated by filters, headers and account',
    () async {
      var calls = 0;
      var generation = 1;
      var token = 'account-a';
      final api =
          ApiClient.forTesting(
              MockClient(
                (_) async => http.Response(jsonEncode({'call': ++calls}), 200),
              ),
            )
            ..sessionGenerationProvider = (() => generation)
            ..tokenProvider = (() => token);
      const age = Duration(minutes: 5);
      await api.get('/store/products', freshness: age);
      await api.get('/store/products', freshness: age);
      expect(calls, 1);
      await api.get('/store/products', query: {'page': '2'}, freshness: age);
      await api.get(
        '/store/products',
        headers: {'If-None-Match': 'v2'},
        freshness: age,
      );
      generation++;
      token = 'account-b';
      await api.get('/store/products', freshness: age);
      expect(calls, 4);
      await api.get('/orders');
      await api.get('/orders');
      expect(calls, 6);
      await api.get('/store/products', freshness: age, force: true);
      expect(calls, 7);
    },
  );

  test(
    'mutations invalidate read cache and old in-flight reads cannot refill it',
    () async {
      var reads = 0;
      final gate = Completer<void>();
      final api = ApiClient.forTesting(
        MockClient((request) async {
          if (request.method == 'GET') {
            reads++;
            if (reads == 1) await gate.future;
          }
          return http.Response('{}', 200);
        }),
      );
      const age = Duration(minutes: 5);
      final old = api.get('/store/products', freshness: age);
      await Future<void>.delayed(Duration.zero);
      await api.post('/store/products', body: {});
      gate.complete();
      await old;
      await api.get('/store/products', freshness: age);
      expect(reads, 2);
      await api.get('/store/products', freshness: age);
      expect(reads, 2);
      await api.delete('/store/products/id');
      await api.get('/store/products', freshness: age);
      expect(reads, 3);
    },
  );

  test('session switch rejects old queued/transport reads', () async {
    var generation = 1;
    final gate = Completer<void>();
    final api = ApiClient.forTesting(
      MockClient((_) async {
        await gate.future;
        return http.Response('{}', 200);
      }),
    )..sessionGenerationProvider = () => generation;
    final old = api.get('/orders');
    final assertion = expectLater(old, throwsA(isA<StaleSessionException>()));
    generation++;
    gate.complete();
    await assertion;
  });

  test('multipart upload is never automatically retried on 5xx', () async {
    var calls = 0;
    final api = ApiClient.forTesting(
      MockClient((_) async {
        calls++;
        return http.Response('{"message":"failed after write"}', 500);
      }),
    );
    await expectLater(
      api.upload('/uploads', [1, 2, 3], 'synthetic.jpg'),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
  });

  test(
    'a late clinical push acknowledgement is rejected after session switch',
    () async {
      var generation = 1;
      var token = 'synthetic-A';
      final entered = Completer<void>();
      final gate = Completer<void>();
      final api =
          ApiClient.forTesting(
              MockClient((request) async {
                expect(request.headers['Authorization'], 'Bearer synthetic-A');
                entered.complete();
                await gate.future;
                return http.Response(
                  '{"data":{"results":[{"status":"accepted"}]}}',
                  200,
                );
              }),
            )
            ..sessionGenerationProvider = (() => generation)
            ..tokenProvider = (() => token);
      final pending = api.post('/sync/push', body: {'operations': []});
      final assertion = expectLater(
        pending,
        throwsA(isA<StaleSessionException>()),
      );
      await entered.future;
      generation++;
      token = 'synthetic-B';
      gate.complete();
      await assertion;
    },
  );

  test('a queued A write never leaves the queue with B credentials', () async {
    final release = Completer<void>();
    final entered = Completer<void>();
    var occupying = 0;
    final blockers = List.generate(
      3,
      (_) => ApiRequestQueue.instance.add(() async {
        if (++occupying == 3) entered.complete();
        await release.future;
        return 0;
      }, maxRetries: 0),
    );
    await entered.future;
    var generation = 1;
    var token = 'synthetic-A';
    var sent = 0;
    final api =
        ApiClient.forTesting(
            MockClient((_) async {
              sent++;
              return http.Response('{}', 200);
            }),
          )
          ..sessionGenerationProvider = (() => generation)
          ..tokenProvider = (() => token);
    final old = api.post('/sync/push', body: {'operations': []});
    final assertion = expectLater(old, throwsA(isA<StaleSessionException>()));
    generation++;
    token = 'synthetic-B';
    release.complete();
    await Future.wait(blockers);
    await assertion;
    expect(sent, 0);
  });

  test('failure is not retained as a shared completed request', () async {
    var calls = 0;
    final api = ApiClient.forTesting(
      MockClient((_) async => http.Response('{}', ++calls == 1 ? 500 : 200)),
    );
    await expectLater(
      api.get('/orders', maxRetries: 0),
      throwsA(isA<ApiException>()),
    );
    await api.get('/orders', maxRetries: 0);
    expect(calls, 2);
  });

  test(
    'date reads separate clinic scopes even when the token is unchanged',
    () async {
      final oldEntered = Completer<void>();
      final releaseOld = Completer<void>();
      var calls = 0;
      final api = ApiClient.forTesting(
        MockClient((request) async {
          calls++;
          if (request.headers['X-Clinical-Clinic'] == 'old-clinic') {
            oldEntered.complete();
            await releaseOld.future;
            return http.Response(
              '{"code":"clinical_scope_changed","message":"Scope changed"}',
              403,
            );
          }
          return http.Response('{"data":{"clinic":"new-clinic"}}', 200);
        }),
      )..tokenProvider = (() => 'unchanged-token');
      const query = {'from': '2026-11-01', 'to': '2026-11-01', 'page': '1'};
      const currentHeaders = {
        'X-Clinical-Clinic': 'new-clinic',
        'X-Clinical-Scope-Version': '2',
      };
      final old = api.get(
        '/appointments',
        query: query,
        maxRetries: 0,
        headers: {
          'X-Clinical-Clinic': 'old-clinic',
          'X-Clinical-Scope-Version': '1',
        },
      );
      final oldAssertion = expectLater(old, throwsA(isA<ApiException>()));
      await oldEntered.future;
      final current = await api.get(
        '/appointments',
        query: query,
        headers: currentHeaders,
        maxRetries: 0,
        freshness: const Duration(seconds: 20),
      );
      expect(current.data['data']['clinic'], 'new-clinic');
      expect(calls, 2);
      releaseOld.complete();
      await oldAssertion;
      final cached = await api.get(
        '/appointments',
        query: query,
        headers: currentHeaders,
        maxRetries: 0,
        freshness: const Duration(seconds: 20),
      );
      expect(cached.data['data']['clinic'], 'new-clinic');
      expect(calls, 2);
    },
  );

  test(
    'a queued clinical write retains its scope with an unchanged token',
    () async {
      final release = Completer<void>();
      final entered = Completer<void>();
      var occupied = 0;
      final blockers = List.generate(
        3,
        (_) => ApiRequestQueue.instance.add(() async {
          if (++occupied == 3) entered.complete();
          await release.future;
          return 0;
        }, maxRetries: 0),
      );
      await entered.future;
      var clinic = 'old-clinic';
      final api = ApiClient.forTesting(
        MockClient((request) async {
          expect(request.headers['X-Clinical-Clinic'], 'old-clinic');
          expect(request.headers['X-Clinical-Scope-Version'], '1');
          expect(clinic, 'new-clinic');
          return http.Response(
            '{"code":"clinical_scope_changed","message":"Scope changed"}',
            403,
          );
        }),
      )..tokenProvider = (() => 'same-account-token');
      final pending = api.post(
        '/patients',
        body: {
          'data': {'name': 'Pending'},
        },
        headers: Map.unmodifiable({
          'X-Clinical-Clinic': clinic,
          'X-Clinical-Scope-Version': '1',
        }),
        maxRetries: 0,
      );
      final assertion = expectLater(
        pending,
        throwsA(
          isA<ApiException>().having(
            (error) => (error.details as Map)['code'],
            'scope rejection',
            'clinical_scope_changed',
          ),
        ),
      );
      clinic = 'new-clinic';
      release.complete();
      await Future.wait(blockers);
      await assertion;
    },
  );
}
