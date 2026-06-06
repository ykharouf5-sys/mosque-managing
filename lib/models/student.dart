class Student {
  final String id;
  final String name;
  final String? teacherId; // Add teacherId
  final String phone;
  final String teacherName;
  final String teacherPhone;
  final String email;
  final String password;
  final int points;
  final List<bool> attendance; // true حاضر, false غياب
  final List<String>
  attendanceDates; // parallel list of dates for each attendance entry
  final List<List<String>>
  prayers; // قائمة بالأيام، كل يوم قائمة بـ5 صلوات: ['جماعة', 'أداء', 'قضاء', 'غياب']
  final List<String> prayerDates; // قائمة بتواريخ الصلاة لكل يوم
  final List<String> memorization; // قائمة بتقييم الحفظ لكل يوم
  final int dailyPointsAdded;
  final String lastPointsDate;

  Student({
    required this.id,
    required this.name,
    this.teacherId,
    required this.phone,
    required this.teacherName,
    required this.teacherPhone,
    required this.email,
    required this.password,
    required this.points,
    required this.attendance,
    this.attendanceDates = const [],
    required this.prayers,
    required this.prayerDates,
    required this.memorization,
    this.dailyPointsAdded = 0,
    this.lastPointsDate = '',
  });

  Student copyWith({
    String? id,
    String? name,
    String? teacherId,
    String? phone,
    String? teacherName,
    String? teacherPhone,
    String? email,
    String? password,
    int? points,
    List<bool>? attendance,
    List<String>? attendanceDates,
    List<List<String>>? prayers,
    List<String>? prayerDates,
    List<String>? memorization,
    int? dailyPointsAdded,
    String? lastPointsDate,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      teacherId: teacherId ?? this.teacherId,
      phone: phone ?? this.phone,
      teacherName: teacherName ?? this.teacherName,
      teacherPhone: teacherPhone ?? this.teacherPhone,
      email: email ?? this.email,
      password: password ?? this.password,
      points: points ?? this.points,
      attendance: attendance ?? this.attendance,
      attendanceDates: attendanceDates ?? this.attendanceDates,
      prayers: prayers ?? this.prayers,
      prayerDates: prayerDates ?? this.prayerDates,
      memorization: memorization ?? this.memorization,
      dailyPointsAdded: dailyPointsAdded ?? this.dailyPointsAdded,
      lastPointsDate: lastPointsDate ?? this.lastPointsDate,
    );
  }

  /// Helper method to convert prayers and prayerDates lists to a map
  Map<String, List<String>> getPrayerMap() {
    Map<String, List<String>> prayerMap = {};
    for (int i = 0; i < prayerDates.length; i++) {
      if (i < prayers.length) {
        prayerMap[prayerDates[i]] = prayers[i];
      }
    }
    return prayerMap;
  }

  /// Helper method to create a copy of the student with an updated prayer map
  Student copyWithPrayerMap(Map<String, List<String>> prayerMap) {
    return copyWith(
      prayerDates: prayerMap.keys.toList(),
      prayers: prayerMap.values.toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teacherId': teacherId,
    'phone': phone,
    'teacherName': teacherName,
    'teacherPhone': teacherPhone,
    'email': email,
    'password': password,
    'points': points,
    'attendance': attendance,
    'prayers': prayers,
    'prayerDates': prayerDates,
    'memorization': memorization,
    'attendanceDates': attendanceDates,
    'dailyPointsAdded': dailyPointsAdded,
    'lastPointsDate': lastPointsDate,
  };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
    id: json['id'] as String,
    name: json['name'] as String,
    teacherId: json['teacherId'] as String?,
    phone: (json['phone'] ?? '') as String,
    teacherName: json['teacherName'] as String,
    teacherPhone: json['teacherPhone'] as String,
    email: json['email'] as String,
    password: json['password'] as String,
    points: (json['points'] ?? 0) as int,
    attendance: (json['attendance'] as List? ?? [])
        .map((e) => e == true)
        .toList(),
    attendanceDates: (json['attendanceDates'] as List? ?? [])
        .map((e) => e as String)
        .toList(),
    prayers: (json['prayers'] as List? ?? [])
        .map((e) => (e as List).map((p) => p as String).toList())
        .toList(),
    prayerDates: (json['prayerDates'] as List? ?? [])
        .map((e) => e as String)
        .toList(),
    memorization: (json['memorization'] as List? ?? [])
        .map((e) => e as String)
        .toList(),
    dailyPointsAdded: (json['dailyPointsAdded'] ?? 0) as int,
    lastPointsDate: (json['lastPointsDate'] ?? '') as String,
  );
}
