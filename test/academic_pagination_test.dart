import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/student/data/academic_api_service.dart';

Map<String, dynamic> subject(String id) => {
  'id': id,
  'name': 'Synthetic',
  'code': id,
  'academicYear': 'first',
  'lectures': <dynamic>[],
  'version': 1,
};

http.Response pageResponse(
  List<Map<String, dynamic>> rows,
  int page,
  int? next,
) => http.Response(
  jsonEncode({
    'data': rows,
    'meta': {'current_page': page, 'has_more': next != null, 'next_page': next},
  }),
  200,
  headers: {'etag': '"page-$page"'},
);

void main() {
  test(
    'collects all pages, deduplicates overlapping records and revalidates each page',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient.forTesting(
        MockClient((request) async {
          requests.add(request);
          final page = int.parse(request.url.queryParameters['page']!);
          if (request.headers['If-None-Match'] != null) {
            return http.Response('', 304);
          }
          return page == 1
              ? pageResponse([subject('a'), subject('b')], 1, 2)
              : pageResponse([subject('b'), subject('c')], 2, null);
        }),
      );
      final service = AcademicApiService(client: api);
      expect((await service.subjects()).map((s) => s.id), ['a', 'b', 'c']);
      expect((await service.subjects()).map((s) => s.id), ['a', 'b', 'c']);
      expect(requests.length, 4); // Revalidate even when memory cache is fresh.
      expect(requests[2].headers['If-None-Match'], '"page-1"');
      expect(requests[3].headers['If-None-Match'], '"page-2"');
      await service.subjects(force: true);
      expect(requests.length, 6);
      expect(requests[4].headers['If-None-Match'], isNull);
    },
  );

  test(
    'does not return a partial collection when a later page fails',
    () async {
      final api = ApiClient.forTesting(
        MockClient((request) async {
          return request.url.queryParameters['page'] == '1'
              ? pageResponse([subject('a')], 1, 2)
              : http.Response('{"message":"Forbidden"}', 403);
        }),
      );
      await expectLater(
        AcademicApiService(client: api).subjects(),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test(
    'rejects non-advancing pagination rather than looping forever',
    () async {
      final api = ApiClient.forTesting(
        MockClient((_) async => pageResponse([subject('a')], 1, 1)),
      );
      await expectLater(
        AcademicApiService(client: api).subjects(),
        throwsFormatException,
      );
    },
  );

  test('a session change between pages cannot mix two accounts', () async {
    var generation = 1;
    var calls = 0;
    late final ApiClient api;
    api = ApiClient.forTesting(
      MockClient((_) async {
        calls++;
        if (calls == 1) generation++;
        return pageResponse([subject('a')], 1, 2);
      }),
    )..sessionGenerationProvider = (() => generation);
    await expectLater(
      AcademicApiService(client: api).subjects(),
      throwsA(isA<StaleSessionException>()),
    );
    expect(calls, 1);
  });

  test('legacy arrays remain usable during a rolling backend update', () async {
    final api = ApiClient.forTesting(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': [subject('a')],
          }),
          200,
        ),
      ),
    );
    expect((await AcademicApiService(client: api).subjects()).single.id, 'a');
  });

  test(
    'enrollments also collect pages and retain student scope data',
    () async {
      final api = ApiClient.forTesting(
        MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page']!);
          return pageResponse(
            [
              {
                'enrollmentId': 'e$page',
                'subjectId': 's$page',
                'name': 'Synthetic',
                'code': 'SYN',
                'academicYear': 'first',
                'scheduleDays': [],
                'scheduleTimes': [],
                'viewedLectures': [],
                'version': 1,
              },
            ],
            page,
            page == 1 ? 2 : null,
          );
        }),
      );
      final rows = await AcademicApiService(client: api).enrollments();
      expect(rows.map((s) => s.enrollmentId), ['e1', 'e2']);
    },
  );
}
