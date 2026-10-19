class TaskModel {
  final int? id;
  final int classId;
  final String title;
  final String category;
  final String subject;
  final String dueDate;
  final String? description;
  final String createdAt;

  // Runtime computed counts for dashboard
  int totalStudents;
  int completedCount;
  int pendingCount;

  TaskModel({
    this.id,
    required this.classId,
    required this.title,
    required this.category,
    required this.subject,
    required this.dueDate,
    this.description,
    required this.createdAt,
    this.totalStudents = 0,
    this.completedCount = 0,
    this.pendingCount = 0,
  });

  double get completionPercentage {
    if (totalStudents == 0) return 0.0;
    return (completedCount / totalStudents).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class_id': classId,
      'title': title,
      'category': category,
      'subject': subject,
      'due_date': dueDate,
      'description': description,
      'created_at': createdAt,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as int?,
      classId: map['class_id'] as int,
      title: map['title'] as String,
      category: map['category'] as String,
      subject: map['subject'] as String,
      dueDate: map['due_date'] as String,
      description: map['description'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
