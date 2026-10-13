import 'package:flutter/material.dart';
import 'package:studentry/utils/variable_colors.dart';

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
    if (lastPage <= 1 && !loading) return const SizedBox.shrink();
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 78,
              child: TextButton.icon(
                onPressed: loading ? null : onPrevious,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  minimumSize: const Size(70, 40),
                ),
                icon: const Icon(Icons.chevron_right_rounded, size: 16),
                label: const Text('السابق', style: TextStyle(fontSize: 12)),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 70),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '$currentPage من $lastPage',
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            SizedBox(
              width: 78,
              child: TextButton.icon(
                onPressed: loading ? null : onNext,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  minimumSize: const Size(70, 40),
                ),
                icon: const Icon(Icons.chevron_left_rounded, size: 16),
                label: const Text('التالي', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
