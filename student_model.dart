class StudentModel {
  final int? id;
  final int classId;
  final String rollNo;
  final String name;
  final String? phone;
  final String createdAt;

  StudentModel({
    this.id,
    required this.classId,
    required this.rollNo,
    required this.name,
    this.phone,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class_id': classId,
      'roll_no': rollNo,
      'name': name,
      'phone': phone,
      'created_at': createdAt,
    };
  }

  factory StudentModel.fromMap(Map<String, dynamic> map) {
    return StudentModel(
      id: map['id'] as int?,
      classId: map['class_id'] as int,
      rollNo: map['roll_no'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
