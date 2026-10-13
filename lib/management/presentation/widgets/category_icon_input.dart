import 'package:flutter/material.dart';
import 'package:studentry/utils/variable_colors.dart';

class CategoryIconInput extends StatefulWidget {
  const CategoryIconInput({
    super.key,
    required this.controller,
    required this.onPick,
    this.onBusyChanged,
  });

  final TextEditingController controller;
  final Future<String?> Function() onPick;
  final ValueChanged<bool>? onBusyChanged;

  @override
  State<CategoryIconInput> createState() => _CategoryIconInputState();
}

class _CategoryIconInputState extends State<CategoryIconInput> {
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      final url = await widget.onPick();
      if (!mounted) return;
      if (url != null && url.isNotEmpty) widget.controller.text = url;
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذّر رفع الأيقونة: $error');
    } finally {
      widget.onBusyChanged?.call(false);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _pick,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            _busy ? 'عم نرفع الأيقونة...' : 'اختيار أيقونة من الجهاز (اختياري)',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: 'أو رابط الأيقونة (اختياري)',
            hintText: 'https://...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, value, _) {
            final url = value.text.trim();
            if (url.isEmpty) return const SizedBox.shrink();
            final uri = Uri.tryParse(url);
            if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    url,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.category_outlined,
                      size: 44,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
