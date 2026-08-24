import 'package:flutter/material.dart';

class SubjectLecture {
  final int number;
  final String title;
  final List<String> links;

  SubjectLecture({
    required this.number,
    this.title = '',
    this.links = const [],
  });

  SubjectLecture copyWith({String? title, List<String>? links}) =>
      SubjectLecture(
        number: number,
        title: title ?? this.title,
        links: links ?? this.links,
      );

  Map<String, dynamic> toJson() => {
    'number': number,
    'title': title,
    'links': links,
  };

  factory SubjectLecture.fromJson(Map<String, dynamic> json) => SubjectLecture(
    number: json['number'] as int,
    title: (json['title'] as String?) ?? '',
    links: (json['links'] as List?)?.cast<String>() ?? [],
  );
}

class Subject {
  final String id, name, code, academicYear, doctorName, color;
  final int totalLectures;
  final List<SubjectLecture> lectures;
  final String? pdfUrl;
  final int version;

  Subject({
    required this.id,
    required this.name,
    required this.code,
    required this.academicYear,
    this.doctorName = '',
    this.color = '#2196F3',
    this.totalLectures = 20,
    this.lectures = const [],
    this.pdfUrl,
    this.version = 1,
  });

  Subject copyWith({
    String? name,
    String? code,
    String? academicYear,
    String? doctorName,
    String? color,
    int? totalLectures,
    List<SubjectLecture>? lectures,
    String? pdfUrl,
    int? version,
  }) => Subject(
    id: id,
    name: name ?? this.name,
    code: code ?? this.code,
    academicYear: academicYear ?? this.academicYear,
    doctorName: doctorName ?? this.doctorName,
    color: color ?? this.color,
    totalLectures: totalLectures ?? this.totalLectures,
    lectures: lectures ?? this.lectures,
    pdfUrl: pdfUrl ?? this.pdfUrl,
    version: version ?? this.version,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'academicYear': academicYear,
    'doctorName': doctorName,
    'color': color,
    'totalLectures': totalLectures,
    'lectures': lectures.map((l) => l.toJson()).toList(),
    if (pdfUrl != null) 'pdfUrl': pdfUrl,
    'version': version,
  };

  factory Subject.fromJson(Map<String, dynamic> json) {
    final rawLectures = json['lectures'] as List? ?? [];
    final lectures = rawLectures
        .map((e) => SubjectLecture.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = (json['totalLectures'] as num?)?.toInt() ?? 20;
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      academicYear: json['academicYear'] as String,
      doctorName: (json['doctorName'] as String?) ?? '',
      color: (json['color'] as String?) ?? '#2196F3',
      totalLectures: total,
      lectures: lectures,
      pdfUrl: json['pdfUrl'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  static List<SubjectLecture> generateLectures(int count) => List.generate(
    count,
    (i) => SubjectLecture(number: i + 1, title: 'محاضرة ${i + 1}'),
  );
}

class StudentSubject {
  final String enrollmentId;
  final String subjectId, name, code, academicYear, doctorName, color;
  final List<String> scheduleDays, scheduleTimes;
  final String hall, nextLecture;
  final int totalLectures, grade;
  final List<int> viewedLectures;
  final bool isCustom;
  final int version;

  StudentSubject({
    String? enrollmentId,
    required this.subjectId,
    required this.name,
    required this.code,
    required this.academicYear,
    this.doctorName = '',
    this.color = '#2196F3',
    this.scheduleDays = const [],
    this.scheduleTimes = const [],
    this.hall = '',
    this.nextLecture = '',
    this.totalLectures = 20,
    this.grade = 0,
    this.viewedLectures = const [],
    this.isCustom = false,
    this.version = 1,
  }) : enrollmentId = enrollmentId ?? subjectId;

  int get attendedLectures => viewedLectures.length;
  double get progress =>
      totalLectures > 0 ? attendedLectures / totalLectures : 0;

  Map<String, dynamic> toJson() => {
    'subjectId': subjectId,
    'enrollmentId': enrollmentId,
    'name': name,
    'code': code,
    'academicYear': academicYear,
    'doctorName': doctorName,
    'color': color,
    'scheduleDays': scheduleDays,
    'scheduleTimes': scheduleTimes,
    'hall': hall,
    'nextLecture': nextLecture,
    'totalLectures': totalLectures,
    'attendedLectures': attendedLectures,
    'grade': grade,
    'viewedLectures': viewedLectures,
    'isCustom': isCustom,
    'version': version,
  };

  factory StudentSubject.fromJson(Map<String, dynamic> json) {
    final viewed = (json['viewedLectures'] as List?)?.cast<int>() ?? [];
    return StudentSubject(
      enrollmentId:
          (json['enrollmentId'] as String?) ?? (json['subjectId'] as String),
      subjectId: json['subjectId'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      academicYear: (json['academicYear'] as String?) ?? '',
      doctorName: (json['doctorName'] as String?) ?? '',
      color: (json['color'] as String?) ?? '#2196F3',
      scheduleDays: (json['scheduleDays'] as List?)?.cast<String>() ?? [],
      scheduleTimes: (json['scheduleTimes'] as List?)?.cast<String>() ?? [],
      hall: (json['hall'] as String?) ?? '',
      nextLecture: (json['nextLecture'] as String?) ?? '',
      totalLectures: (json['totalLectures'] as num?)?.toInt() ?? 20,
      grade: (json['grade'] as num?)?.round() ?? 0,
      viewedLectures: viewed,
      isCustom: (json['isCustom'] as bool?) ?? false,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  StudentSubject copyWith({
    int? grade,
    int? totalLectures,
    List<String>? scheduleDays,
    List<String>? scheduleTimes,
    String? hall,
    String? nextLecture,
    List<int>? viewedLectures,
    int? version,
  }) => StudentSubject(
    enrollmentId: enrollmentId,
    subjectId: subjectId,
    name: name,
    code: code,
    academicYear: academicYear,
    doctorName: doctorName,
    color: color,
    scheduleDays: scheduleDays ?? this.scheduleDays,
    scheduleTimes: scheduleTimes ?? this.scheduleTimes,
    hall: hall ?? this.hall,
    nextLecture: nextLecture ?? this.nextLecture,
    totalLectures: totalLectures ?? this.totalLectures,
    grade: grade ?? this.grade,
    viewedLectures: viewedLectures ?? this.viewedLectures,
    isCustom: isCustom,
    version: version ?? this.version,
  );
}

Color parseColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}
