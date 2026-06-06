class Teacher {
  final String? id;
  final String name;
  final String number;
  final String email;
  final String password;

  Teacher({this.id, required this.name, required this.number, required this.email, required this.password});

  Map<String, dynamic> toJson() => {
    'id': id ?? 'teacher_${DateTime.now().millisecondsSinceEpoch}',
    'name': name,
    'number': number,
    'email': email,
    'password': password
  };

  factory Teacher.fromJson(Map<String, dynamic> json) =>
      Teacher(
        id: json['id'] as String?,
        name: json['name'] as String,
        number: json['number'] as String,
        email: json['email'] as String,
        password: json['password'] as String
      );

  Teacher copyWith({String? id, String? name, String? number, String? email, String? password}) =>
      Teacher(
        id: id ?? this.id,
        name: name ?? this.name,
        number: number ?? this.number,
        email: email ?? this.email,
        password: password ?? this.password
      );
}
