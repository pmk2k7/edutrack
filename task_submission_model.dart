class TaskSubmissionModel {
  final int? id;
  final int taskId;
  final int studentId;
  final String studentName;
  final String rollNo;
  final String status; // 'completed' or 'pending'
  final String? updatedAt;

  TaskSubmissionModel({
    this.id,
    required this.taskId,
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    required this.status,
    this.updatedAt,
  });

  bool get isCompleted => status == 'completed';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'student_id': studentId,
      'status': status,
      'updated_at': updatedAt,
    };
  }

  factory TaskSubmissionModel.fromMap(Map<String, dynamic> map) {
    return TaskSubmissionModel(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      studentId: map['student_id'] as int,
      studentName: (map['student_name'] ?? '') as String,
      rollNo: (map['roll_no'] ?? '') as String,
      status: (map['status'] ?? 'pending') as String,
      updatedAt: map['updated_at'] as String?,
    );
  }
}
