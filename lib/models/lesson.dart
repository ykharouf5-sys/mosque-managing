class Lesson {
  final String id;
  final String title;
  final String description;
  final String link; // URL to video, PDF, or text content
  final String? thumbnailUrl;
  final String? uploaderId; // Admin ID who uploaded it (optional tracking)
  final DateTime createdAt;

  Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.link,
    this.thumbnailUrl,
    this.uploaderId,
    required this.createdAt,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      link: json['link'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      uploaderId: json['uploader_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'link': link,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (uploaderId != null) 'uploader_id': uploaderId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
