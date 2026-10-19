import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_model.dart';
import '../models/task_submission_model.dart';
import '../providers/app_provider.dart';
import '../services/pdf_report_service.dart';

class ClassReportScreen extends StatefulWidget {
  final ClassModel classModel;

  const ClassReportScreen({super.key, required this.classModel});

  @override
  State<ClassReportScreen> createState() => _ClassReportScreenState();
}

class _ClassReportScreenState extends State<ClassReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<int, List<TaskSubmissionModel>> _taskSubmissionsMap = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllSubmissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSubmissions() async {
    final provider = context.read<AppProvider>();
    final tasks = provider.tasks;

    Map<int, List<TaskSubmissionModel>> map = {};
    for (final task in tasks) {
      if (task.id != null) {
        final subs = await provider.databaseHelper.getSubmissionsForTask(task.id!);
        map[task.id!] = subs;
      }
    }

    if (mounted) {
      setState(() {
        _taskSubmissionsMap = map;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final students = provider.students;
        final tasks = provider.tasks;

        // Calculate student summaries
        int grandTotal = 0;
        int grandCompleted = 0;

        final List<Map<String, dynamic>> studentProgressList = [];
        for (final student in students) {
          int completed = 0;
          int total = 0;

          for (final task in tasks) {
            final subs = _taskSubmissionsMap[task.id] ?? [];
            final studentSub = subs.where((s) => s.studentId == student.id).firstOrNull;
            if (studentSub != null) {
              total++;
              if (studentSub.isCompleted) completed++;
            }
          }

          final pending = total - completed;
          final percent = total > 0 ? (completed / total) : 0.0;

          studentProgressList.add({
            'student': student,
            'total': total,
            'completed': completed,
            'pending': pending,
            'percent': percent,
          });

          grandTotal += total;
          grandCompleted += completed;
        }

        final classAvgPercent = grandTotal > 0 ? ((grandCompleted / grandTotal) * 100).toInt() : 0;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'முன்னேற்ற அறிக்கை (Progress Report)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                Text(
                  widget.classModel.displayName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.print_outlined),
                tooltip: 'அச்சிடு / PDF சேமி (Print Report)',
                onPressed: () => _printReport(context, provider),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.teal,
              indicatorWeight: 3,
              labelColor: Colors.teal.shade800,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(icon: Icon(Icons.people_outline, size: 18), text: 'மாணவர் வாரியாக'),
                Tab(icon: Icon(Icons.assignment_outlined, size: 18), text: 'செயல்பாடு வாரியாக'),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // 1. Overall Class Performance Banner
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal.shade800, Colors.teal.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryStat('மாணவர்கள்', '${students.length}', Icons.people),
                              Container(height: 36, width: 1, color: Colors.white24),
                              _buildSummaryStat('செயல்பாடுகள்', '${tasks.length}', Icons.assignment),
                              Container(height: 36, width: 1, color: Colors.white24),
                              _buildSummaryStat('முடிக்கப்பட்டவை', '$grandCompleted', Icons.check_circle),
                              Container(height: 36, width: 1, color: Colors.white24),
                              _buildSummaryStat('வகுப்பு சராசரி', '$classAvgPercent%', Icons.auto_graph),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: grandTotal > 0 ? (grandCompleted / grandTotal) : 0,
                              minHeight: 6,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. Tab Bar Views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildStudentWiseTab(studentProgressList),
                          _buildTaskWiseTab(tasks),
                        ],
                      ),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: Colors.teal.shade800,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.print),
            label: const Text('அறிக்கையை அச்சிடு (Print / PDF)'),
            onPressed: () => _printReport(context, provider),
          ),
        );
      },
    );
  }

  Widget _buildStudentWiseTab(List<Map<String, dynamic>> progressList) {
    var filtered = progressList;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      filtered = progressList.where((item) {
        final student = item['student'] as dynamic;
        return student.name.toLowerCase().contains(q) ||
            student.rollNo.toLowerCase().contains(q);
      }).toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'மாணவர் பெயர் அல்லது வரிசை எண் தேடுக...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('மாணவர்கள் எவரும் காணப்படவில்லை', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    final student = item['student'] as dynamic;
                    final total = item['total'] as int;
                    final completed = item['completed'] as int;
                    final pending = item['pending'] as int;
                    final percentDouble = item['percent'] as double;
                    final percentInt = (percentDouble * 100).toInt();

                    Color statusColor = Colors.green;
                    String statusText = 'சிறப்பு';
                    if (percentInt < 50) {
                      statusColor = Colors.redAccent;
                      statusText = 'கவனம் தேவை';
                    } else if (percentInt < 75) {
                      statusColor = Colors.orange;
                      statusText = 'நன்று';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.teal.shade50,
                                  child: Text(
                                    student.rollNo,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.teal.shade900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      Text(
                                        'முடித்தவை: $completed / $total  •  நிலுவை: $pending',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$statusText ($percentInt%)',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentDouble,
                                minHeight: 5,
                                backgroundColor: Colors.red.shade100,
                                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTaskWiseTab(List<dynamic> tasks) {
    if (tasks.isEmpty) {
      return const Center(child: Text('செயல்பாடுகள் எதுவும் இல்லை', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: tasks.length,
      itemBuilder: (context, idx) {
        final task = tasks[idx];
        final pct = (task.completionPercentage * 100).toInt();

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.teal.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${task.category} • ${task.subject} • கடைசி தேதி: ${task.dueDate}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text('முடித்தவர்கள்: ${task.completedCount}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(width: 14),
                    const Icon(Icons.cancel, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Text('முடிக்காதவர்கள்: ${task.pendingCount}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: task.completionPercentage,
                    minHeight: 6,
                    backgroundColor: Colors.red.shade100,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }

  void _printReport(BuildContext context, AppProvider provider) {
    PdfReportService.generateAndPrintClassReport(
      classModel: widget.classModel,
      students: provider.students,
      tasks: provider.tasks,
      taskSubmissionsMap: _taskSubmissionsMap,
    );
  }
}
