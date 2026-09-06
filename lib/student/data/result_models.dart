class ResultUpload {
  final String id;
  final String fileName;
  final String? storagePath;
  final String? downloadUrl;
  final String status; // upload-ready, processing, completed, failed
  final int totalRecords;
  final int importedRecords;
  final int failedRecords;
  final int matchedRecords;
  final int unmatchedRecords;
  final List<String> warnings;
  final String? errorMessage;
  final DateTime uploadDate;
  final DateTime? processedDate;
  final String uploadedBy;
  final String? examSession;
  final String? academicYear;
  final String? university;

  ResultUpload({
    required this.id,
    required this.fileName,
    this.storagePath,
    this.downloadUrl,
    this.status = 'upload-ready',
    this.totalRecords = 0,
    this.importedRecords = 0,
    this.failedRecords = 0,
    this.matchedRecords = 0,
    this.unmatchedRecords = 0,
    this.warnings = const [],
    this.errorMessage,
    required this.uploadDate,
    this.processedDate,
    required this.uploadedBy,
    this.examSession,
    this.academicYear,
    this.university,
  });

  ResultUpload copyWith({
    String? status,
    int? totalRecords,
    int? importedRecords,
    int? failedRecords,
    int? matchedRecords,
    int? unmatchedRecords,
    List<String>? warnings,
    String? errorMessage,
    DateTime? processedDate,
    String? downloadUrl,
    String? storagePath,
    String? university,
  }) => ResultUpload(
    id: id,
    fileName: fileName,
    storagePath: storagePath ?? this.storagePath,
    downloadUrl: downloadUrl ?? this.downloadUrl,
    status: status ?? this.status,
    totalRecords: totalRecords ?? this.totalRecords,
    importedRecords: importedRecords ?? this.importedRecords,
    failedRecords: failedRecords ?? this.failedRecords,
    matchedRecords: matchedRecords ?? this.matchedRecords,
    unmatchedRecords: unmatchedRecords ?? this.unmatchedRecords,
    warnings: warnings ?? this.warnings,
    errorMessage: errorMessage ?? this.errorMessage,
    uploadDate: uploadDate,
    processedDate: processedDate ?? this.processedDate,
    uploadedBy: uploadedBy,
    examSession: examSession,
    academicYear: academicYear,
    university: university ?? this.university,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    if (storagePath != null) 'storagePath': storagePath,
    if (downloadUrl != null) 'downloadUrl': downloadUrl,
    'status': status,
    'totalRecords': totalRecords,
    'importedRecords': importedRecords,
    'failedRecords': failedRecords,
    'matchedRecords': matchedRecords,
    'unmatchedRecords': unmatchedRecords,
    'warnings': warnings,
    'errorMessage': errorMessage,
    'uploadDate': uploadDate.toIso8601String(),
    'processedDate': processedDate?.toIso8601String(),
    'uploadedBy': uploadedBy,
    'examSession': examSession,
    'academicYear': academicYear,
    'university': university,
  };

  factory ResultUpload.fromJson(Map<String, dynamic> json) => ResultUpload(
    id: json['id'] as String,
    fileName: json['fileName'] as String,
    storagePath: json['storagePath'] as String?,
    downloadUrl: json['downloadUrl'] as String?,
    status: (json['status'] as String?) ?? 'upload-ready',
    totalRecords: (json['totalRecords'] as num?)?.toInt() ?? 0,
    importedRecords: (json['importedRecords'] as num?)?.toInt() ?? 0,
    failedRecords: (json['failedRecords'] as num?)?.toInt() ?? 0,
    matchedRecords: (json['matchedRecords'] as num?)?.toInt() ?? 0,
    unmatchedRecords: (json['unmatchedRecords'] as num?)?.toInt() ?? 0,
    warnings: (json['warnings'] as List?)?.cast<String>() ?? [],
    errorMessage: json['errorMessage'] as String?,
    uploadDate: DateTime.parse(json['uploadDate'] as String),
    processedDate: json['processedDate'] != null
        ? DateTime.parse(json['processedDate'] as String)
        : null,
    uploadedBy: json['uploadedBy'] as String,
    examSession: json['examSession'] as String?,
    academicYear: json['academicYear'] as String?,
    university: json['university'] as String?,
  );
}

class ResultRecord {
  final String id;
  final String examNumber;
  final String studentName;
  final String? fatherName;
  final String subjectName;
  final String? subjectCode;
  final double? theoreticalMark;
  final double? practicalMark;
  final double mark;
  final double total;
  final String? status; // 'ناجح', 'راسب', 'حجب', or null
  final String? examSession;
  final String? academicYear;
  final DateTime uploadDate;
  final String sourcePdfId;
  final String? notes;
  final bool matched;

  ResultRecord({
    required this.id,
    required this.examNumber,
    this.studentName = '',
    this.fatherName,
    required this.subjectName,
    this.subjectCode,
    this.theoreticalMark,
    this.practicalMark,
    required this.mark,
    this.total = 100,
    this.status,
    this.examSession,
    this.academicYear,
    required this.uploadDate,
    required this.sourcePdfId,
    this.notes,
    this.matched = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'examNumber': examNumber,
    'studentName': studentName,
    'fatherName': fatherName,
    'subjectName': subjectName,
    'subjectCode': subjectCode,
    'theoreticalMark': theoreticalMark,
    'practicalMark': practicalMark,
    'mark': mark,
    'total': total,
    'status': status,
    'examSession': examSession,
    'academicYear': academicYear,
    'uploadDate': uploadDate.toIso8601String(),
    'sourcePdfId': sourcePdfId,
    'notes': notes,
    'matched': matched,
  };

  factory ResultRecord.fromJson(Map<String, dynamic> json) => ResultRecord(
    id: json['id'] as String,
    examNumber: json['examNumber'] as String,
    studentName: (json['studentName'] as String?) ?? '',
    fatherName: json['fatherName'] as String?,
    subjectName: json['subjectName'] as String,
    subjectCode: json['subjectCode'] as String?,
    theoreticalMark: (json['theoreticalMark'] as num?)?.toDouble(),
    practicalMark: (json['practicalMark'] as num?)?.toDouble(),
    mark: (json['mark'] as num).toDouble(),
    total: (json['total'] as num?)?.toDouble() ?? 100,
    status: json['status'] as String?,
    examSession: json['examSession'] as String?,
    academicYear: json['academicYear'] as String?,
    uploadDate: DateTime.parse(json['uploadDate'] as String),
    sourcePdfId: json['sourcePdfId'] as String,
    notes: json['notes'] as String?,
    matched: json['matched'] as bool? ?? true,
  );

  String get percentage {
    if (total <= 0) return '0.0';
    return ((mark / total) * 100).toStringAsFixed(1);
  }

  String get statusLabel {
    switch (status) {
      case 'passed':
        return 'ناجح';
      case 'failed':
        return 'راسب';
      case 'withheld':
        return 'حجب';
      default:
        return status ?? '—';
    }
  }
}

class ImportValidationIssue {
  final String
  type; // duplicate_exam, malformed_row, missing_mark, missing_name
  final String? examNumber;
  final String? studentName;
  final String? subjectName;
  final String? message;
  final int? rowIndex;

  ImportValidationIssue({
    required this.type,
    this.examNumber,
    this.studentName,
    this.subjectName,
    this.message,
    this.rowIndex,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'examNumber': examNumber,
    'studentName': studentName,
    'subjectName': subjectName,
    'message': message,
    'rowIndex': rowIndex,
  };

  factory ImportValidationIssue.fromJson(Map<String, dynamic> json) =>
      ImportValidationIssue(
        type: json['type'] as String,
        examNumber: json['examNumber'] as String?,
        studentName: json['studentName'] as String?,
        subjectName: json['subjectName'] as String?,
        message: json['message'] as String?,
        rowIndex: json['rowIndex'] as int?,
      );
}

class ResultImportLog {
  final String id;
  final String uploadId;
  final String level; // info, warning, error
  final String message;
  final String? details;
  final DateTime timestamp;

  ResultImportLog({
    required this.id,
    required this.uploadId,
    required this.level,
    required this.message,
    this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'uploadId': uploadId,
    'level': level,
    'message': message,
    'details': details,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ResultImportLog.fromJson(Map<String, dynamic> json) =>
      ResultImportLog(
        id: json['id'] as String,
        uploadId: json['uploadId'] as String,
        level: json['level'] as String,
        message: json['message'] as String,
        details: json['details'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

String statusLabel(String status) {
  switch (status) {
    case 'upload-ready':
      return 'في الانتظار';
    case 'processing':
      return 'قيد المعالجة';
    case 'completed':
      return 'مكتمل';
    case 'failed':
      return 'فشل';
    default:
      return status;
  }
}

String statusIcon(String status) {
  switch (status) {
    case 'upload-ready':
      return 'pending';
    case 'processing':
      return 'processing';
    case 'completed':
      return 'completed';
    case 'failed':
      return 'failed';
    default:
      return 'unknown';
  }
}
