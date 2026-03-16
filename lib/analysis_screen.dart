import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';
import 'garden_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  static const Color colorPinkish = Color(0xFFE7CCCC);
  static const Color colorCream = Color(0xFFEDE8DC);
  static const Color colorGreenDark = Color(0xff7f9461);
  static const Color colorGreenLight = Color(0xFFC1CFA1);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedIndex = 3;

  // Classifications list
  final List<String> _classifications = [
    'anxiety',
    'depression',
    'anorexia',
    'bipolar',
    'ADHD',
    'antisocial personality',
    'bulimia'
  ];

  // Date range selection
  DateTime? _startDate;
  DateTime? _endDate;

  // Data from Firebase
  int _totalPoints = 0;
  int _completedActivities = 0;
  int _totalGoals = 0;
  int _totalAnalyses = 0;

  // Classification counts for histogram
  Map<String, int> _classificationCounts = {};
  List<Map<String, dynamic>> _allAnalysesData = [];

  bool _isLoading = true;
  String _userId = '';

  // Report generation state
  bool _isGeneratingReport = false;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      await _loadUserData();
      await _loadAnalysesData();
    }
  }

  Future<void> _loadUserData() async {
    if (_userId.isEmpty) return;

    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_userId).get();
      if (userDoc.exists) {
        setState(() {
          _totalPoints = userDoc.get('points') ?? 0;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadAnalysesData() async {
    if (_userId.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Calculate date range if not set
      if (_startDate == null || _endDate == null) {
        DateTime now = DateTime.now();
        _startDate = DateTime(now.year, now.month, 1); // First day of current month
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59); // Today
      }

      // Get all analyses for the user within the date range
      QuerySnapshot analysesSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('analyses')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(_endDate!))
          .orderBy('timestamp', descending: true)
          .get();

      // Initialize counts for all classifications
      Map<String, int> counts = {};
      for (var classification in _classifications) {
        counts[classification] = 0;
      }

      int completedActs = 0;
      int goalsCount = 0;
      List<Map<String, dynamic>> analysesData = [];

      // Process each analysis
      for (var doc in analysesSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // Store full analysis data for report
        analysesData.add({
          'id': doc.id,
          ...data,
        });

        // Count classification
        String classification = data['classification'] ?? '';
        if (_classifications.contains(classification)) {
          counts[classification] = (counts[classification] ?? 0) + 1;
        }

        // Count goals (each analysis has one goal)
        if (data['goal'] != null && data['goal'].toString().isNotEmpty) {
          goalsCount++;
        }

        // Count completed activities
        List<dynamic> activities = data['activities'] ?? [];
        for (var activity in activities) {
          if (activity['completed'] == true) {
            completedActs++;
          }
        }
      }

      setState(() {
        _classificationCounts = counts;
        _completedActivities = completedActs;
        _totalGoals = goalsCount;
        _totalAnalyses = analysesSnapshot.docs.length;
        _allAnalysesData = analysesData;
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading analyses: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    DateTime now = DateTime.now();

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: colorGreenDark,
              onPrimary: Colors.white,
              surface: colorCream,
              onSurface: colorGreenDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      await _loadAnalysesData();
    }
  }

  Future<void> _generatePDFReport() async {
    if (_userId.isEmpty || _allAnalysesData.isEmpty) {
      _showErrorDialog('No data available to generate report');
      return;
    }

    setState(() {
      _isGeneratingReport = true;
    });

    try {
      // Create PDF document
      final pdf = pw.Document();

      // Add cover page
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
                      'Mental Health Analytics Report',
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
                      'Generated for: ${_auth.currentUser?.email ?? 'User'}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'Date Range: ${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'Generated on: ${_formatDate(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      // Add summary page
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
                      value: '$_totalPoints',
                      icon: pw.IconData(0xe838),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: _buildSummaryBox(
                      title: 'Total Analyses',
                      value: '$_totalAnalyses',
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
                      value: '$_completedActivities',
                      icon: pw.IconData(0xe86c),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: _buildSummaryBox(
                      title: 'Total Goals',
                      value: '$_totalGoals',
                      icon: pw.IconData(0xe87d),
                    ),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      // Add classification distribution page
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            List<pw.Widget> items = [];

            items.add(pw.Text(
              'Mental Health Classification Distribution',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green700,
              ),
            ));

            items.add(pw.SizedBox(height: 20));

            // Create table for classifications
            items.add(
              pw.Table.fromTextArray(
                headers: ['Classification', 'Count', 'Percentage'],
                data: _classifications.map((classification) {
                  int count = _classificationCounts[classification] ?? 0;
                  double percentage = _totalAnalyses > 0
                      ? (count / _totalAnalyses * 100)
                      : 0;
                  String displayName = classification.split(' ').map((word) =>
                  word[0].toUpperCase() + word.substring(1)
                  ).join(' ');

                  return [
                    displayName,
                    count.toString(),
                    '${percentage.toStringAsFixed(1)}%',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.green700,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                border: pw.TableBorder.all(color: PdfColors.grey300),
              ),
            );

            items.add(pw.SizedBox(height: 20));

            // Add total row
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
                    pw.Text(
                      'Total Analyses:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '$_totalAnalyses',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );

            return items;
          },
        ),
      );

      // Add detailed analyses pages
      if (_allAnalysesData.isNotEmpty) {
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

              for (var analysis in _allAnalysesData) {
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

      // Add activities completion history
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

            // Collect all activities
            Map<String, int> activityCompletionCount = {};
            int totalPossibleCompletions = 0;

            for (var analysis in _allAnalysesData) {
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

            // Create activities table
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
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.green700,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                border: pw.TableBorder.all(color: PdfColors.grey300),
              ),
            );

            items.add(pw.SizedBox(height: 20));

            // Add total completions
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
                    pw.Text(
                      'Total Activity Completions:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '$totalPossibleCompletions',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );

            return items;
          },
        ),
      );

      // Save PDF to device
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/mental_health_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      setState(() {
        _isGeneratingReport = false;
      });

      // Show options to share or open
      _showPDFOptions(file);

    } catch (e) {
      setState(() {
        _isGeneratingReport = false;
      });
      _showErrorDialog('Error generating PDF: $e');
    }
  }

  pw.Widget _buildSummaryBox({
    required String title,
    required String value,
    required pw.IconData icon,
  }) {
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
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.green600,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildAnalysisDetailItem(Map<String, dynamic> analysis) {
    Timestamp? timestamp = analysis['timestamp'];
    String date = timestamp != null
        ? _formatDate(timestamp.toDate())
        : 'Unknown date';

    String classification = analysis['classification'] ?? 'Unknown';
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
              pw.Text(
                'Date: $date',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                classification.toUpperCase(),
                style: pw.TextStyle(
                  color: PdfColors.green700,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Original text: "$text"',
            style:  pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Goal: $goal',
            style:  pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Activities: $completedActivities/${activities.length} completed',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _showPDFOptions(File file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colorCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorGreenDark.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Report Generated Successfully',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorGreenDark,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.share, color: colorGreenDark),
                title: const Text('Share Report', style: TextStyle(color: colorGreenDark)),
                onTap: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(file.path)],
                    text: 'Mental Health Analytics Report',
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.picture_as_pdf, color: colorGreenDark),
                title: const Text('Open PDF', style: TextStyle(color: colorGreenDark)),
                onTap: () {
                  Navigator.pop(context);
                  _openPDF(file);
                },
              ),
              ListTile(
                leading: Icon(Icons.close, color: Colors.red),
                title: const Text('Close', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPDF(File file) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => await file.readAsBytes(),
      );
    } catch (e) {
      _showErrorDialog('Error opening PDF: $e');
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        title: const Text('Error', style: TextStyle(color: colorGreenDark)),
        content: Text(message, style: const TextStyle(color: colorGreenDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: colorGreenDark)),
          ),
        ],
      ),
    );
  }

  int _getMaxY() {
    int max = 0;
    _classificationCounts.forEach((key, value) {
      if (value > max) max = value;
    });
    return max + 1;
  }

  double _getInterval() {
    int max = _getMaxY();
    if (max <= 5) return 1;
    if (max <= 10) return 2;
    if (max <= 20) return 5;
    return 10;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      switch (index) {
        case 0:
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => GardenPage()));
          break;
        case 1:
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => ShopPage()));
          break;
        case 3:
          print('Already on Analytics Page');
          break;
        case 4:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          );
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorPinkish, colorCream, colorGreenLight],
            stops: [0.1, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colorGreenDark),
            ),
          )
              : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: colorGreenDark),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Analytics & Statistics",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorGreenDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.assessment_outlined,
                        color: colorGreenDark),
                  ],
                ),
                const SizedBox(height: 16),

                // Date Range Selector
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.date_range, color: colorGreenDark, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "Date Range",
                            style: TextStyle(
                              color: colorGreenDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: colorGreenLight.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatDate(_startDate),
                                style: TextStyle(color: colorGreenDark),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('to', style: TextStyle(color: colorGreenDark)),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: colorGreenLight.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatDate(_endDate),
                                style: TextStyle(color: colorGreenDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _selectDateRange,
                          icon: const Icon(Icons.edit_calendar, color: Colors.white, size: 16),
                          label: const Text(
                            "Select Date Range",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorGreenDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: "Points",
                        value: _totalPoints.toString(),
                        icon: Icons.star,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: "Activities",
                        value: _completedActivities.toString(),
                        icon: Icons.check_circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: "Goals",
                        value: _totalGoals.toString(),
                        icon: Icons.flag,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: "Analyses",
                        value: _totalAnalyses.toString(),
                        icon: Icons.analytics,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Classification Distribution Title
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pie_chart_outline,
                          color: colorGreenDark, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Mental Health Analysis Distribution",
                          style: TextStyle(
                            color: colorGreenDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "Total: $_totalAnalyses analyses",
                          style: TextStyle(
                            color: colorGreenDark,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Histogram Chart
                Container(
                  height: 300,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _classificationCounts.isEmpty
                      ? Center(
                    child: Text(
                      "No data available for selected range",
                      style: TextStyle(color: colorGreenDark),
                    ),
                  )
                      : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxY().toDouble(),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${rod.toY.toInt()}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < _classifications.length) {
                                String label = _classifications[index];
                                // Shorten labels for display
                                if (label == 'antisocial personality') {
                                  label = 'Antisocial';
                                } else if (label == 'anorexia') {
                                  label = 'Anorexia';
                                } else {
                                  label = label.substring(0, 1).toUpperCase() +
                                      label.substring(1, label.length > 6 ? 6 : label.length);
                                }

                                return Container(
                                  width: 45,
                                  alignment: Alignment.center,
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: colorGreenDark,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                            reservedSize: 40,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: colorGreenDark,
                                  fontSize: 10,
                                ),
                              );
                            },
                            reservedSize: 24,
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: _getInterval(),
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: colorGreenLight.withOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(
                        show: false,
                      ),
                      barGroups: List.generate(_classifications.length, (index) {
                        String classification = _classifications[index];
                        int count = _classificationCounts[classification] ?? 0;

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: count.toDouble(),
                              width: 16,
                              color: colorGreenDark,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                          showingTooltipIndicators: [0],
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Classification Details List
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Classification Details",
                        style: TextStyle(
                          color: colorGreenDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(_classifications.length, (index) {
                        String classification = _classifications[index];
                        int count = _classificationCounts[classification] ?? 0;
                        double percentage = _totalAnalyses > 0
                            ? (count / _totalAnalyses * 100)
                            : 0;

                        // Format classification name for display
                        String displayName = classification.split(' ').map((word) =>
                        word[0].toUpperCase() + word.substring(1)
                        ).join(' ');

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colorGreenDark,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    color: colorGreenDark,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                constraints: const BoxConstraints(minWidth: 24),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: colorGreenDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                constraints: const BoxConstraints(minWidth: 36),
                                child: Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: colorGreenLight,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const Divider(color: colorGreenLight, height: 24),

                      // Summary Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Total Analyses:",
                            style: TextStyle(
                              color: colorGreenDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '$_totalAnalyses',
                            style: TextStyle(
                              color: colorGreenDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Generate Report Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _isGeneratingReport || _allAnalysesData.isEmpty
                        ? null
                        : _generatePDFReport,
                    icon: _isGeneratingReport
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.picture_as_pdf,
                        color: Colors.white, size: 20),
                    label: Text(
                      _isGeneratingReport
                          ? "Generating Report..."
                          : "Download PDF Report",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorGreenDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        },
        backgroundColor: colorGreenLight,
        shape: const CircleBorder(),
        child: const Icon(Icons.home, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorGreenDark.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorGreenDark, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: colorGreenDark,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: colorGreenLight,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      child: SizedBox(
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.local_florist_outlined, "Garden", 0),
            _navItem(Icons.storefront, "Shop", 1),
            const SizedBox(width: 36),
            _navItem(Icons.bar_chart, "Analytics", 3),
            _navItem(Icons.person_outline, "Profile", 4),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? colorGreenDark : Colors.grey,
              size: isSelected ? 22 : 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colorGreenDark : Colors.grey,
                fontSize: isSelected ? 10 : 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}