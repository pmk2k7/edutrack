import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/task_model.dart';
import '../models/task_submission_model.dart';

class PdfReportService {
  static Future<void> generateAndPrintClassReport({
    required ClassModel classModel,
    required List<StudentModel> students,
    required List<TaskModel> tasks,
    required Map<int, List<TaskSubmissionModel>> taskSubmissionsMap,
  }) async {
    final pdf = pw.Document();

    // Load Tamil Unicode Font from assets
    pw.Font? ttfFont;
    pw.Font? ttfBoldFont;
    try {
      final fontData = await rootBundle.load('assets/fonts/latha.ttf');
      ttfFont = pw.Font.ttf(fontData);
      final boldData = await rootBundle.load('assets/fonts/lathab.ttf');
      ttfBoldFont = pw.Font.ttf(boldData);
    } catch (_) {
      // Fallback to standard font if asset is missing
      ttfFont = pw.Font.helvetica();
      ttfBoldFont = pw.Font.helveticaBold();
    }

    final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

    // Calculate student overall statistics
    final List<Map<String, dynamic>> studentStats = [];
    int grandTotalSubmissions = 0;
    int grandCompletedSubmissions = 0;

    for (final student in students) {
      int completed = 0;
      int total = 0;

      for (final task in tasks) {
        final subs = taskSubmissionsMap[task.id] ?? [];
        final studentSub = subs.where((s) => s.studentId == student.id).firstOrNull;
        if (studentSub != null) {
          total++;
          if (studentSub.isCompleted) completed++;
        }
      }

      final pending = total - completed;
      final percent = total > 0 ? ((completed / total) * 100).toInt() : 0;

      studentStats.add({
        'roll_no': student.rollNo,
        'name': student.name,
        'total': total,
        'completed': completed,
        'pending': pending,
        'percent': percent,
      });

      grandTotalSubmissions += total;
      grandCompletedSubmissions += completed;
    }

    final overallClassPercent = grandTotalSubmissions > 0
        ? ((grandCompletedSubmissions / grandTotalSubmissions) * 100).toInt()
        : 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: ttfFont, bold: ttfBoldFont),
        build: (context) => [
          // 1. Elegant Header Banner
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.teal800,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'EduTrack Pro',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      'மாணவர் செயல்பாடுகள் & வீட்டுப்பாடக் கண்காணிப்பு அறிக்கை',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.teal100),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'தேதி: $currentDate',
                      style: const pw.TextStyle(fontSize: 11, color: PdfColors.white),
                    ),
                    pw.Text(
                      'வகுப்பு: ${classModel.name} - ${classModel.section} பிரிவு',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // 2. Class Summary Metric Cards
          pw.Row(
            children: [
              _buildPdfMetricCard('மொத்த மாணவர்கள்', '${students.length}', PdfColors.blueGrey800),
              pw.SizedBox(width: 10),
              _buildPdfMetricCard('மொத்த செயல்பாடுகள்', '${tasks.length}', PdfColors.teal700),
              pw.SizedBox(width: 10),
              _buildPdfMetricCard('முடிக்கப்பட்டவை', '$grandCompletedSubmissions', PdfColors.green700),
              pw.SizedBox(width: 10),
              _buildPdfMetricCard('நிலுவையில் உள்ளவை', '${grandTotalSubmissions - grandCompletedSubmissions}', PdfColors.red700),
              pw.SizedBox(width: 10),
              _buildPdfMetricCard('வகுப்பு சராசரி', '$overallClassPercent%', PdfColors.indigo700),
            ],
          ),
          pw.SizedBox(height: 16),

          // 3. Section Title
          pw.Text(
            'மாணவர்கள் வாரியான முன்னேற்ற அறிக்கை (Student Progress Table)',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
          ),
          pw.SizedBox(height: 8),

          // 4. Elegant Students Table
          pw.TableHelper.fromTextArray(
            headers: [
              'வரிசை எண்',
              'மாணவர் பெயர்',
              'மொத்தப் பணிகள்',
              'முடித்தவை',
              'நிலுவை',
              'முன்னேற்றம் (%)',
              'மதிப்பீடு',
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
            cellAlignment: pw.Alignment.center,
            cellAlignments: {
              1: pw.Alignment.centerLeft,
            },
            cellStyle: const pw.TextStyle(fontSize: 9),
            data: studentStats.map((s) {
              final pct = s['percent'] as int;
              String grade = 'சிறப்பு (Excellent)';
              if (pct < 50) {
                grade = 'கவனம் தேவை';
              } else if (pct < 75) {
                grade = 'நன்று (Good)';
              }

              return [
                s['roll_no'].toString(),
                s['name'].toString(),
                s['total'].toString(),
                s['completed'].toString(),
                s['pending'].toString(),
                '$pct%',
                grade,
              ];
            }).toList(),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
          pw.SizedBox(height: 20),

          // 5. Tasks List Summary Section
          pw.Text(
            'செயல்பாடுகள் வாரியான சுருக்கம் (Task-wise Summary)',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
          ),
          pw.SizedBox(height: 6),

          pw.TableHelper.fromTextArray(
            headers: ['வ.எண்', 'செயல்பாட்டின் பெயர்', 'பணி வகை', 'பாடம்', 'கடைசி தேதி', 'முடித்தவர்கள்', 'முடிக்காதவர்கள்'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
            cellStyle: const pw.TextStyle(fontSize: 8),
            data: tasks.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final t = entry.value;
              return [
                '$idx',
                t.title,
                t.category,
                t.subject,
                t.dueDate,
                '${t.completedCount} பேர்',
                '${t.pendingCount} பேர்',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 36),

          // 6. Signatures Footer
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.Container(width: 160, height: 1, color: PdfColors.grey700),
                  pw.SizedBox(height: 6),
                  pw.Text('வகுப்பாசிரியர் கையொப்பம்\n(Class Teacher Signature)',
                      textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Container(width: 160, height: 1, color: PdfColors.grey700),
                  pw.SizedBox(height: 6),
                  pw.Text('தலைமையாசிரியர் கையொப்பம்\n(Headmaster Signature)',
                      textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${classModel.name}_${classModel.section}_Report.pdf',
    );
  }

  static pw.Widget _buildPdfMetricCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: color, width: 1),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );
  }
}
