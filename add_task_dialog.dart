import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class AddTaskDialog extends StatefulWidget {
  final int classId;

  const AddTaskDialog({super.key, required this.classId});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController(text: 'கணிதம்');
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'வீட்டுப்பாடம் (Homework)';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final provider = context.watch<AppProvider>();
    final categories = provider.categories;
    final quickSubjects = provider.subjects;

    if (!categories.contains(_selectedCategory) && categories.isNotEmpty) {
      _selectedCategory = categories.first;
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_task, color: Colors.teal),
          SizedBox(width: 8),
          Text('புதிய செயல்பாடு சேர்த்தல்', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Task Title (செயல்பாட்டின் பெயர்)
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'செயல்பாட்டின் பெயர் (Activity Name) *',
                    hintText: 'எ.கா: இயற்கணிதம் பயிற்சி 3.1',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'செயல்பாட்டின் பெயரை உள்ளிடவும்';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 2. Category Dropdown & Add Custom Category Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_selectedCategory),
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'பணி வகை (Category)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: categories.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add, color: Colors.teal),
                      tooltip: 'கூடுதல் பணி வகை சேர் (Add Category)',
                      onPressed: _showAddCategoryDialog,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, left: 2.0),
                  child: InkWell(
                    onTap: _showAddCategoryDialog,
                    child: Text(
                      '+ கூடுதல் பணி வகை சேர்க்க (+ Add Category)',
                      style: TextStyle(fontSize: 11, color: Colors.teal.shade800, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Subject with quick suggestions & Add Custom Subject
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'பாடம் (Subject) *',
                    hintText: 'எ.கா: கணிதம், கணினி அறிவியல்...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'பாடத்தின் பெயரை உள்ளிடவும்';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ...quickSubjects.map((sub) {
                      final isSelected = _subjectController.text.trim() == sub;
                      return ActionChip(
                        avatar: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                        label: Text(sub, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87)),
                        backgroundColor: isSelected ? Colors.teal : Colors.grey.shade100,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _subjectController.text = sub;
                          });
                        },
                      );
                    }),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 14, color: Colors.teal),
                      label: const Text('+ கூடுதல் பாடம்', style: TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.teal.shade50,
                      padding: EdgeInsets.zero,
                      onPressed: _showAddSubjectDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Due Date
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'சமர்ப்பிக்க வேண்டிய கடைசி தேதி (Due Date)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_month),
                    ),
                    child: Text(
                      dateFormat.format(_selectedDate),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ரத்து செய் (Cancel)'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final dueDateStr = dateFormat.format(_selectedDate);
              context.read<AppProvider>().addTask(
                    classId: widget.classId,
                    title: _titleController.text.trim(),
                    category: _selectedCategory,
                    subject: _subjectController.text.trim(),
                    dueDate: dueDateStr,
                    description: _descriptionController.text.trim(),
                  );
              Navigator.pop(context);
            }
          },
          child: const Text('சேர் (Add Activity)'),
        ),
      ],
    );
  }

  void _showAddCategoryDialog() {
    final catController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('புதிய பணி வகை சேர்த்தல்'),
        content: TextField(
          controller: catController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'பணி வகை பெயர் (Category Name)',
            hintText: 'எ.கா: ஆய்வகப் பணி (Lab), வினாடி வினா (Quiz)...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ரத்து செய்'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              final newCat = catController.text.trim();
              if (newCat.isNotEmpty) {
                context.read<AppProvider>().addCustomCategory(newCat);
                setState(() {
                  _selectedCategory = newCat;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('சேர் (Add)'),
          ),
        ],
      ),
    );
  }

  void _showAddSubjectDialog() {
    final subController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('புதிய பாடம் சேர்த்தல்'),
        content: TextField(
          controller: subController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'பாடத்தின் பெயர் (Subject Name)',
            hintText: 'எ.கா: கணினி அறிவியல், உடற்கல்வி...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ரத்து செய்'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              final newSub = subController.text.trim();
              if (newSub.isNotEmpty) {
                context.read<AppProvider>().addCustomSubject(newSub);
                setState(() {
                  _subjectController.text = newSub;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('சேர் (Add)'),
          ),
        ],
      ),
    );
  }
}
