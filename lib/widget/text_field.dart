import 'package:flutter/material.dart';
import 'package:yaman/widget/variable.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.colorborder,
    required this.hint,
    required this.icons,
    required this.onchanged,
    required this.pass,
    this.controller,
  });
  
  final Color colorborder;
  final String hint;
  final Icon icons;
  final ValueChanged<String> onchanged;
  final bool pass;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: pass,
      textAlign: TextAlign.center,
      onChanged: onchanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: textcolor.withValues(alpha: 0.12),
        suffixIcon: icons,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 16, color: Colors.white70),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: textcolor.withValues(alpha: 0.5),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorborder, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
