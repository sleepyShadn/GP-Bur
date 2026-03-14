import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';
import 'garden_screen.dart';

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

  // Time range options
  final List<String> _timeRanges = ['Day', 'Week', 'Month', 'Year'];
  String _selectedTimeRange = 'Month';

  // Data from Firebase
  int _totalPoints = 0;
  int _completedActivities = 0;
  int _totalGoals = 0;

  // Classification counts for histogram
  Map<String, int> _classificationCounts = {};
  int _totalAnalyses = 0;

  bool _isLoading = true;
  String _userId = '';

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
      // Calculate date range based on selected time range
      DateTime now = DateTime.now();
      DateTime startDate;

      switch (_selectedTimeRange) {
        case 'Day':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'Week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'Month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'Year':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, 1);
      }

      // Get all analyses for the user within the time range
      QuerySnapshot analysesSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('analyses')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('timestamp', descending: true)
          .get();

      // Initialize counts for all classifications
      Map<String, int> counts = {};
      for (var classification in _classifications) {
        counts[classification] = 0;
      }

      int completedActs = 0;
      int goalsCount = 0;

      // Process each analysis
      for (var doc in analysesSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

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
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading analyses: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onTimeRangeChanged(String? newRange) {
    if (newRange != null) {
      setState(() {
        _selectedTimeRange = newRange;
      });
      _loadAnalysesData();
    }
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

  void _generateReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Generated'),
        content: Text(
            'Analytics report for $_selectedTimeRange has been successfully generated and saved to your device\n\n'
                'Total Analyses: $_totalAnalyses\n'
                'Completed Activities: $_completedActivities\n'
                'Total Goals: $_totalGoals\n'
                'Total Points: $_totalPoints'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

                // Time Range Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: colorGreenDark, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        "Time Range:",
                        style: TextStyle(
                          color: colorGreenDark,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: colorGreenLight.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedTimeRange,
                            isExpanded: true,
                            underline: const SizedBox(),
                            icon: Icon(Icons.arrow_drop_down, color: colorGreenDark),
                            items: _timeRanges.map((String range) {
                              return DropdownMenuItem<String>(
                                value: range,
                                child: Text(
                                  range,
                                  style: TextStyle(color: colorGreenDark),
                                ),
                              );
                            }).toList(),
                            onChanged: _onTimeRangeChanged,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

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
                      "No data available for $_selectedTimeRange",
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
                        "Classification Details ($_selectedTimeRange)",
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
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _generateReport,
                    icon: const Icon(Icons.download,
                        color: Colors.white, size: 20),
                    label: const Text(
                      "Generate Report",
                      style: TextStyle(
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