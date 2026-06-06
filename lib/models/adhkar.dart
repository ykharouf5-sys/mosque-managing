class AdhkarCategory {
  final String id;
  final String title;
  final String description;
  final String? iconUrl; // Optional for future UI enhancements
  final DateTime createdAt;

  AdhkarCategory({
    required this.id,
    required this.title,
    required this.description,
    this.iconUrl,
    required this.createdAt,
  });

  factory AdhkarCategory.fromJson(Map<String, dynamic> json) {
    return AdhkarCategory(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] ?? '',
      iconUrl: json['iconUrl'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      if (iconUrl != null) 'iconUrl': iconUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Dhikr {
  final String id;
  final String categoryId;
  final String text;
  final String? source; // e.g., Bukhari, Muslim
  final int count; // Number of times to repeat
  final String? virtue; // فضل الذكر
  final DateTime createdAt;

  Dhikr({
    required this.id,
    required this.categoryId,
    required this.text,
    this.source,
    this.count = 1,
    this.virtue,
    required this.createdAt,
  });

  factory Dhikr.fromJson(Map<String, dynamic> json) {
    return Dhikr(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      text: json['text'] as String,
      source: json['source'] as String?,
      count: json['count'] as int? ?? 1,
      virtue: json['virtue'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'text': text,
      if (source != null) 'source': source,
      'count': count,
      if (virtue != null) 'virtue': virtue,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
