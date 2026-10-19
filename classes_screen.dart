import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'class_detail_screen.dart';

class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon/app_logo.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EduTrack Pro',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'வகுப்பு & செயல்பாடுகள் கண்காணிப்பான்',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'புதுப்பி (Refresh)',
            onPressed: () {
              context.read<AppProvider>().loadClasses();
            },
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.classes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school_outlined, size: 80, color: Colors.teal.shade300),
                    const SizedBox(height: 16),
                    const Text(
                      'வகுப்புகள் எதுவும் சேர்க்கப்படவில்லை',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'கீழே உள்ள "+" பொத்தானைத் தொட்டு உங்கள் முதல் வகுப்பைச் சேர்க்கவும்.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade700, Colors.teal.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('மொத்த வகுப்புகள்', '${provider.classes.length}', Icons.class_outlined),
                    Container(height: 40, width: 1, color: Colors.white24),
                    _buildStatItem(
                      'மொத்த மாணவர்கள்',
                      '${provider.classStudentCounts.values.fold(0, (a, b) => a + b)}',
                      Icons.people_alt_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'வகுப்புகளின் பட்டியல் (Classes)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
              const SizedBox(height: 12),

              // Class List
              ...provider.classes.map((cls) {
                final studentCount = provider.classStudentCounts[cls.id] ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      provider.selectClass(cls.id!);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ClassDetailScreen(classModel: cls),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                cls.section,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cls.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        'பிரிவு: ${cls.section}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'மாணவர்கள்: $studentCount',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.teal.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            tooltip: 'நீக்கு',
                            onPressed: () => _confirmDeleteClass(context, provider, cls),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('புதிய வகுப்பு (Add Class)'),
        onPressed: () => _showAddClassDialog(context),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 26),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  void _showAddClassDialog(BuildContext context) {
    final nameController = TextEditingController();
    final sectionController = TextEditingController(text: 'A');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('புதிய வகுப்பு சேர்த்தல்'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'வகுப்பு பெயர் (Class Name)',
                hintText: 'எ.கா: 10-ஆம் வகுப்பு அல்லது 9th Std',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: sectionController,
              decoration: const InputDecoration(
                labelText: 'பிரிவு (Section)',
                hintText: 'எ.கா: A, B, C...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('ரத்து செய் (Cancel)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              final name = nameController.text.trim();
              final section = sectionController.text.trim();
              if (name.isNotEmpty && section.isNotEmpty) {
                context.read<AppProvider>().addClass(name, section);
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('சேர் (Add)'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteClass(BuildContext context, AppProvider provider, dynamic cls) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('வகுப்பை நீக்கவா?'),
        content: Text(
          '${cls.displayName} மற்றும் அதன் கீழ் உள்ள அனைத்து மாணவர்கள், செயல்பாடுகள் மற்றும் நிலைகள் நிரந்தரமாக நீக்கப்படும்.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ரத்து செய்'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              provider.deleteClass(cls.id);
              Navigator.pop(ctx);
            },
            child: const Text('நீக்கு (Delete)'),
          ),
        ],
      ),
    );
  }
}
