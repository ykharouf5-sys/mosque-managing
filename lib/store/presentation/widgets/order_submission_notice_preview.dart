import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'order_submission_notice.dart';

@Preview(name: 'Queued offline order', group: 'Checkout', size: Size(320, 100))
Widget queuedOrderPreview() => const Directionality(
  textDirection: TextDirection.rtl,
  child: Material(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: OrderSubmissionNotice(awaitingSync: true),
    ),
  ),
);

@Preview(name: 'Confirmed order', group: 'Checkout', size: Size(320, 100))
Widget confirmedOrderPreview() => const Directionality(
  textDirection: TextDirection.rtl,
  child: Material(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: OrderSubmissionNotice(awaitingSync: false),
    ),
  ),
);
