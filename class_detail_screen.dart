import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_model.dart';
import '../models/task_model.dart';
import '../providers/app_provider.dart';
import 'task_tracker_screen.dart';
import 'add_task_dialog.dart';
import 'add_student_dialog.dart';
import 'class_report_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final ClassModel classModel;

  const ClassDetailScreen({super.key, required this.classModel});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final studentCount = provider.students.length;
        final tasks = provider.tasks;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.classModel.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'மாணவர்கள்: $studentCount பேர்',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.analytics_outlined),
                tooltip: 'அறிக்கை தயாரி & அச்சிடு (Report & Print)',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ClassReportScreen(classModel: widget.classModel),
                    ),
                  );
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.teal,
              indicatorWeight: 3,
              labelColor: Colors.teal.shade800,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  text: 'செயல்பாடுகள் (${tasks.length})',
                ),
                Tab(
                  icon: const Icon(Icons.people_alt_outlined),
                  text: 'மாணவர்கள் ($studentCount)',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildTasksTab(context, provider, tasks),
              _buildStudentsTab(context, provider),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return Text(
                  _tabController.index == 0
                      ? 'புதிய செயல்பாடு (Add Activity)'
                      : 'புதிய மாணவர் (Add Student)',
                );
              },
            ),
            onPressed: () {
              if (_tabController.index == 0) {
                if (provider.students.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('முதலில் மாணவர்களைச் சேர்க்கவும் (Add students first)!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  _tabController.animateTo(1);
                  return;
                }
                showDialog(
                  context: context,
                  builder: (ctx) => AddTaskDialog(classId: widget.classModel.id!),
                );
              } else {
                showDialog(
                  context: context,
                  builder: (ctx) => AddStudentDialog(classId: widget.classModel.id!),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildTasksTab(BuildContext context, AppProvider provider, List<TaskModel> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined, size: 70, color: Colors.teal.shade200),
              const SizedBox(height: 16),
              const Text(
                'செயல்பாடுகள் எதுவும் இல்லை',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'புதிய வீட்டுப்பாடம், அசைன்மென்ட் அல்லது தேர்வு சேர்க்க கீழே உள்ள "+" பொத்தானைத் தொடவும்.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final percent = (task.completionPercentage * 100).toInt();

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              provider.loadTaskSubmissions(task.id!);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskTrackerScreen(
                    task: task,
                    className: widget.classModel.displayName,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Tags Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(task.category).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          task.category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getCategoryColor(task.category),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            task.dueDate,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                            onSelected: (val) {
                              if (val == 'delete') {
                                _confirmDeleteTask(context, provider, task);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    SizedBox(width: 8),
                                    Text('நீக்கு (Delete)', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Task Title (Prominent)
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'பாடம்: ${task.subject}',
                    style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade700),
                  ),
                  const SizedBox(height: 14),

                  // Class Level Status Banner (முடித்தவர்கள் vs முடிக்காதவர்கள்)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'முடித்தவர்கள்: ${task.completedCount}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.cancel, color: Colors.redAccent, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'முடிக்காதவர்கள்: ${task.pendingCount}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$percent%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: task.completionPercentage,
                            minHeight: 7,
                            backgroundColor: Colors.red.shade100,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'மாணவர் நிலை சரிபார்க்க (Open Tracker)',
                          style: TextStyle(fontSize: 12, color: Colors.teal.shade700, fontWeight: FontWeight.w600),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 12, color: Colors.teal.shade700),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentsTab(BuildContext context, AppProvider provider) {
    if (provider.students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 70, color: Colors.teal.shade200),
              const SizedBox(height: 16),
              const Text(
                'மாணவர்கள் இன்னும் சேர்க்கப்படவில்லை',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'மாணவர்களின் பெயர் மற்றும் பதிவெண் (Roll No) உள்ளிட கீழே உள்ள "+" பொத்தானைத் தொடவும்.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: provider.students.length,
      itemBuilder: (context, index) {
        final student = provider.students[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              foregroundColor: Colors.teal.shade900,
              child: Text(
                student.rollNo,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            title: Text(
              student.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Text('பதிவெண்: ${student.rollNo}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              onPressed: () {
                _confirmDeleteStudent(context, provider, student);
              },
            ),
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    if (category.contains('வீட்டுப்பாடம்') || category.contains('Homework')) {
      return Colors.blue.shade700;
    } else if (category.contains('அசைன்மென்ட்') || category.contains('Assignment')) {
      return Colors.deepPurple;
    } else if (category.contains('பிராஜெக்ட்') || category.contains('Project')) {
      return Colors.orange.shade800;
    } else if (category.contains('தேர்வு') || category.contains('Exam')) {
      return Colors.red.shade700;
    }
    return Colors.teal;
  }

  void _confirmDeleteTask(BuildContext context, AppProvider provider, TaskModel task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('செயல்பாட்டை நீக்கவா?'),
        content: Text('"${task.title}" மற்றும் மாணவர்களின் சமர்ப்பிப்பு நிலைகள் நீக்கப்படும்.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ரத்து செய்')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              provider.deleteTask(task.id!, widget.classModel.id!);
              Navigator.pop(ctx);
            },
            child: const Text('நீக்கு'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteStudent(BuildContext context, AppProvider provider, dynamic student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('மாணவரை நீக்கவா?'),
        content: Text('${student.name} (பதிவெண்: ${student.rollNo}) நீக்கப்படுவார்.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ரத்து செய்')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              provider.deleteStudent(student.id, widget.classModel.id!);
              Navigator.pop(ctx);
            },
            child: const Text('நீக்கு'),
          ),
        ],
      ),
    );
  }
}
