import 'package:flutter/material.dart';
import 'package:yaman/utils/responsive_helper.dart';

/// Responsive Stats Card يتناسب مع جميع أحجام الشاشات
class ResponsiveStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color? color;

  const ResponsiveStatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Container(
      width: responsive.cardWidth(),
      padding: responsive.padding(12, tablet: 16, desktop: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(responsive.borderRadius()),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          if (icon != null)
            Icon(icon, color: color ?? Colors.blue, size: responsive.iconSize())
          else
            SizedBox(height: responsive.iconSize()),

          SizedBox(height: responsive.verticalSpace()),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: responsive.fontSize(12, tablet: 14, desktop: 16),
              fontWeight: FontWeight.w500,
            ),
          ),

          SizedBox(height: responsive.verticalSpace() / 2),

          // Value
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.blue,
              fontSize: responsive.fontSize(22, tablet: 26, desktop: 30),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive Button
class ResponsiveButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isFullWidth;

  const ResponsiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    final button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null
          ? Icon(icon, size: responsive.iconSize() * 0.8)
          : const SizedBox.shrink(),
      label: Text(
        label,
        style: TextStyle(
          fontSize: responsive.fontSize(14, tablet: 16, desktop: 18),
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: responsive.padding(12, tablet: 16, desktop: 20),
        minimumSize: Size(
          isFullWidth ? double.infinity : 120,
          responsive.fontSize(48, tablet: 56, desktop: 60),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(responsive.borderRadius()),
        ),
      ),
    );

    if (isFullWidth) {
      return button;
    }

    return Align(alignment: Alignment.center, child: button);
  }
}

/// Responsive Table Cell
class ResponsiveTableCell extends StatelessWidget {
  final String text;
  final Alignment alignment;

  const ResponsiveTableCell(
    this.text, {
    super.key,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Padding(
      padding: responsive.padding(6, tablet: 8, desktop: 10),
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: TextStyle(
            fontSize: responsive.fontSize(12, tablet: 14, desktop: 16),
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Responsive Grid List (بدل GridView.builder للبساطة)
class ResponsiveGridList extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;

  const ResponsiveGridList({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final crossAxisCount = responsive.gridCrossAxisCount();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: responsive.horizontalSpace(),
      crossAxisSpacing: responsive.verticalSpace(),
      children: children,
    );
  }
}

/// Responsive Dialog
class ResponsiveAlertDialog extends StatelessWidget {
  final String title;
  final String content;
  final List<TextButton> actions;

  const ResponsiveAlertDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(responsive.borderRadius()),
      ),
      child: Padding(
        padding: responsive.padding(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: responsive.fontSize(18, tablet: 20, desktop: 22),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: responsive.verticalSpace()),
            Text(
              content,
              style: TextStyle(
                fontSize: responsive.fontSize(14, tablet: 16, desktop: 18),
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: responsive.verticalSpace() * 1.5),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }
}
