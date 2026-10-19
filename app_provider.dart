import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/task_model.dart';
import '../models/task_submission_model.dart';

class AppProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<ClassModel> _classes = [];
  Map<int, int> _classStudentCounts = {};
  
  List<StudentModel> _students = [];
  List<TaskModel> _tasks = [];
  List<TaskSubmissionModel> _submissions = [];

  bool _isLoading = false;
  int? _selectedClassId;
  int? _selectedTaskId;

  List<ClassModel> get classes => _classes;
  Map<int, int> get classStudentCounts => _classStudentCounts;
  List<StudentModel> get students => _students;
  List<TaskModel> get tasks => _tasks;
  List<TaskSubmissionModel> get submissions => _submissions;
  bool get isLoading => _isLoading;
  int? get selectedClassId => _selectedClassId;
  int? get selectedTaskId => _selectedTaskId;
  DatabaseHelper get databaseHelper => _dbHelper;

  // Filtered submission lists
  List<TaskSubmissionModel> get completedSubmissions =>
      _submissions.where((s) => s.isCompleted).toList();

  List<TaskSubmissionModel> get pendingSubmissions =>
      _submissions.where((s) => !s.isCompleted).toList();

  final List<String> _categories = [
    'வீட்டுப்பாடம் (Homework)',
    'அசைன்மென்ட் (Assignment)',
    'பிராஜெக்ட் (Project)',
    'ரிக்கார்டு (Record Note)',
    'தேர்வு (Exam / Test)',
  ];

  final List<String> _subjects = [
    'தமிழ்',
    'ஆங்கிலம்',
    'கணிதம்',
    'அறிவியல்',
    'சமூக அறிவியல்',
  ];

  List<String> get categories => _categories;
  List<String> get subjects => _subjects;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await loadClasses();
    await loadCustomCategoriesAndSubjects();

    // If no classes exist yet, insert helpful starter data
    if (_classes.isEmpty) {
      await _insertDemoData();
      await loadClasses();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCustomCategoriesAndSubjects() async {
    final customCats = await _dbHelper.getCustomCategories();
    for (final cat in customCats) {
      if (!_categories.contains(cat)) {
        _categories.add(cat);
      }
    }

    final customSubs = await _dbHelper.getCustomSubjects();
    for (final sub in customSubs) {
      if (!_subjects.contains(sub)) {
        _subjects.add(sub);
      }
    }
    notifyListeners();
  }

  Future<void> addCustomCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _dbHelper.insertCustomCategory(trimmed);
    if (!_categories.contains(trimmed)) {
      _categories.add(trimmed);
      notifyListeners();
    }
  }

  Future<void> addCustomSubject(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _dbHelper.insertCustomSubject(trimmed);
    if (!_subjects.contains(trimmed)) {
      _subjects.add(trimmed);
      notifyListeners();
    }
  }

  // ==================== CLASSES ====================

  Future<void> loadClasses() async {
    _classes = await _dbHelper.getAllClasses();
    _classStudentCounts = {};
    for (final c in _classes) {
      if (c.id != null) {
        _classStudentCounts[c.id!] = await _dbHelper.getStudentCountForClass(c.id!);
      }
    }
    notifyListeners();
  }

  Future<void> addClass(String name, String section) async {
    final newClass = ClassModel(
      name: name.trim(),
      section: section.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    await _dbHelper.insertClass(newClass);
    await loadClasses();
  }

  Future<void> deleteClass(int classId) async {
    await _dbHelper.deleteClass(classId);
    if (_selectedClassId == classId) {
      _selectedClassId = null;
      _students = [];
      _tasks = [];
    }
    await loadClasses();
  }

  // ==================== CLASS DASHBOARD (STUDENTS & TASKS) ====================

  Future<void> selectClass(int classId) async {
    _selectedClassId = classId;
    _isLoading = true;
    notifyListeners();

    await Future.wait([
      loadStudents(classId),
      loadTasks(classId),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadStudents(int classId) async {
    _students = await _dbHelper.getStudentsByClass(classId);
    _classStudentCounts[classId] = _students.length;
    notifyListeners();
  }

  Future<void> addStudent(int classId, String rollNo, String name, String? phone) async {
    final student = StudentModel(
      classId: classId,
      rollNo: rollNo.trim(),
      name: name.trim(),
      phone: phone?.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    await _dbHelper.insertStudent(student);
    await loadStudents(classId);
    await loadTasks(classId); // tasks need updated student counts
  }

  Future<void> bulkAddStudents(int classId, List<Map<String, String>> list) async {
    await _dbHelper.bulkInsertStudents(classId, list);
    await loadStudents(classId);
    await loadTasks(classId);
  }

  Future<void> deleteStudent(int studentId, int classId) async {
    await _dbHelper.deleteStudent(studentId);
    await loadStudents(classId);
    await loadTasks(classId);
  }

  // ==================== TASKS / ACTIVITIES ====================

  Future<void> loadTasks(int classId) async {
    _tasks = await _dbHelper.getTasksByClass(classId);
    notifyListeners();
  }

  Future<void> addTask({
    required int classId,
    required String title,
    required String category,
    required String subject,
    required String dueDate,
    String? description,
  }) async {
    final task = TaskModel(
      classId: classId,
      title: title.trim(),
      category: category,
      subject: subject.trim(),
      dueDate: dueDate,
      description: description?.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    await _dbHelper.insertTask(task);
    await loadTasks(classId);
  }

  Future<void> deleteTask(int taskId, int classId) async {
    await _dbHelper.deleteTask(taskId);
    if (_selectedTaskId == taskId) {
      _selectedTaskId = null;
      _submissions = [];
    }
    await loadTasks(classId);
  }

  // ==================== TASK TRACKER & QUICK STATUS TOGGLE ====================

  Future<void> loadTaskSubmissions(int taskId) async {
    _selectedTaskId = taskId;
    _submissions = await _dbHelper.getSubmissionsForTask(taskId);
    notifyListeners();
  }

  Future<void> toggleSubmissionStatus(int taskId, int studentId, String currentStatus) async {
    await _dbHelper.toggleSubmissionStatus(taskId, studentId, currentStatus);
    
    // Quick local state update for instant UI feedback
    final index = _submissions.indexWhere((s) => s.studentId == studentId);
    if (index != -1) {
      final old = _submissions[index];
      final newStatus = currentStatus == 'completed' ? 'pending' : 'completed';
      _submissions[index] = TaskSubmissionModel(
        id: old.id,
        taskId: old.taskId,
        studentId: old.studentId,
        studentName: old.studentName,
        rollNo: old.rollNo,
        status: newStatus,
        updatedAt: DateTime.now().toIso8601String(),
      );
    }
    
    notifyListeners();

    // Also refresh class tasks list in background so overview dashboard counters are updated
    if (_selectedClassId != null) {
      _tasks = await _dbHelper.getTasksByClass(_selectedClassId!);
      notifyListeners();
    }
  }

  Future<void> markAllSubmissions(int taskId, String status) async {
    await _dbHelper.markAllSubmissions(taskId, status);
    await loadTaskSubmissions(taskId);
    if (_selectedClassId != null) {
      await loadTasks(_selectedClassId!);
    }
  }

  // ==================== STARTER DEMO DATA ====================

  Future<void> _insertDemoData() async {
    final now = DateTime.now().toIso8601String();
    
    // 1. Create Class: 10-ஆம் வகுப்பு - A பிரிவு
    final class10A = ClassModel(name: '10-ஆம் வகுப்பு', section: 'A', createdAt: now);
    final classId = await _dbHelper.insertClass(class10A);

    // 2. Add sample students
    final sampleStudents = [
      {'roll_no': '1', 'name': 'கவின் குமார்', 'phone': '9876543210'},
      {'roll_no': '2', 'name': 'வர்ஷினி பிரியா', 'phone': '9876543211'},
      {'roll_no': '3', 'name': 'முகமது ஆசிப்', 'phone': '9876543212'},
      {'roll_no': '4', 'name': 'கார்த்திக் ராஜா', 'phone': '9876543213'},
      {'roll_no': '5', 'name': 'அனன்யா ஸ்ரீ', 'phone': '9876543214'},
      {'roll_no': '6', 'name': 'தினேஷ் பிரபு', 'phone': '9876543215'},
    ];
    await _dbHelper.bulkInsertStudents(classId, sampleStudents);

    // 3. Create Sample Tasks
    final task1 = TaskModel(
      classId: classId,
      title: 'இயற்கணிதம் பயிற்சி 3.1 & 3.2',
      category: 'வீட்டுப்பாடம் (Homework)',
      subject: 'கணிதம்',
      dueDate: DateTime.now().add(const Duration(days: 1)).toString().split(' ')[0],
      createdAt: now,
    );
    final taskId1 = await _dbHelper.insertTask(task1);

    // Mark 3 students as completed to show instant visual contrast
    final studentsInDb = await _dbHelper.getStudentsByClass(classId);
    if (studentsInDb.length >= 3) {
      await _dbHelper.setSubmissionStatus(taskId1, studentsInDb[0].id!, 'completed');
      await _dbHelper.setSubmissionStatus(taskId1, studentsInDb[1].id!, 'completed');
      await _dbHelper.setSubmissionStatus(taskId1, studentsInDb[2].id!, 'completed');
    }

    final task2 = TaskModel(
      classId: classId,
      title: 'ஒளிச்சேர்க்கை அறிவியல் வரைபடம்',
      category: 'அசைன்மென்ட் (Assignment)',
      subject: 'அறிவியல்',
      dueDate: DateTime.now().add(const Duration(days: 3)).toString().split(' ')[0],
      createdAt: now,
    );
    final taskId2 = await _dbHelper.insertTask(task2);
    if (studentsInDb.isNotEmpty) {
      await _dbHelper.setSubmissionStatus(taskId2, studentsInDb[0].id!, 'completed');
    }

    // 4. Create another Class: 12-ஆம் வகுப்பு - B பிரிவு
    final class12B = ClassModel(name: '12-ஆம் வகுப்பு', section: 'B', createdAt: now);
    await _dbHelper.insertClass(class12B);
  }
}
