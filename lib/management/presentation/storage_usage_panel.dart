import 'package:flutter/material.dart';
import 'package:studentry/shared/data/storage_usage.dart';

class StorageUsagePanel extends StatelessWidget {
  final StorageUsage usage;
  final bool busy;
  final VoidCallback? onClean;
  final VoidCallback? onCompact;
  const StorageUsagePanel({
    super.key,
    required this.usage,
    this.busy = false,
    this.onClean,
    this.onCompact,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'ملفات التطبيق: ${StorageUsage.formatBytes(usage.total)}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      const Text(
        'هذا قياس الملفات التي يستطيع التطبيق قراءتها، وليس حجم التثبيت الذي يعرضه أندرويد.',
      ),
      const SizedBox(height: 16),
      for (final row in [
        ('قواعد البيانات المحلية', usage.databases),
        ('ملفات المرضى المحلية', usage.clinicalFiles),
        ('التفضيلات والبيانات المحفوظة', usage.preferences),
        ('ملفات مؤقتة وملفات تشغيل', usage.temporaryFiles),
        ('ملفات داخلية إضافية', usage.otherFiles),
      ])
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(row.$1),
          trailing: Text(StorageUsage.formatBytes(row.$2)),
        ),
      const Divider(),
      const Text(
        'لا نحذف المرضى، صورهم، المفضلة أو الطلبات بانتظار الإرسال. الضغط يسترجع المساحة الفارغة داخل قاعدة البيانات فقط.',
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: busy ? null : onCompact,
        child: const Text('ضغط قاعدة البيانات'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: busy ? null : onClean,
        child: const Text('تنظيف الملفات المؤقتة'),
      ),
      if (busy)
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: LinearProgressIndicator(),
        ),
    ],
  );
}
