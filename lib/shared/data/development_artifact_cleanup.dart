import 'dart:io';
import 'package:path/path.dart' as p;

/// Only obsolete Flutter debug VM payloads, never documents/photos/databases.
/// The caller must run compiled (release/profile), not an active debug VM.
Future<int> removeObsoleteDebugArtifacts(
  Directory documents, {
  required bool compiledRuntime,
}) async {
  if (!compiledRuntime) return 0;
  final assets = Directory(p.join(documents.path, 'flutter_assets'));
  if (!await assets.exists()) return 0;
  final root = await documents.resolveSymbolicLinks();
  final resolved = await assets.resolveSymbolicLinks();
  if (!p.equals(resolved, p.join(root, 'flutter_assets'))) return 0;
  const names = [
    'kernel_blob.bin',
    'isolate_snapshot_data',
    'vm_snapshot_data',
  ];
  // Require the known debug runtime triplet. Leave unfamiliar files untouched.
  for (final name in names) {
    if (await FileSystemEntity.type(
          p.join(assets.path, name),
          followLinks: false,
        ) !=
        FileSystemEntityType.file) {
      return 0;
    }
  }
  var bytes = 0;
  for (final name in names) {
    final file = File(p.join(assets.path, name));
    bytes += await file.length();
    await file.delete();
  }
  return bytes;
}
