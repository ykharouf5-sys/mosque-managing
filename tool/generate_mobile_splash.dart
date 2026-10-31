import 'dart:io';

/// Regenerate Android only, including the Android 12 circular-mask safe inset.
Future<void> main() async {
  final result = await Process.run(Platform.resolvedExecutable, [
    'run',
    'flutter_native_splash:create',
    '--path=flutter_native_splash.yaml',
  ]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) exit(result.exitCode);
  for (final mode in ['values-v31', 'values-night-v31']) {
    final file = File('android/app/src/main/res/$mode/styles.xml');
    final xml = await file.readAsString();
    await file.writeAsString(
      xml.replaceAll(
        '@drawable/android12splash',
        '@drawable/studentry_splash_safe',
      ),
    );
  }
  stdout.writeln('Android 12 safe splash inset applied.');
}
