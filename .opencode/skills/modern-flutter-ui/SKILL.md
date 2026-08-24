---
name: modern-flutter-ui
description: >-
  Modern Flutter UI/UX design skill for building beautiful, animated,
  production-grade mobile interfaces. Covers glassmorphism, neumorphism,
  Material 3, smooth animations with flutter_animate, responsive layouts,
  theming, micro-interactions, and component design patterns.
---

# Modern Flutter UI Skill

> Craft beautiful, animated, modern Flutter interfaces.

---

## Modern Design Aesthetics

### Glassmorphism (Frosted Glass)

```dart
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    color: Colors.white.withValues(alpha: 0.15),
    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: ... // your content
    ),
  ),
)
```

### Neumorphism (Soft UI)

```dart
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    color: surfaceColor,
    boxShadow: [
      BoxShadow(
        color: darkShadowColor, offset: const Offset(5, 5), blurRadius: 15,
      ),
      BoxShadow(
        color: lightShadowColor, offset: const Offset(-5, -5), blurRadius: 15,
      ),
    ],
  ),
)
```

### Gradient Premium

```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [primaryLight, primary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
)
```

---

## Animation with flutter_animate

Preferred over animate_do for declarative, composable animations.

```dart
import 'package:flutter_animate/flutter_animate.dart';

// Single effect
myWidget.animate().fadeIn(duration: 300.ms).slideX(begin: 0.2);

// Chained effects with delay
myWidget
    .animate()
    .fadeIn(duration: 400.ms)
    .slideY(begin: 0.3, duration: 400.ms, curve: Curves.easeOutQuad);

// Staggered list items
Column(
  children: items.map((item) => item.animate().fadeIn(
    duration: 300.ms,
    delay: (index * 100).ms,
  )).toList(),
)

// Hover/scale effect
myWidget.animate(onHover: true).scale(begin: 1.0, end: 1.05);
```

### Animation Timing Rules
- Fade in: 200-400ms
- Slide: 300-500ms
- Scale/transform: 150-250ms
- Stagger delay between items: 50-150ms
- Curve: `Curves.easeOutQuad` or `Curves.easeInOut` by default

---

## Color & Theme System

### AppColors Pattern (current project style)
```dart
class AppColors {
  static const Color primary = Color.fromARGB(255, 21, 169, 188);
  static const Color primaryLight = Color(0xFF80CBC4);
  static const Color primarySurface = Color(0xFFE0F7FA);
  static const Color background = Color(0xFFF8FBFC);
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF1E293B);
  static const Color textLight = Colors.white;
  static const Color textGray = Color(0xFF94A3B8);
  static const Color divider = Color(0xFFE0E0E0);
}
```

### Modern Color Palette Rules
- Primary takes 10-20% of screen surface
- Use `withValues(alpha:)` instead of deprecated `withOpacity()`
- Surface cards: white with subtle shadow
- Background: light neutral (F8FBFC)
- Status colors: success=green, pending=orange, danger=red

---

## Component Design Patterns

### Cards
```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.primary, width: 2),
    boxShadow: [BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 12, offset: const Offset(0, 4),
    )],
  ),
)
```

### Buttons
- Primary: `ElevatedButton` with `StadiumBorder()` for rounded look
- Outline: `OutlinedButton` with 1.5px primary border
- Avoid sharp corners for modern feel (borderRadius >= 12)

### Input Fields
```dart
TextField(
  decoration: InputDecoration(
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  ),
)
```

---

## SafeArea Convention (this project)
```dart
SafeArea(top: false, bottom: true, child: ...)
```
Apply to ALL bottom navigation bars. Screens without bottom nav wrap body with `SafeArea(bottom: true)`.

---

## Micro-Interactions Guidelines
- Pull-to-refresh: always include `RefreshIndicator` with `color: AppColors.primary`
- Empty states: icon + message + optional action button
- Loading: shimmer effect with `shimmer` package
- Error: SnackBar with action or full-screen error widget
- Success feedback: brief SnackBar or animated checkmark
- Page transitions: `MaterialPageRoute` with smooth slide

---

## Layout Rules
- Use 8-point spacing grid (4, 8, 12, 16, 20, 24, 32)
- `Spacer` and `Expanded` over fixed heights/widths
- Grid: `shrinkWrap: true` + `NeverScrollableScrollPhysics()` inside scrollable parent
- Bottom nav: 70px height with centered FAB
- SafeArea respected on all screens
