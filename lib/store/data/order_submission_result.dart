class OrderSubmissionResult {
  final String status;
  final Map<String, dynamic>? confirmedOrder;
  final Duration? retryAfter;

  const OrderSubmissionResult(
    this.status, {
    this.confirmedOrder,
    this.retryAfter,
  });

  bool get isConfirmed => status == 'inserted' || status == 'exists';
  bool get isPermanentFailure =>
      status == 'insufficient_stock' ||
      status == 'invalid_order' ||
      status == 'payment_failed' ||
      status == 'forbidden';
}
