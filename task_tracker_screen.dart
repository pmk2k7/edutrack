import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../models/task_submission_model.dart';
import '../providers/app_provider.dart';

class TaskTrackerScreen extends StatefulWidget {
  final TaskModel task;
  final String className;

  const TaskTrackerScreen({
    super.key,
    required this.task,
    required this.className,
  });

  @override
  State<TaskTrackerScreen> createState() => _TaskTrackerScreenState();
}

class _TaskTrackerScreenState extends State<TaskTrackerScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Completed, 2: Pending
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final allSubmissions = provider.submissions;
        final completedList = provider.completedSubmissions;
        final pendingList = provider.pendingSubmissions;

        // Apply filter based on selected tab
        List<TaskSubmissionModel> currentList;
        if (_selectedFilterIndex == 1) {
          currentList = completedList;
        } else if (_selectedFilterIndex == 2) {
          currentList = pendingList;
        } else {
          currentList = allSubmissions;
        }

        // Apply search filter if query is present
        if (_searchQuery.trim().isNotEmpty) {
          final q = _searchQuery.toLowerCase().trim();
          currentList = currentList.where((s) {
            return s.studentName.toLowerCase().contains(q) ||
                s.rollNo.toLowerCase().contains(q);
          }).toList();
        }

        final total = allSubmissions.length;
        final completedCount = completedList.length;
        final pendingCount = pendingList.length;
        final percentage = total > 0 ? ((completedCount / total) * 100).toInt() : 0;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'செயல்பாட்டுக் கண்காணிப்பு',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'கூடுதல் விருப்பங்கள்',
                onSelected: (val) {
                  if (val == 'all_done') {
                    _confirmBatchAction(
                      context,
                      title: 'அனைவருக்கும் முடித்ததாக மாற்றவா?',
                      message: 'வகுப்பிலுள்ள அனைத்து மாணவர்களையும் "முடித்தார்" நிலைக்கு மாற்றும்.',
                      onConfirm: () {
                        provider.markAllSubmissions(widget.task.id!, 'completed');
                      },
                    );
                  } else if (val == 'all_pending') {
                    _confirmBatchAction(
                      context,
                      title: 'அனைவரையும் முடிக்காத நிலைக்கு மாற்றவா?',
                      message: 'அனைத்து மாணவர்களையும் "முடிக்கவில்லை (Pending)" நிலைக்கு மாற்றும்.',
                      onConfirm: () {
                        provider.markAllSubmissions(widget.task.id!, 'pending');
                      },
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'all_done',
                    child: Row(
                      children: [
                        Icon(Icons.done_all, color: Colors.green),
                        SizedBox(width: 8),
                        Text('அனைவருக்கும் முடித்ததாக மாற்று'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'all_pending',
                    child: Row(
                      children: [
                        Icon(Icons.replay, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('அனைவருக்கும் நிலுவை (Reset)'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // 1. Prominent Activity Header Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(color: Colors.teal.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.assignment, color: Colors.teal.shade800, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.task.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.className} • ${widget.task.subject} • ${widget.task.category}',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                              ),
                              Text(
                                'சமர்ப்பிக்க வேண்டிய தேதி: ${widget.task.dueDate}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Metrics Row (வகுப்பு அளவில் முடித்தவர்கள் & முடிக்காதவர்கள்)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricChip(
                          label: 'மொத்தம்',
                          count: '$total',
                          color: Colors.blueGrey,
                          icon: Icons.people,
                        ),
                        _buildMetricChip(
                          label: 'முடித்தவர்கள்',
                          count: '$completedCount',
                          color: Colors.green,
                          icon: Icons.check_circle,
                        ),
                        _buildMetricChip(
                          label: 'முடிக்காதவர்கள்',
                          count: '$pendingCount',
                          color: Colors.redAccent,
                          icon: Icons.cancel,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'வகுப்பு நிறைவு சதவீதம் (Progress):',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        Text(
                          '$percentage%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: total > 0 ? (completedCount / total) : 0,
                        minHeight: 8,
                        backgroundColor: Colors.red.shade100,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Search & Tab Filter Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'மாணவர் பெயர் அல்லது பதிவெண் தேடுக...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),

              // 3. Filter Buttons (Tabs)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFilterTab(
                        title: 'அனைவரும் ($total)',
                        index: 0,
                        activeColor: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterTab(
                        title: '🟢 முடித்தவர்கள் ($completedCount)',
                        index: 1,
                        activeColor: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterTab(
                        title: '🔴 முடிக்காதவர்கள் ($pendingCount)',
                        index: 2,
                        activeColor: Colors.redAccent.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // Instruction hint for the teacher
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.touch_app, size: 15, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'ஒரே டச்சில் நிலை மாற்ற பொத்தானைத் தொடவும்',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

              // 4. Students List with One-Touch Toggle
              Expanded(
                child: currentList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectedFilterIndex == 1
                                    ? Icons.pending_actions
                                    : _selectedFilterIndex == 2
                                        ? Icons.verified
                                        : Icons.person_off_outlined,
                                size: 50,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _selectedFilterIndex == 1
                                    ? 'இன்னும் யாரும் முடிக்கவில்லை'
                                    : _selectedFilterIndex == 2
                                        ? 'அனைத்து மாணவர்களும் முடித்துவிட்டார்கள்! 🎉'
                                        : 'மாணவர்கள் எவரும் காணப்படவில்லை',
                                style: const TextStyle(fontSize: 15, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        itemCount: currentList.length,
                        itemBuilder: (context, index) {
                          final item = currentList[index];
                          final isDone = item.isCompleted;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: isDone ? 1 : 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isDone ? Colors.green.shade200 : Colors.red.shade200,
                                width: 1.2,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                provider.toggleSubmissionStatus(
                                  widget.task.id!,
                                  item.studentId,
                                  item.status,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    // Roll No Circle
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isDone ? Colors.green.shade50 : Colors.red.shade50,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDone ? Colors.green : Colors.redAccent,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          item.rollNo,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDone ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Student Name
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.studentName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isDone ? Colors.black87 : Colors.red.shade900,
                                            ),
                                          ),
                                          Text(
                                            'பதிவெண்: ${item.rollNo}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Quick Status Button (One-Touch Interactive)
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDone ? Colors.green : Colors.red.shade50,
                                        foregroundColor: isDone ? Colors.white : Colors.red.shade800,
                                        elevation: isDone ? 2 : 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          side: BorderSide(
                                            color: isDone ? Colors.green : Colors.red.shade300,
                                          ),
                                        ),
                                      ),
                                      icon: Icon(
                                        isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                                        size: 18,
                                      ),
                                      label: Text(
                                        isDone ? 'முடித்தார்' : 'முடிக்கவில்லை',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      onPressed: () {
                                        provider.toggleSubmissionStatus(
                                          widget.task.id!,
                                          item.studentId,
                                          item.status,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildFilterTab({
    required String title,
    required int index,
    required Color activeColor,
  }) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmBatchAction(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ரத்து செய்'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('உறுதி செய்'),
          ),
        ],
      ),
    );
  }
}
