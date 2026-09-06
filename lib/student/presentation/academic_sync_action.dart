import 'package:flutter/material.dart';
import '../data/academic_store.dart';

/// Only appears when synchronization needs attention; existing layouts stay put.
class AcademicSyncAction extends StatelessWidget {
  const AcademicSyncAction({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AcademicStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => store.error == null
          ? const SizedBox.shrink()
          : IconButton(
              tooltip: 'تعذّرت مزامنة البيانات الدراسية',
              icon: Icon(
                Icons.sync_problem,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                final discard = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('مزامنة البيانات الدراسية'),
                    content: SingleChildScrollView(
                      child: Text(
                        'تعديلاتك محفوظة على هذا الجهاز ولم تكتمل مزامنتها.\n\n${store.error}\n\n'
                        'إعادة المحاولة تحفظ التعديلات. اختيار نسخة الخادم يلغي جميع التعديلات الدراسية التي لم تُرسل من هذا الحساب.',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إغلاق'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إعادة المحاولة'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('اختيار نسخة الخادم'),
                      ),
                    ],
                  ),
                );
                if (!context.mounted || discard == null) return;
                if (discard) {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('إلغاء التعديلات غير المرسلة؟'),
                      content: const Text(
                        'ستُحذف تعديلات المواد والبرنامج الدراسي الموجودة في طابور هذا الحساب. لا يمكن التراجع عن هذا الإجراء.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('رجوع'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('إلغاء التعديلات'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;
                }
                try {
                  if (discard) {
                    await store.discardPendingAndRefresh();
                  } else {
                    await store.retryPending();
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تعذّر إكمال العملية. حاول مجدداً.'),
                      ),
                    );
                  }
                }
              },
            ),
    );
  }
}
