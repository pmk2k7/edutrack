import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class AddStudentDialog extends StatefulWidget {
  final int classId;

  const AddStudentDialog({super.key, required this.classId});

  @override
  State<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<AddStudentDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Single Student Mode
  final _rollNoController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  // CSV File Import State
  String? _selectedFileName;
  List<Map<String, String>> _csvParsedStudents = [];
  bool _isCsvLoading = false;

  // Bulk Text Paste Controller
  final _bulkTextController = TextEditingController();

  int _addedCountInSession = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAutoRollNumber();
    });
  }

  void _initAutoRollNumber() {
    final provider = context.read<AppProvider>();
    final students = provider.students;

    if (students.isNotEmpty) {
      final lastRoll = students.last.rollNo;
      _rollNoController.text = _calculateNextRoll(lastRoll);
    } else {
      _rollNoController.text = '1';
    }
  }

  /// Calculates the next roll number keeping identical formatting and leading zeros
  /// Examples: "1" -> "2", "01" -> "02", "009" -> "010", "101" -> "102", "A-01" -> "A-02"
  String _calculateNextRoll(String currentRoll) {
    final trimmed = currentRoll.trim();
    if (trimmed.isEmpty) return '1';

    final regex = RegExp(r'^(.*?)(\d+)$');
    final match = regex.firstMatch(trimmed);

    if (match != null) {
      final prefix = match.group(1) ?? '';
      final digitsStr = match.group(2)!;
      final number = int.tryParse(digitsStr);

      if (number != null) {
        final nextNumber = number + 1;
        final padded = nextNumber.toString().padLeft(digitsStr.length, '0');
        return '$prefix$padded';
      }
    }

    // Fallback if not matching digits at end
    return '$trimmed-1';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rollNoController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _nameFocusNode.dispose();
    _bulkTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'மாணவர்கள் சேர்க்கை',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          TabBar(
            controller: _tabController,
            labelColor: Colors.teal.shade800,
            indicatorColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.person_add, size: 20), text: 'வரிசை எண் சேர்க்கை'),
              Tab(icon: Icon(Icons.attach_file, size: 20), text: 'CSV கோப்பு'),
              Tab(icon: Icon(Icons.paste, size: 20), text: 'நகலெடுத்து ஒட்டு'),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 380,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildAutoRollSingleForm(),
            _buildCsvFilePickerTab(),
            _buildBulkTextTab(),
          ],
        ),
      ),
      actions: [
        if (_addedCountInSession > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'சேர்க்கப்பட்டவர்கள்: $_addedCountInSession',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 12),
            ),
          ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('சேர் (Save)'),
          onPressed: _saveSingleStudentAndNext,
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('முடிந்தது (Done)'),
        ),
      ],
    );
  }

  // ==================== 1. AUTO ROLL SINGLE STUDENT ====================

  Widget _buildAutoRollSingleForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 14.0, bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Informative Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.teal, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'முதல் மாணவருக்கு வரிசை எண் தந்தால் போதும், அடுத்தடுத்த மாணவர்களுக்கு அதே வடிவில் தானாக வரிசை எண் மாறும்.',
                    style: TextStyle(fontSize: 12, color: Colors.teal),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Roll No Field with Auto badge
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _rollNoController,
                  decoration: const InputDecoration(
                    labelText: 'வரிசை எண் (Roll No) *',
                    hintText: '1 அல்லது 01',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text(
                  'தானியங்கி\n(Auto-Seq)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Student Name field (Enter key triggers immediate save!)
          TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'மாணவர் பெயர் (Student Name) *',
              hintText: 'எ.கா: கவின் குமார்',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _saveSingleStudentAndNext(),
          ),
          const SizedBox(height: 12),

          // Phone field (Optional)
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'தொலைபேசி எண் (விருப்பத்தேர்வு)',
              hintText: '9876543210',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
            onSubmitted: (_) => _saveSingleStudentAndNext(),
          ),
          const SizedBox(height: 16),

          // Prominently Visible Add Student Button!
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade800,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.person_add_alt_1, size: 22),
              label: const Text(
                'மாணவரைச் சேர் (Save & Next)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: _saveSingleStudentAndNext,
            ),
          ),
        ],
      ),
    );
  }

  void _saveSingleStudentAndNext() {
    final rollNo = _rollNoController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (rollNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('வரிசை எண்ணை உள்ளிடவும்')),
      );
      return;
    }
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('மாணவர் பெயரை உள்ளிடவும்')),
      );
      return;
    }

    final provider = context.read<AppProvider>();
    provider.addStudent(widget.classId, rollNo, name, phone.isEmpty ? null : phone);

    setState(() {
      _addedCountInSession++;
      // Auto-increment the roll number for the next student in identical format!
      _rollNoController.text = _calculateNextRoll(rollNo);
      _nameController.clear();
      _phoneController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name ($rollNo) வெற்றிகரமாக சேர்க்கப்பட்டார்!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );

    // Keep focus on name input for seamless typing of next student
    _nameFocusNode.requestFocus();
  }

  // ==================== 2. CSV FILE PICKER TAB ====================

  Widget _buildCsvFilePickerTab() {
    return Padding(
      padding: const EdgeInsets.only(top: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'உங்கள் மொபைலில் உள்ள .csv கோப்பை இணைக்கவும். கோப்பில் "வரிசை எண், பெயர், போன்" அல்லது வெறும் பெயர்கள் இருக்கலாம்.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Pick Button
          Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('CSV கோப்பைத் தேர்ந்தெடு (Select CSV File)'),
              onPressed: _isCsvLoading ? null : _pickCsvFile,
            ),
          ),
          const SizedBox(height: 12),

          if (_isCsvLoading)
            const Center(child: CircularProgressIndicator())
          else if (_selectedFileName != null) ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'கோப்பு: $_selectedFileName (${_csvParsedStudents.length} மாணவர்கள்)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Preview box
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ListView.builder(
                  itemCount: _csvParsedStudents.length,
                  itemBuilder: (ctx, idx) {
                    final s = _csvParsedStudents[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        '${s['roll_no']}. ${s['name']}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.cloud_download),
                label: Text('${_csvParsedStudents.length} மாணவர்களையும் இறக்குமதி செய் (Import All)'),
                onPressed: _importParsedCsv,
              ),
            ),
          ] else ...[
            const Spacer(),
            Center(
              child: Text(
                'கோப்பு எதுவும் தேர்ந்தெடுக்கப்படவில்லை',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
            const Spacer(),
          ],
        ],
      ),
    );
  }

  Future<void> _pickCsvFile() async {
    setState(() => _isCsvLoading = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final content = utf8.decode(bytes);

        final parsed = _parseCsvContent(content);
        if (mounted) {
          setState(() {
            _selectedFileName = file.name;
            _csvParsedStudents = parsed;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('கோப்பை வாசிப்பதில் பிழை: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCsvLoading = false);
      }
    }
  }

  List<Map<String, String>> _parseCsvContent(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    final List<Map<String, String>> list = [];

    final provider = context.read<AppProvider>();
    String currentRoll = provider.students.isNotEmpty
        ? _calculateNextRoll(provider.students.last.rollNo)
        : '1';

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Skip header line if present
      final lower = line.toLowerCase();
      if (i == 0 && (lower.contains('roll') || lower.contains('name') || lower.contains('பெயர்') || lower.contains('வரிசை'))) {
        continue;
      }

      if (line.contains(',') || line.contains('\t') || line.contains(';')) {
        final parts = line.split(RegExp(r'[,;\t]'));
        final p0 = parts[0].trim();
        final p1 = parts.length > 1 ? parts[1].trim() : '';
        final p2 = parts.length > 2 ? parts[2].trim() : '';

        // Check if first column is numeric/roll number
        if (RegExp(r'^\d+').hasMatch(p0)) {
          list.add({'roll_no': p0, 'name': p1.isNotEmpty ? p1 : 'மாணவர் $p0', 'phone': p2});
        } else {
          // If first column is name
          list.add({'roll_no': currentRoll, 'name': p0, 'phone': p1});
          currentRoll = _calculateNextRoll(currentRoll);
        }
      } else {
        // Plain single name per line
        list.add({'roll_no': currentRoll, 'name': line, 'phone': ''});
        currentRoll = _calculateNextRoll(currentRoll);
      }
    }

    return list;
  }

  void _importParsedCsv() {
    if (_csvParsedStudents.isEmpty) return;

    final provider = context.read<AppProvider>();
    provider.bulkAddStudents(widget.classId, _csvParsedStudents);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_csvParsedStudents.length} மாணவர்கள் வெற்றிகரமாக சேர்க்கப்பட்டனர்!'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }

  // ==================== 3. BULK TEXT COPY-PASTE TAB ====================

  Widget _buildBulkTextTab() {
    return Padding(
      padding: const EdgeInsets.only(top: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WhatsApp அல்லது Excel-லிருந்து வரிக்கு ஒரு மாணவர் என ஒட்டவும் (Paste):',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _bulkTextController,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                hintText: '01, கவின் குமார்\n02, வர்ஷினி பிரியா\n03, முகமது ஆசிப்\n(அல்லது வெறும் பெயர்கள்)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.paste),
              label: const Text('அனைவரையும் சேர் (Add All)'),
              onPressed: () {
                final text = _bulkTextController.text.trim();
                if (text.isEmpty) return;

                final parsed = _parseCsvContent(text);
                if (parsed.isNotEmpty) {
                  context.read<AppProvider>().bulkAddStudents(widget.classId, parsed);
                  Navigator.pop(context);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
