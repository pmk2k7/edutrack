import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/task_model.dart';
import '../models/task_submission_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('edutrack_pro.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Enable FFI on Windows and Linux desktops
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS custom_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS custom_subjects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Classes Table
    await db.execute('''
      CREATE TABLE classes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        section TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Students Table
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL,
        roll_no TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
      )
    ''');

    // Tasks / Activities Table
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        subject TEXT NOT NULL,
        due_date TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
      )
    ''');

    // Task Submissions (Status Tracking) Table
    await db.execute('''
      CREATE TABLE task_submissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        updated_at TEXT,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        UNIQUE(task_id, student_id)
      )
    ''');
  }

  // ==================== CLASS CRUD ====================

  Future<int> insertClass(ClassModel classModel) async {
    final db = await database;
    return await db.insert('classes', classModel.toMap());
  }

  Future<List<ClassModel>> getAllClasses() async {
    final db = await database;
    final result = await db.query('classes', orderBy: 'name ASC, section ASC');
    return result.map((e) => ClassModel.fromMap(e)).toList();
  }

  Future<int> deleteClass(int classId) async {
    final db = await database;
    return await db.delete('classes', where: 'id = ?', whereArgs: [classId]);
  }

  Future<int> getStudentCountForClass(int classId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM students WHERE class_id = ?',
      [classId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== STUDENT CRUD ====================

  Future<int> insertStudent(StudentModel student) async {
    final db = await database;
    final studentId = await db.insert('students', student.toMap());

    // When a student is added, automatically create pending submissions for all existing tasks of this class
    final tasks = await db.query(
      'tasks',
      columns: ['id'],
      where: 'class_id = ?',
      whereArgs: [student.classId],
    );

    for (final task in tasks) {
      await db.insert('task_submissions', {
        'task_id': task['id'],
        'student_id': studentId,
        'status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    return studentId;
  }

  Future<int> bulkInsertStudents(int classId, List<Map<String, String>> studentsList) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (final item in studentsList) {
      batch.insert('students', {
        'class_id': classId,
        'roll_no': item['roll_no'] ?? '',
        'name': item['name'] ?? '',
        'phone': item['phone'] ?? '',
        'created_at': now,
      });
    }

    await batch.commit(noResult: true);

    // Sync submissions for any existing tasks in this class
    final students = await db.query('students', columns: ['id'], where: 'class_id = ?', whereArgs: [classId]);
    final tasks = await db.query('tasks', columns: ['id'], where: 'class_id = ?', whereArgs: [classId]);

    final submissionBatch = db.batch();
    for (final task in tasks) {
      final taskId = task['id'];
      for (final student in students) {
        final studentId = student['id'];
        submissionBatch.rawInsert('''
          INSERT OR IGNORE INTO task_submissions (task_id, student_id, status, updated_at)
          VALUES (?, ?, 'pending', ?)
        ''', [taskId, studentId, now]);
      }
    }
    await submissionBatch.commit(noResult: true);

    return studentsList.length;
  }

  Future<List<StudentModel>> getStudentsByClass(int classId) async {
    final db = await database;
    final result = await db.query(
      'students',
      where: 'class_id = ?',
      whereArgs: [classId],
      orderBy: 'CAST(roll_no AS INTEGER) ASC, roll_no ASC, name ASC',
    );
    return result.map((e) => StudentModel.fromMap(e)).toList();
  }

  Future<int> deleteStudent(int studentId) async {
    final db = await database;
    return await db.delete('students', where: 'id = ?', whereArgs: [studentId]);
  }

  // ==================== TASK / ACTIVITY CRUD ====================

  Future<int> insertTask(TaskModel task) async {
    final db = await database;
    final taskId = await db.insert('tasks', task.toMap());

    // Automatically create 'pending' submissions for all existing students in this class
    final students = await db.query(
      'students',
      columns: ['id'],
      where: 'class_id = ?',
      whereArgs: [task.classId],
    );

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final student in students) {
      batch.insert('task_submissions', {
        'task_id': taskId,
        'student_id': student['id'],
        'status': 'pending',
        'updated_at': now,
      });
    }
    await batch.commit(noResult: true);

    return taskId;
  }

  Future<List<TaskModel>> getTasksByClass(int classId) async {
    final db = await database;
    final tasksResult = await db.query(
      'tasks',
      where: 'class_id = ?',
      whereArgs: [classId],
      orderBy: 'id DESC',
    );

    List<TaskModel> tasks = [];
    for (final map in tasksResult) {
      final task = TaskModel.fromMap(map);
      // Compute status counts
      final stats = await getTaskStats(task.id!);
      task.totalStudents = stats['total'] ?? 0;
      task.completedCount = stats['completed'] ?? 0;
      task.pendingCount = stats['pending'] ?? 0;
      tasks.add(task);
    }

    return tasks;
  }

  Future<int> deleteTask(int taskId) async {
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
  }

  // ==================== SUBMISSION / STATUS TRACKING ====================

  Future<Map<String, int>> getTaskStats(int taskId) async {
    final db = await database;
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM task_submissions WHERE task_id = ?',
      [taskId],
    );
    final completedResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM task_submissions WHERE task_id = ? AND status = 'completed'",
      [taskId],
    );

    final total = Sqflite.firstIntValue(totalResult) ?? 0;
    final completed = Sqflite.firstIntValue(completedResult) ?? 0;
    final pending = total - completed;

    return {
      'total': total,
      'completed': completed,
      'pending': pending,
    };
  }

  Future<List<TaskSubmissionModel>> getSubmissionsForTask(int taskId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT ts.id, ts.task_id, ts.student_id, ts.status, ts.updated_at,
             s.name as student_name, s.roll_no as roll_no
      FROM task_submissions ts
      JOIN students s ON ts.student_id = s.id
      WHERE ts.task_id = ?
      ORDER BY CAST(s.roll_no AS INTEGER) ASC, s.roll_no ASC, s.name ASC
    ''', [taskId]);

    return result.map((e) => TaskSubmissionModel.fromMap(e)).toList();
  }

  Future<void> toggleSubmissionStatus(int taskId, int studentId, String currentStatus) async {
    final db = await database;
    final newStatus = currentStatus == 'completed' ? 'pending' : 'completed';
    await db.update(
      'task_submissions',
      {
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'task_id = ? AND student_id = ?',
      whereArgs: [taskId, studentId],
    );
  }

  Future<void> setSubmissionStatus(int taskId, int studentId, String newStatus) async {
    final db = await database;
    await db.update(
      'task_submissions',
      {
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'task_id = ? AND student_id = ?',
      whereArgs: [taskId, studentId],
    );
  }

  Future<void> markAllSubmissions(int taskId, String status) async {
    final db = await database;
    await db.update(
      'task_submissions',
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }

  // ==================== CUSTOM CATEGORIES & SUBJECTS ====================

  Future<List<String>> getCustomCategories() async {
    final db = await database;
    final result = await db.query('custom_categories', orderBy: 'id ASC');
    return result.map((e) => e['name'] as String).toList();
  }

  Future<void> insertCustomCategory(String name) async {
    final db = await database;
    await db.insert(
      'custom_categories',
      {'name': name.trim()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<String>> getCustomSubjects() async {
    final db = await database;
    final result = await db.query('custom_subjects', orderBy: 'id ASC');
    return result.map((e) => e['name'] as String).toList();
  }

  Future<void> insertCustomSubject(String name) async {
    final db = await database;
    await db.insert(
      'custom_subjects',
      {'name': name.trim()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
