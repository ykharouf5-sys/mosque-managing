import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'storage_usage_panel.dart';
import 'package:studentry/shared/data/storage_usage.dart';

@Preview(name: 'App storage breakdown', group: 'Settings', size: Size(380, 760))
Widget storageUsagePreview() => const Directionality(
  textDirection: TextDirection.rtl,
  child: Material(
    child: StorageUsagePanel(
      usage: StorageUsage(
        databases: 30 * 1024 * 1024,
        clinicalFiles: 10 * 1024 * 1024,
        temporaryFiles: 1024 * 1024,
        otherFiles: 100 * 1024 * 1024,
      ),
    ),
  ),
);
