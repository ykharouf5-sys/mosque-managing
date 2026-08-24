import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  const legacyDartPackage =
      'package:'
      'dentalcare/';

  group('Studentry identity', () {
    test('uses the canonical package and application identifiers', () {
      expect(_read('pubspec.yaml'), contains('name: studentry'));

      final androidBuild = _read('android/app/build.gradle.kts');
      expect(androidBuild, contains('namespace = "io.studentry.app"'));
      expect(androidBuild, contains('applicationId = "io.studentry.app"'));

      final androidManifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(androidManifest, contains('android:label="Studentry"'));
      expect(androidManifest, contains('android:scheme="studentry"'));

      final mainActivity = _read(
        'android/app/src/main/kotlin/io/studentry/app/MainActivity.kt',
      );
      expect(mainActivity, contains('package io.studentry.app'));

      final iosProject = _read('ios/Runner.xcodeproj/project.pbxproj');
      expect(
        iosProject,
        contains('PRODUCT_BUNDLE_IDENTIFIER = io.studentry.app;'),
      );

      final iosInfo = _read('ios/Runner/Info.plist');
      expect(iosInfo, contains('<string>Studentry</string>'));
      expect(iosInfo, contains('<string>studentry</string>'));

      final webManifest = _read('web/manifest.json');
      expect(webManifest, contains('"name": "Studentry"'));
      expect(webManifest, contains('"short_name": "Studentry"'));
    });

    test('contains no active imports using the previous Dart package', () {
      final dartFiles = <File>[
        ...Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart')),
        ...Directory('test')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart')),
      ];

      for (final file in dartFiles) {
        expect(
          file.readAsStringSync(),
          isNot(contains(legacyDartPackage)),
          reason: 'Legacy package import remains in ${file.path}',
        );
      }
    });

    test('platform identity files contain no previous app identifiers', () {
      const identityFiles = [
        'android/app/build.gradle.kts',
        'android/app/src/main/AndroidManifest.xml',
        'ios/Runner/Info.plist',
        'ios/Runner.xcodeproj/project.pbxproj',
        'linux/CMakeLists.txt',
        'macos/Runner/Configs/AppInfo.xcconfig',
        'web/index.html',
        'web/manifest.json',
        'windows/runner/Runner.rc',
      ];
      const legacyIdentifiers = [
        'com.example.aqua',
        'io.dentalcare.app',
        legacyDartPackage,
      ];

      for (final path in identityFiles) {
        final content = _read(path);
        for (final identifier in legacyIdentifiers) {
          expect(
            content,
            isNot(contains(identifier)),
            reason: '$identifier remains in $path',
          );
        }
      }
    });

    test(
      'Android release configuration removes restricted ad and alarm access',
      () {
        final manifest = _read('android/app/src/main/AndroidManifest.xml');
        expect(manifest, isNot(contains('SCHEDULE_EXACT_ALARM')));
        expect(manifest, isNot(contains('USE_EXACT_ALARM')));
        expect(
          RegExp(r'AD_ID" tools:node="remove"').allMatches(manifest).length,
          greaterThanOrEqualTo(2),
        );

        final gradle = _read('android/app/build.gradle.kts');
        expect(gradle, isNot(contains('firebase-analytics')));
        expect(gradle, isNot(contains('play-services-auth')));
      },
    );
  });
}
