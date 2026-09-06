import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int lastPage;
  final bool loading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.lastPage,
    required this.loading,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: loading ? null : onPrevious,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('السابق', maxLines: 1),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Text('$currentPage / $lastPage'),
        ),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: loading ? null : onNext,
            icon: loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_left_rounded),
            label: const Text('التالي', maxLines: 1),
          ),
        ),
      ],
    );
  }
}
