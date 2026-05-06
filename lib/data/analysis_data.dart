// ========== lib/data/analysis_data.dart ==========
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class AnalysisData {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Map<String, String> _classificationFriendlyLabels =
      <String, String>{
    'sleeping disorder': 'Sleep Balance',
    'social disorder': 'Social Comfort',
    'obsessive habits': 'Routine Flexibility',
    'cognitive disorder': 'Mental Clarity',
    'adhd': 'Attention Stability',
    'mood swings': 'Mood Stability',
    'mild anger issues': 'Emotional Calm',
    'professional support referral': 'Professional support',
  };

  Future<Map<String, dynamic>?> getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      return {'uid': user.uid, 'email': user.email};
    }
    return null;
  }

  Future<String> getUserEmail() async {
    return _auth.currentUser?.email ?? 'User';
  }

  Future<int> loadUserPoints(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.get('points') ?? 0;
    } catch (e) {
      print('Error loading user data: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> loadAnalysesData(
      String userId,
      DateTime startDate,
      DateTime endDate,
      List<String> classifications,
      ) async {
    try {
      QuerySnapshot analysesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('analyses')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('timestamp', descending: true)
          .get();

      Map<String, int> counts = {};
      for (var classification in classifications) {
        counts[classification] = 0;
      }

      int completedActivities = 0;
      int totalGoals = 0;
      List<Map<String, dynamic>> analysesData = [];

      for (var doc in analysesSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        analysesData.add({'id': doc.id, ...data});

        String classification = data['classification'] ?? '';
        if (classifications.contains(classification)) {
          counts[classification] = (counts[classification] ?? 0) + 1;
        }

        if (data['goal'] != null && data['goal'].toString().isNotEmpty) {
          totalGoals++;
        }

        List<dynamic> activities = data['activities'] ?? [];
        for (var activity in activities) {
          if (activity['completed'] == true) {
            completedActivities++;
          }
        }
      }

      return {
        'counts': counts,
        'completedActivities': completedActivities,
        'totalGoals': totalGoals,
        'totalAnalyses': analysesSnapshot.docs.length,
        'analysesData': analysesData,
      };
    } catch (e) {
      print('Error loading analyses: $e');
      return {};
    }
  }

  Future<File?> generatePDFReport(
      String userEmail,
      DateTime? startDate,
      DateTime? endDate,
      int totalPoints,
      int totalAnalyses,
      int completedActivities,
      int totalGoals,
      List<String> classifications,
      Map<String, int> classificationCounts,
      List<Map<String, dynamic>> allAnalysesData,
      ) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.SizedBox(height: 100),
                    pw.Text(
                      'Emotional Wellbeing Analytics Report',
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green700,
                      ),
                    ),
                    pw.SizedBox(height: 40),
                    pw.Container(
                      width: 100,
                      height: 100,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green100,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Center(
                        child: pw.Icon(
                          pw.IconData(0xe88a),
                          size: 50,
                          color: PdfColors.green700,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 40),
                    pw.Text(
                      'Generated for: $userEmail',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'Date Range: ${_formatDateForPDF(startDate)} - ${_formatDateForPDF(endDate)}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'Generated on: ${_formatDateForPDF(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Text(
                'Summary Statistics',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green700,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildSummaryBox(
                      title: 'Total Points',
                      value: totalPoints.toString(),
                      icon: pw.IconData(0xe838),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: _buildSummaryBox(
                      title: 'Total Analyses',
                      value: totalAnalyses.toString(),
                      icon: pw.IconData(0xe80b),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildSummaryBox(
                      title: 'Completed Activities',
                      value: completedActivities.toString(),
                      icon: pw.IconData(0xe86c),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: _buildSummaryBox(
                      title: 'Total Goals',
                      value: totalGoals.toString(),
                      icon: pw.IconData(0xe87d),
                    ),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            List<pw.Widget> items = [];
            items.add(pw.Text(
              'Emotional Pattern Distribution',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green700,
              ),
            ));
            items.add(pw.SizedBox(height: 20));
            items.add(
              pw.Table.fromTextArray(
                headers: ['Emotional Pattern', 'Count', 'Percentage'],
                data: classifications.map((classification) {
                  int count = classificationCounts[classification] ?? 0;
                  double percentage = totalAnalyses > 0 ? (count / totalAnalyses * 100) : 0;
                  String displayName = _classificationFriendlyLabels[classification] ??
                      classification
                          .split(' ')
                          .map((word) => word[0].toUpperCase() + word.substring(1))
                          .join(' ');
                  return [displayName, count.toString(), '${percentage.toStringAsFixed(1)}%'];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(color: PdfColors.green700),
                cellStyle: const pw.TextStyle(fontSize: 10),
                border: pw.TableBorder.all(color: PdfColors.grey300),
              ),
            );
            items.add(pw.SizedBox(height: 20));
            items.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Analyses:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(totalAnalyses.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            );
            return items;
          },
        ),
      );

      if (allAnalysesData.isNotEmpty) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              List<pw.Widget> items = [];
              items.add(pw.Text(
                'Detailed Analysis History',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green700,
                ),
              ));
              items.add(pw.SizedBox(height: 20));
              for (var analysis in allAnalysesData) {
                items.add(_buildAnalysisDetailItem(analysis));
                items.add(pw.SizedBox(height: 15));
                items.add(pw.Divider());
                items.add(pw.SizedBox(height: 10));
              }
              return items;
            },
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            List<pw.Widget> items = [];
            items.add(pw.Text(
              'Activities Completion Summary',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green700,
              ),
            ));
            items.add(pw.SizedBox(height: 20));

            Map<String, int> activityCompletionCount = {};
            int totalPossibleCompletions = 0;

            for (var analysis in allAnalysesData) {
              List<dynamic> activities = analysis['activities'] ?? [];
              for (var activity in activities) {
                String title = activity['title'] ?? '';
                if (title.isNotEmpty) {
                  activityCompletionCount[title] = (activityCompletionCount[title] ?? 0) +
                      (activity['completed'] == true ? 1 : 0);
                  totalPossibleCompletions++;
                }
              }
            }

            items.add(
              pw.Table.fromTextArray(
                headers: ['Activity', 'Times Completed'],
                data: activityCompletionCount.entries.map((entry) {
                  return [entry.key, entry.value.toString()];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(color: PdfColors.green700),
                cellStyle: const pw.TextStyle(fontSize: 9),
                border: pw.TableBorder.all(color: PdfColors.grey300),
              ),
            );

            items.add(pw.SizedBox(height: 20));
            items.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Activity Completions:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(totalPossibleCompletions.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            );
            return items;
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/mental_health_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      print('Error generating PDF: $e');
      return null;
    }
  }

  pw.Widget _buildSummaryBox({required String title, required String value, required pw.IconData icon}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.green200),
      ),
      child: pw.Column(
        children: [
          pw.Icon(icon, color: PdfColors.green700),
          pw.SizedBox(height: 8),
          pw.Text(value, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
          pw.SizedBox(height: 4),
          pw.Text(title, style: pw.TextStyle(fontSize: 10, color: PdfColors.green600)),
        ],
      ),
    );
  }

  pw.Widget _buildAnalysisDetailItem(Map<String, dynamic> analysis) {
    Timestamp? timestamp = analysis['timestamp'];
    String date = timestamp != null ? _formatDateForPDF(timestamp.toDate()) : 'Unknown date';
    String classification = analysis['classification'] ?? 'Unknown';
    String displayClassification =
        _classificationFriendlyLabels[classification] ?? classification;
    String goal = analysis['goal'] ?? 'No goal';
    String text = analysis['text'] ?? '';
    List<dynamic> activities = analysis['activities'] ?? [];
    int completedActivities = activities.where((a) => a['completed'] == true).length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Date: $date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(displayClassification, style: pw.TextStyle(color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text('Original text: "$text"', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10)),
          pw.SizedBox(height: 8),
          pw.Text('Goal: $goal', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Activities: $completedActivities/${activities.length} completed', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  String _formatDateForPDF(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day}/${date.month}/${date.year}';
  }
}
