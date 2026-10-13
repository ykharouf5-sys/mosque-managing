import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/shared/data/development_artifact_cleanup.dart';

void main() {
  test(
    'compiled runtime removes only debug triplet, preserving clinical files',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'studentry-debug-cleanup-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final assets = await Directory('${root.path}/flutter_assets').create();
      for (final name in [
        'kernel_blob.bin',
        'isolate_snapshot_data',
        'vm_snapshot_data',
      ]) {
        await File('${assets.path}/$name').writeAsBytes([1, 2, 3]);
      }
      final medical = await File(
        '${root.path}/patient.webp',
      ).writeAsBytes([4, 5]);
      final other = await File(
        '${assets.path}/unfamiliar.bin',
      ).writeAsBytes([6]);
      expect(
        await removeObsoleteDebugArtifacts(root, compiledRuntime: false),
        0,
      );
      expect(
        await removeObsoleteDebugArtifacts(root, compiledRuntime: true),
        9,
      );
      expect(await medical.exists(), true);
      expect(await other.exists(), true);
      expect(
        await removeObsoleteDebugArtifacts(root, compiledRuntime: true),
        0,
      );
    },
  );
}
