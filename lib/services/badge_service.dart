import 'package:yaman/models/student.dart';

class Badge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String category; // streak, performance, attendance, special
  final int requiredCount;
  final DateTime? unlockedDate;
  final bool isUnlocked;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.requiredCount,
    this.unlockedDate,
    this.isUnlocked = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'category': category,
      'requiredCount': requiredCount,
      'unlockedDate': unlockedDate?.toIso8601String(),
      'isUnlocked': isUnlocked,
    };
  }

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      category: json['category'] ?? '',
      requiredCount: json['requiredCount'] ?? 0,
      unlockedDate: json['unlockedDate'] != null
          ? DateTime.parse(json['unlockedDate'])
          : null,
      isUnlocked: json['isUnlocked'] ?? false,
    );
  }
}

class BadgeService {
  // تعريف جميع الأوسمة المتاحة
  static final List<Badge> availableBadges = [
    // أوسمة الالتزام
    Badge(
      id: 'first_step',
      name: 'الخطوة الأولى',
      description: 'أدخل صلاتك لأول مرة',
      icon: '👣',
      category: 'streak',
      requiredCount: 1,
    ),
    Badge(
      id: 'week_warrior',
      name: 'محارب الأسبوع',
      description: 'أكمل صلواتك 7 أيام متتالية',
      icon: '🗓️',
      category: 'streak',
      requiredCount: 7,
    ),
    Badge(
      id: 'month_master',
      name: 'سيد الشهر',
      description: 'أكمل صلواتك 30 يوماً متتالياً',
      icon: '📆',
      category: 'streak',
      requiredCount: 30,
    ),
    Badge(
      id: 'century_club',
      name: 'نادي المائة',
      description: 'أكمل صلواتك 100 يوم متتالي',
      icon: '💯',
      category: 'streak',
      requiredCount: 100,
    ),

    // أوسمة الأداء
    Badge(
      id: 'perfect_week',
      name: 'أسبوع مثالي',
      description: 'أكمل جميع صلوات الأسبوع جماعة',
      icon: '⭐',
      category: 'performance',
      requiredCount: 35, // 5 صلوات × 7 أيام
    ),
    Badge(
      id: 'perfect_month',
      name: 'شهر مثالي',
      description: 'أكمل جميع صلوات الشهر جماعة',
      icon: '✨',
      category: 'performance',
      requiredCount: 150, // 5 صلوات × 30 يوم
    ),
    Badge(
      id: 'high_performer',
      name: 'أداء عالي',
      description: 'حافظ على متوسط أداء 2.5 أو أعلى لمدة شهر',
      icon: '🚀',
      category: 'performance',
      requiredCount: 30,
    ),

    // أوسمة الحضور
    Badge(
      id: 'attendance_bronze',
      name: 'برونز الحضور',
      description: 'حضر 10 جلسات متتالية',
      icon: '🥉',
      category: 'attendance',
      requiredCount: 10,
    ),
    Badge(
      id: 'attendance_silver',
      name: 'فضة الحضور',
      description: 'حضر 30 جلسة متتالية',
      icon: '🥈',
      category: 'attendance',
      requiredCount: 30,
    ),
    Badge(
      id: 'attendance_gold',
      name: 'ذهب الحضور',
      description: 'حضر 50 جلسة متتالية',
      icon: '🥇',
      category: 'attendance',
      requiredCount: 50,
    ),

    // أوسمة خاصة
    Badge(
      id: 'comeback_kid',
      name: 'طفل العودة',
      description: 'أكمل 7 أيام بعد تعطل لمدة أسبوع',
      icon: '📈',
      category: 'special',
      requiredCount: 7,
    ),
    Badge(
      id: 'night_owl',
      name: 'بومة الليل',
      description: 'أكمل صلاة العشاء 20 يوماً متتالياً',
      icon: '🌙',
      category: 'special',
      requiredCount: 20,
    ),
    Badge(
      id: 'early_bird',
      name: 'الطير المبكر',
      description: 'أكمل صلاة الفجر 20 يوماً متتالياً',
      icon: '🌅',
      category: 'special',
      requiredCount: 20,
    ),
    Badge(
      id: 'helper',
      name: 'المساعد',
      description: 'شارك 5 طلاب آخرين في تحفيزهم',
      icon: '🤝',
      category: 'special',
      requiredCount: 5,
    ),
  ];

  /// الحصول على أوسمة الطالب المفتوحة
  static List<Badge> getUnlockedBadges(Student student) {
    List<Badge> unlocked = [];

    // فحص الأوسمة بناءً على بيانات الطالب
    for (var badge in availableBadges) {
      if (_isBadgeUnlocked(student, badge)) {
        unlocked.add(
          badge.copyWith(isUnlocked: true, unlockedDate: DateTime.now()),
        );
      }
    }

    return unlocked;
  }

  /// الحصول على الأوسمة القريبة من التحقق
  static List<BadgeProgress> getNearbyBadges(Student student) {
    List<BadgeProgress> nearby = [];

    for (var badge in availableBadges) {
      if (!_isBadgeUnlocked(student, badge)) {
        final progress = _getBadgeProgress(student, badge);
        if (progress > 0.5) {
          // أقرب من 50%
          nearby.add(
            BadgeProgress(
              badge: badge,
              progress: progress,
              current: _getCurrentBadgeCount(student, badge),
              required: badge.requiredCount,
            ),
          );
        }
      }
    }

    // ترتيب حسب التقدم
    nearby.sort((a, b) => b.progress.compareTo(a.progress));
    return nearby;
  }

  /// فحص ما إذا كان الأوسمة غير مفتوحة
  static bool _isBadgeUnlocked(Student student, Badge badge) {
    switch (badge.id) {
      case 'first_step':
        return student.prayers.isNotEmpty;

      case 'week_warrior':
        return _getConsecutiveDays(student) >= 7;

      case 'month_master':
        return _getConsecutiveDays(student) >= 30;

      case 'century_club':
        return _getConsecutiveDays(student) >= 100;

      case 'perfect_week':
        return _getPerfectWeekCount(student) >= 35;

      case 'perfect_month':
        return _getPerfectMonthCount(student) >= 150;

      case 'high_performer':
        return _getMonthlyAveragePerformance(student) >= 2.5;

      case 'attendance_bronze':
        return (student.attendance.length ?? 0) >= 10;

      case 'attendance_silver':
        return (student.attendance.length ?? 0) >= 30;

      case 'attendance_gold':
        return (student.attendance.length ?? 0) >= 50;

      case 'night_owl':
        return _getConsecutiveSpecificPrayer(student, 4) >=
            20; // العشاء هو الصلاة 4

      case 'early_bird':
        return _getConsecutiveSpecificPrayer(student, 0) >=
            20; // الفجر هو الصلاة 0

      case 'comeback_kid':
        return _isCombackKid(student);

      case 'helper':
        return (student.points ?? 0) >= 50; // تقريبي

      default:
        return false;
    }
  }

  /// الحصول على نسبة التقدم لأوسمة
  static double _getBadgeProgress(Student student, Badge badge) {
    final current = _getCurrentBadgeCount(student, badge);
    return (current / badge.requiredCount).clamp(0.0, 1.0);
  }

  /// الحصول على عدد أيام متتالية للصلوات
  static int _getConsecutiveDays(Student student) {
    if (student.prayers.isEmpty) return 0;

    int consecutive = 0;
    for (int i = student.prayers.length - 1; i >= 0; i--) {
      final day = student.prayers[i];
      if (day.isNotEmpty) {
        consecutive++;
      } else {
        break;
      }
    }
    return consecutive;
  }

  /// الحصول على عدد الصلوات المتكاملة (جماعة) في الأسبوع الأخير
  static int _getPerfectWeekCount(Student student) {
    if (student.prayers.isEmpty) return 0;

    int jamaahCount = 0;
    final lastWeek = student.prayers.length >= 7
        ? student.prayers.sublist(student.prayers.length - 7)
        : student.prayers;

    for (var day in lastWeek) {
      for (var prayer in day) {
        if (prayer == 'جماعة') {
          jamaahCount++;
        }
      }
        }

    return jamaahCount;
  }

  /// الحصول على عدد الصلوات المتكاملة (جماعة) في الشهر الأخير
  static int _getPerfectMonthCount(Student student) {
    if (student.prayers.isEmpty) return 0;

    int jamaahCount = 0;
    final lastMonth = student.prayers.length >= 30
        ? student.prayers.sublist(student.prayers.length - 30)
        : student.prayers;

    for (var day in lastMonth) {
      for (var prayer in day) {
        if (prayer == 'جماعة') {
          jamaahCount++;
        }
      }
        }

    return jamaahCount;
  }

  /// حساب متوسط الأداء الشهري
  static double _getMonthlyAveragePerformance(Student student) {
    if (student.prayers.isEmpty) return 0;

    int total = 0;
    int count = 0;
    final lastMonth = student.prayers.length >= 30
        ? student.prayers.sublist(student.prayers.length - 30)
        : student.prayers;

    for (var day in lastMonth) {
      for (var prayer in day) {
        if (prayer == 'جماعة') {
          total += 3;
        } else if (prayer == 'أداء') {
          total += 2;
        } else if (prayer == 'قضاء') {
          total += 1;
        }
        count++;
      }
        }

    return count > 0 ? total / count : 0;
  }

  /// الحصول على أيام متتالية لصلاة محددة
  static int _getConsecutiveSpecificPrayer(Student student, int prayerIndex) {
    if (student.prayers.isEmpty) return 0;

    int consecutive = 0;
    for (int i = student.prayers.length - 1; i >= 0; i--) {
      final day = student.prayers[i];
      if (day.length > prayerIndex) {
        if (day[prayerIndex] == 'جماعة' || day[prayerIndex] == 'أداء') {
          consecutive++;
        } else {
          break;
        }
      } else {
        break;
      }
    }
    return consecutive;
  }

  /// فحص ما إذا كان الطالب comeback kid
  static bool _isCombackKid(Student student) {
    if (student.prayers.length < 14) return false;

    // ابحث عن فجوة 7 أيام ثم 7 أيام متتالية
    int lastGapStart = -1;
    int consecutiveAfterGap = 0;

    for (int i = student.prayers.length - 1; i >= 0; i--) {
      final day = student.prayers[i];
      if (day.isEmpty) {
        if (consecutiveAfterGap >= 7) {
          return true; // وجدنا!
        }
        lastGapStart = i;
        consecutiveAfterGap = 0;
      } else {
        consecutiveAfterGap++;
      }
    }

    return consecutiveAfterGap >= 7 && lastGapStart > 0;
  }

  /// الحصول على العدد الحالي لأوسمة
  static int _getCurrentBadgeCount(Student student, Badge badge) {
    switch (badge.id) {
      case 'first_step':
      case 'week_warrior':
      case 'month_master':
      case 'century_club':
        return _getConsecutiveDays(student);

      case 'perfect_week':
        return _getPerfectWeekCount(student);

      case 'perfect_month':
        return _getPerfectMonthCount(student);

      case 'high_performer':
        return (_getMonthlyAveragePerformance(student) * 10).toInt();

      case 'attendance_bronze':
      case 'attendance_silver':
      case 'attendance_gold':
        return student.attendance.length ?? 0;

      case 'night_owl':
        return _getConsecutiveSpecificPrayer(student, 4);

      case 'early_bird':
        return _getConsecutiveSpecificPrayer(student, 0);

      case 'comeback_kid':
        return _isCombackKid(student) ? 1 : 0;

      case 'helper':
        return (student.points ?? 0) ~/ 10;

      default:
        return 0;
    }
  }
}

/// نموذج تقدم الأوسمة
class BadgeProgress {
  final Badge badge;
  final double progress;
  final int current;
  final int required;

  BadgeProgress({
    required this.badge,
    required this.progress,
    required this.current,
    required this.required,
  });

  int get percentComplete => (progress * 100).toInt();
}

extension BadgeCopy on Badge {
  Badge copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? category,
    int? requiredCount,
    DateTime? unlockedDate,
    bool? isUnlocked,
  }) {
    return Badge(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      requiredCount: requiredCount ?? this.requiredCount,
      unlockedDate: unlockedDate ?? this.unlockedDate,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}
