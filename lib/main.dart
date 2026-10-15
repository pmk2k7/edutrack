import 'package:flutter/material.dart';
import 'db.dart';

void main() => runApp(const EduTrackApp());

class EduTrackApp extends StatelessWidget {
  const EduTrackApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'EduTrack Pro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const ClassesPage(),
      );
}

Future<List<String>?> formDialog(BuildContext c, String title, List<String> labels, {int lastLines = 1}) {
  final cs = labels.map((_) => TextEditingController()).toList();
  return showDialog<List<String>>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < labels.length; i++)
            TextField(
              controller: cs[i],
              decoration: InputDecoration(labelText: labels[i]),
              maxLines: i == labels.length - 1 ? lastLines : 1,
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ரத்து')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, cs.map((e) => e.text).toList()),
            child: const Text('சேமி')),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext c, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('இல்லை')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ஆம்')),
      ],
    ),
  );
  return r ?? false;
}

int _i(Object? v) => (v as int?) ?? 0;
String _s(Object? v) => (v as String?) ?? '';

// ---------------- Classes ----------------
class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});
  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  late Future<List<Row>> f = DB.classes();
  void reload() => setState(() => f = DB.classes());

  Future<void> add() async {
    final r = await formDialog(context, 'புதிய வகுப்பு', ['வகுப்பு (எ.கா: 10-ஆம் வகுப்பு)', 'பிரிவு (எ.கா: A)']);
    if (r == null || r[0].trim().isEmpty) return;
    await DB.addClass(r[0].trim(), r[1].trim());
    reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('EduTrack Pro - வகுப்புகள்')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: add, icon: const Icon(Icons.add), label: const Text('புதிய வகுப்பு')),
        body: FutureBuilder<List<Row>>(
          future: f,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final rows = snap.data!;
            if (rows.isEmpty) return const Center(child: Text('வகுப்புகள் இல்லை. + தொட்டு சேர்க்கவும்.'));
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final r = rows[i];
                final title = '${_s(r['name'])} ${_s(r['section'])}'.trim();
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.class_)),
                    title: Text(title),
                    subtitle: Text('மாணவர்கள்: ${_i(r['cnt'])}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (await confirm(context, '"$title" வகுப்பை நீக்கவா?')) {
                          await DB.deleteClass(_i(r['id']));
                          reload();
                        }
                      },
                    ),
                    onTap: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => ClassPage(id: _i(r['id']), title: title)));
                      reload();
                    },
                  ),
                );
              },
            );
          },
        ),
      );
}

// ---------------- Class dashboard ----------------
class ClassPage extends StatefulWidget {
  final int id;
  final String title;
  const ClassPage({super.key, required this.id, required this.title});
  @override
  State<ClassPage> createState() => _ClassPageState();
}

class _ClassPageState extends State<ClassPage> with SingleTickerProviderStateMixin {
  late final TabController tc = TabController(length: 2, vsync: this);
  int ver = 0;

  @override
  void initState() {
    super.initState();
    tc.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    tc.dispose();
    super.dispose();
  }

  void bump() => setState(() => ver++);

  Future<void> addTask() async {
    final r = await formDialog(context, 'புதிய செயல்பாடு',
        ['செயல்பாட்டின் பெயர்', 'பாடம்', 'வகை (வீட்டுப்பாடம் / தேர்வு / அசைன்மென்ட்)']);
    if (r == null || r[0].trim().isEmpty) return;
    if (!mounted) return;
    final d = await showDatePicker(
        context: context,
        helpText: 'கடைசி தேதி',
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    await DB.addTask(widget.id, r[0].trim(), r[2].trim(), r[1].trim(),
        d == null ? '' : d.toIso8601String().substring(0, 10));
    bump();
  }

  Future<void> addStudent() async {
    final r = await formDialog(context, 'புதிய மாணவர்', ['ரோல் எண்', 'பெயர்', 'தொலைபேசி (விருப்பம்)']);
    if (r == null || r[1].trim().isEmpty) return;
    await DB.addStudent(widget.id, r[0].trim(), r[1].trim(), r[2].trim());
    bump();
  }

  Future<void> importStudents() async {
    final r = await formDialog(
        context, 'பல மாணவர்களைச் சேர்க்க', ['ஒரு வரிக்கு ஒருவர்: ரோல் எண்,பெயர்  (அல்லது பெயர் மட்டும்)'],
        lastLines: 10);
    if (r == null || r[0].trim().isEmpty) return;
    final n = await DB.importStudents(widget.id, r[0]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n மாணவர்கள் சேர்க்கப்பட்டனர்')));
    bump();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            if (tc.index == 1)
              IconButton(
                  tooltip: 'பட்டியல் இறக்குமதி',
                  icon: const Icon(Icons.playlist_add),
                  onPressed: importStudents),
          ],
          bottom: TabBar(controller: tc, tabs: const [Tab(text: 'செயல்பாடுகள்'), Tab(text: 'மாணவர்கள்')]),
        ),
        floatingActionButton: tc.index == 0
            ? FloatingActionButton.extended(
                onPressed: addTask, icon: const Icon(Icons.add_task), label: const Text('புதிய செயல்பாடு'))
            : FloatingActionButton.extended(
                onPressed: addStudent, icon: const Icon(Icons.person_add), label: const Text('மாணவர்')),
        body: TabBarView(controller: tc, children: [
          TasksTab(key: ValueKey('t$ver'), classId: widget.id, onChanged: bump),
          StudentsTab(key: ValueKey('s$ver'), classId: widget.id, onChanged: bump),
        ]),
      );
}

class TasksTab extends StatefulWidget {
  final int classId;
  final VoidCallback onChanged;
  const TasksTab({super.key, required this.classId, required this.onChanged});
  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  late final Future<List<Row>> f = DB.tasks(widget.classId);

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Row>>(
        future: f,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          if (rows.isEmpty) return const Center(child: Text('செயல்பாடுகள் இல்லை.'));
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final t = rows[i];
              final total = _i(t['total']), done = _i(t['done']);
              final due = _s(t['due_date']);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: InkWell(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskPage(task: t)));
                    widget.onChanged();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                            child: Text(_s(t['title']),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (await confirm(context, 'இந்தச் செயல்பாட்டை நீக்கவா?')) {
                              await DB.deleteTask(_i(t['id']));
                              widget.onChanged();
                            }
                          },
                        ),
                      ]),
                      Text([
                        if (_s(t['subject']).isNotEmpty) _s(t['subject']),
                        if (_s(t['category']).isNotEmpty) _s(t['category']),
                        if (due.isNotEmpty) 'கடைசி தேதி: $due',
                      ].join(' • ')),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: total == 0 ? 0 : done / total,
                          color: Colors.green,
                          backgroundColor: Colors.red.shade200,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('$total இல் $done முடித்தார்கள் | ${total - done} முடிக்கவில்லை',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      );
}

class StudentsTab extends StatefulWidget {
  final int classId;
  final VoidCallback onChanged;
  const StudentsTab({super.key, required this.classId, required this.onChanged});
  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  late final Future<List<Row>> f = DB.students(widget.classId);

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Row>>(
        future: f,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          if (rows.isEmpty) return const Center(child: Text('மாணவர்கள் இல்லை.'));
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final s = rows[i];
              return ListTile(
                leading: CircleAvatar(child: Text(_s(s['roll_no']).isEmpty ? '-' : _s(s['roll_no']))),
                title: Text(_s(s['name'])),
                subtitle: _s(s['phone']).isEmpty ? null : Text(_s(s['phone'])),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirm(context, '${_s(s['name'])} ஐ நீக்கவா?')) {
                      await DB.deleteStudent(_i(s['id']));
                      widget.onChanged();
                    }
                  },
                ),
              );
            },
          );
        },
      );
}

// ---------------- Task tracker ----------------
class TaskPage extends StatefulWidget {
  final Row task;
  const TaskPage({super.key, required this.task});
  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  List<Row> subs = [];
  bool loading = true;
  String filter = 'all';

  int get taskId => _i(widget.task['id']);

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final rows = await DB.subs(taskId);
    setState(() {
      subs = rows.map((e) => Row.from(e)).toList();
      loading = false;
    });
  }

  Future<void> toggle(Row s) async {
    final next = s['status'] == 'completed' ? 'pending' : 'completed';
    setState(() => s['status'] = next);
    await DB.setStatus(_i(s['id']), next);
  }

  Future<void> markAll() async {
    await DB.markAll(taskId, 'completed');
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final done = subs.where((s) => s['status'] == 'completed').length;
    final pending = subs.length - done;
    final shown = subs.where((s) => filter == 'all' || s['status'] == filter).toList();
    final due = _s(widget.task['due_date']);
    return Scaffold(
      appBar: AppBar(
        title: Text(_s(widget.task['title'])),
        actions: [
          IconButton(tooltip: 'அனைவருக்கும் முடித்ததாக மாற்று', icon: const Icon(Icons.done_all), onPressed: markAll),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          [
                            if (_s(widget.task['subject']).isNotEmpty) _s(widget.task['subject']),
                            if (due.isNotEmpty) 'கடைசி தேதி: $due',
                          ].join(' • '),
                          style: Theme.of(context).textTheme.bodyMedium)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(spacing: 8, children: [
                  ChoiceChip(
                      label: Text('அனைவரும் (${subs.length})'),
                      selected: filter == 'all',
                      onSelected: (_) => setState(() => filter = 'all')),
                  ChoiceChip(
                      label: Text('🟢 முடித்தவர்கள் ($done)'),
                      selected: filter == 'completed',
                      onSelected: (_) => setState(() => filter = 'completed')),
                  ChoiceChip(
                      label: Text('🔴 முடிக்காதவர்கள் ($pending)'),
                      selected: filter == 'pending',
                      onSelected: (_) => setState(() => filter = 'pending')),
                ]),
              ),
              const Divider(),
              Expanded(
                child: shown.isEmpty
                    ? const Center(child: Text('மாணவர்கள் இல்லை.'))
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (_, i) {
                          final s = shown[i];
                          final ok = s['status'] == 'completed';
                          return ListTile(
                            leading: CircleAvatar(
                                backgroundColor: ok ? Colors.green : Colors.red,
                                foregroundColor: Colors.white,
                                child: Text(_s(s['roll_no']).isEmpty ? '-' : _s(s['roll_no']))),
                            title: Text(_s(s['name']),
                                style: TextStyle(color: ok ? Colors.green.shade800 : Colors.red.shade700)),
                            subtitle: Text(ok ? 'முடித்தார்' : 'முடிக்கவில்லை'),
                            trailing: Switch(
                                value: ok,
                                activeColor: Colors.green,
                                inactiveThumbColor: Colors.red,
                                onChanged: (_) => toggle(s)),
                            onTap: () => toggle(s),
                          );
                        },
                      ),
              ),
            ]),
    );
  }
}
