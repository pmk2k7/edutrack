import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

typedef Row = Map<String, Object?>;

class DB {
  static Database? _db;
  static Future<Database> get db async => _db ??= await _open();

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'edutrack.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, v) async {
        await d.execute('CREATE TABLE classes(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, section TEXT, created_at TEXT)');
        await d.execute('CREATE TABLE students(id INTEGER PRIMARY KEY AUTOINCREMENT, class_id INTEGER NOT NULL REFERENCES classes(id) ON DELETE CASCADE, roll_no TEXT, name TEXT NOT NULL, phone TEXT, created_at TEXT)');
        await d.execute('CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, class_id INTEGER NOT NULL REFERENCES classes(id) ON DELETE CASCADE, title TEXT NOT NULL, category TEXT, subject TEXT, due_date TEXT, created_at TEXT)');
        await d.execute('CREATE TABLE task_submissions(id INTEGER PRIMARY KEY AUTOINCREMENT, task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE, student_id INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE, status TEXT NOT NULL DEFAULT \'pending\', updated_at TEXT, UNIQUE(task_id, student_id))');
      },
    );
  }

  static String _now() => DateTime.now().toIso8601String();

  // ---- Classes ----
  static Future<List<Row>> classes() async => (await db).rawQuery(
      'SELECT c.*, (SELECT COUNT(*) FROM students s WHERE s.class_id=c.id) AS cnt FROM classes c ORDER BY c.id DESC');

  static Future<void> addClass(String name, String section) async =>
      (await db).insert('classes', {'name': name, 'section': section, 'created_at': _now()});

  static Future<void> deleteClass(int id) async =>
      (await db).delete('classes', where: 'id=?', whereArgs: [id]);

  // ---- Students ----
  static Future<List<Row>> students(int classId) async => (await db).rawQuery(
      'SELECT * FROM students WHERE class_id=? ORDER BY CAST(roll_no AS INTEGER), name', [classId]);

  static Future<void> addStudent(int classId, String roll, String name, [String phone = '']) async {
    final d = await db;
    await d.transaction((t) async {
      final sid = await t.insert('students',
          {'class_id': classId, 'roll_no': roll, 'name': name, 'phone': phone, 'created_at': _now()});
      final tasks = await t.query('tasks', columns: ['id'], where: 'class_id=?', whereArgs: [classId]);
      for (final k in tasks) {
        await t.insert('task_submissions',
            {'task_id': k['id'], 'student_id': sid, 'status': 'pending', 'updated_at': _now()});
      }
    });
  }

  /// Each line: "roll,name" or "roll<TAB>name" or just "name".
  static Future<int> importStudents(int classId, String text) async {
    var n = 0;
    final existing = (await students(classId)).length;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final parts = line.split(RegExp(r'[,\t]'));
      String roll, name;
      if (parts.length >= 2) {
        roll = parts[0].trim();
        name = parts.sublist(1).join(' ').trim();
      } else {
        roll = '${existing + n + 1}';
        name = line;
      }
      if (name.isEmpty) continue;
      await addStudent(classId, roll, name);
      n++;
    }
    return n;
  }

  static Future<void> deleteStudent(int id) async =>
      (await db).delete('students', where: 'id=?', whereArgs: [id]);

  // ---- Tasks ----
  static Future<List<Row>> tasks(int classId) async => (await db).rawQuery(
      'SELECT t.*, '
      '(SELECT COUNT(*) FROM task_submissions x WHERE x.task_id=t.id) AS total, '
      '(SELECT COUNT(*) FROM task_submissions x WHERE x.task_id=t.id AND x.status=\'completed\') AS done '
      'FROM tasks t WHERE t.class_id=? ORDER BY t.id DESC',
      [classId]);

  static Future<void> addTask(int classId, String title, String category, String subject, String due) async {
    final d = await db;
    await d.transaction((t) async {
      final tid = await t.insert('tasks', {
        'class_id': classId, 'title': title, 'category': category,
        'subject': subject, 'due_date': due, 'created_at': _now()
      });
      final studs = await t.query('students', columns: ['id'], where: 'class_id=?', whereArgs: [classId]);
      for (final s in studs) {
        await t.insert('task_submissions',
            {'task_id': tid, 'student_id': s['id'], 'status': 'pending', 'updated_at': _now()});
      }
    });
  }

  static Future<void> deleteTask(int id) async =>
      (await db).delete('tasks', where: 'id=?', whereArgs: [id]);

  // ---- Submissions ----
  static Future<List<Row>> subs(int taskId) async => (await db).rawQuery(
      'SELECT x.id, x.status, s.name, s.roll_no FROM task_submissions x '
      'JOIN students s ON s.id=x.student_id WHERE x.task_id=? '
      'ORDER BY CAST(s.roll_no AS INTEGER), s.name',
      [taskId]);

  static Future<void> setStatus(int subId, String status) async => (await db).update(
      'task_submissions', {'status': status, 'updated_at': _now()},
      where: 'id=?', whereArgs: [subId]);

  static Future<void> markAll(int taskId, String status) async => (await db).update(
      'task_submissions', {'status': status, 'updated_at': _now()},
      where: 'task_id=?', whereArgs: [taskId]);
}
