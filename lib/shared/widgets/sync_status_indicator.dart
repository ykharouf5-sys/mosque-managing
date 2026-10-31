import 'package:flutter/material.dart';
import 'package:studentry/shared/data/sync_service.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatusSnapshot>(
      valueListenable: SyncService.status,
      builder: (context, status, _) {
        if (status.failedPermanent > 0) {
          return _SyncStatusBadge(
            icon: Icons.cloud_off_rounded,
            color: Colors.orange.shade800,
            label: 'تعذرت مزامنة ${status.failedPermanent} تغييرات',
          );
        }
        if (status.waiting > 0) {
          final details = _waitingDetails(status.waitingByTable);
          return _SyncStatusBadge(
            icon: status.isSyncing
                ? Icons.sync_rounded
                : Icons.cloud_upload_outlined,
            color: Theme.of(context).colorScheme.primary,
            label: status.isSyncing
                ? 'تتم مزامنة ${status.waiting} تغييرات$details'
                : '${status.waiting} تغييرات بانتظار المزامنة$details',
          );
        }
        if (status.pullError != null) {
          return _SyncStatusBadge(
            icon: Icons.cloud_off_rounded,
            color: Colors.orange.shade800,
            label: 'تعذر جلب التحديثات؛ البيانات المحلية محفوظة',
          );
        }
        if (status.recoverySnapshots > 0) {
          return _SyncStatusBadge(
            icon: Icons.history_rounded,
            color: Colors.orange.shade800,
            label:
                'توجد ${status.recoverySnapshots} نسخ استعادة سريرية تحتاج مراجعة',
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  String _waitingDetails(Map<String, int> values) {
    const labels = {
      'patients': 'مرضى',
      'appointments': 'مواعيد',
      'patient_payments': 'دفعات',
    };
    final parts = values.entries
        .where((entry) => entry.value > 0)
        .map((entry) => '${entry.value} ${labels[entry.key] ?? entry.key}')
        .toList(growable: false);
    return parts.isEmpty ? '' : ' (${parts.join('، ')})';
  }
}

class _SyncStatusBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _SyncStatusBadge({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: .25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
