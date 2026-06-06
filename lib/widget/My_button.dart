import 'package:flutter/material.dart';

class MaterialButtonYaman extends StatefulWidget {
  const MaterialButtonYaman({
    super.key,
    required this.onPressed,
    required this.color,
    required this.title,
    required this.colorText,
    this.width,
    this.height,
    this.borderRadius = 15,
    this.elevation = 5,
  });

  final VoidCallback onPressed;
  final Color color;
  final String title;
  final Color colorText;
  final double? width;
  final double? height;
  final double borderRadius;
  final double elevation;

  @override
  State<MaterialButtonYaman> createState() => _MaterialButtonYamanState();
}

class _MaterialButtonYamanState extends State<MaterialButtonYaman> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double buttonHeight = widget.height ?? 52;
    final double buttonWidth = widget.width ?? double.infinity;

    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: SizedBox(
          height: buttonHeight,
          width: buttonWidth,
          child: Material(
            elevation: widget.elevation,
            color: widget.color,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: InkWell(
              onTap: widget.onPressed,
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Center(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: widget.colorText,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
