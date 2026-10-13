import 'package:flutter/material.dart';

String orderSubmissionMessage({
  required bool awaitingSync,
  bool failed = false,
}) {
  if (failed) return 'تعذر إرسال الطلب، راجع السلة أو المخزون';
  return awaitingSync
      ? 'تم حفظ الطلب على جهازك، بانتظار الإرسال عند توفر الاتصال'
      : 'تم إرسال الطلب بنجاح';
}

class OrderSubmissionNotice extends StatelessWidget {
  final bool awaitingSync;
  final bool failed;

  const OrderSubmissionNotice({
    super.key,
    required this.awaitingSync,
    this.failed = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        failed
            ? Icons.error_outline
            : awaitingSync
            ? Icons.cloud_upload_outlined
            : Icons.check_circle_outline,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          orderSubmissionMessage(awaitingSync: awaitingSync, failed: failed),
        ),
      ),
    ],
  );
}
