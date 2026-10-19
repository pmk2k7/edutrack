class ClassModel {
  final int? id;
  final String name;
  final String section;
  final String createdAt;

  ClassModel({
    this.id,
    required this.name,
    required this.section,
    required this.createdAt,
  });

  String get displayName => '$name - $section பிரிவு';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'section': section,
      'created_at': createdAt,
    };
  }

  factory ClassModel.fromMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      section: map['section'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
