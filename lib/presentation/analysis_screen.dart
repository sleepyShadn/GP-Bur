// ========== lib/presentation/analysis_screen.dart ==========
import 'package:appforhumman/presentation/profile_screen.dart';
import 'package:appforhumman/presentation/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/analysis_logic.dart';
import '../../domain/assessment_classifications.dart';
import '../../data/analysis_data.dart';
import 'garden_screen.dart';
import 'home_screen.dart';
import 'widgets/main_top_app_bar.dart';


class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with SingleTickerProviderStateMixin {
  final AnalysisLogic _logic = AnalysisLogic();
  final AnalysisData _data = AnalysisData();

  int _selectedIndex = 3;

  static const Map<String, String> _chartAxisShortLabels =
      <String, String>{
    'sleeping disorder': 'Sleeping',
    'social disorder': 'Social',
    'obsessive habits': 'Obsessive',
    'cognitive disorder': 'Cognitive',
    'adhd': 'ADHD',
    'mood swings': 'Mood',
    'mild anger issues': 'Anger',
  };

  final List<String> _classifications = List<String>.from(
    kAssessmentClassifications,
  );

  DateTime? _startDate;
  DateTime? _endDate;

  int _totalPoints = 0;
  int _completedActivities = 0;
  int _totalGoals = 0;
  int _totalAnalyses = 0;

  Map<String, int> _classificationCounts = {};
  List<Map<String, dynamic>> _allAnalysesData = [];

  bool _isLoading = true;
  bool _isGeneratingReport = false;
  String _userId = '';
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _getCurrentUser();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    final userData = await _data.getCurrentUser();
    if (userData != null) {
      setState(() {
        _userId = userData['uid'] ?? '';
      });
      await _loadUserData();
      await _loadAnalysesData();
    }
  }

  Future<void> _loadUserData() async {
    if (_userId.isEmpty) return;
    final points = await _data.loadUserPoints(_userId);
    setState(() => _totalPoints = points);
  }

  Future<void> _loadAnalysesData() async {
    if (_userId.isEmpty) return;
    setState(() => _isLoading = true);

    if (_startDate == null || _endDate == null) {
      DateTime now = DateTime.now();
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }

    final result = await _data.loadAnalysesData(
      _userId,
      _startDate!,
      _endDate!,
      _classifications,
    );

    setState(() {
      _classificationCounts = result['counts'] ?? {};
      _completedActivities = result['completedActivities'] ?? 0;
      _totalGoals = result['totalGoals'] ?? 0;
      _totalAnalyses = result['totalAnalyses'] ?? 0;
      _allAnalysesData = result['analysesData'] ?? [];
      _isLoading = false;
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await _logic.selectDateRange(context, _startDate, _endDate);
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
      _logic.showErrorDialog(context, 'No data available to generate report');
      return;
    }

    setState(() => _isGeneratingReport = true);

    final userEmail = await _data.getUserEmail();
    final pdfFile = await _data.generatePDFReport(
      userEmail,
      _startDate,
      _endDate,
      _totalPoints,
      _totalAnalyses,
      _completedActivities,
      _totalGoals,
      _classifications,
      _classificationCounts,
      _allAnalysesData,
    );

    setState(() => _isGeneratingReport = false);

    if (pdfFile != null) {
      _logic.showPDFOptions(context, pdfFile);
    } else {
      _logic.showErrorDialog(context, 'Error generating PDF');
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      switch (index) {
        case 0:
          Navigator.push(context, MaterialPageRoute(builder: (_) => GardenPage()));
          break;
        case 1:
          Navigator.push(context, MaterialPageRoute(builder: (_) => ShopPage()));
          break;
        case 3:
          break;
        case 4:
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
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
            colors: [
              Color(0xFFEBD9DC),
              Color(0xFFF2E5D9),
              Color(0xFFE8F2E3),
              Color(0xFFD1E2CF),
            ],
            stops: [0.0, 0.32, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? _buildLoadingShimmer()
              : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                MainTopAppBar(title: 'Analytics', coins: _totalPoints),
                const SizedBox(height: 16),
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
                          Icon(Icons.date_range, color: const Color(0xff7f9461), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "Date Range",
                            style: TextStyle(
                              color: const Color(0xff7f9461),
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
                                color: const Color(0xFFC1CFA1).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _logic.formatDate(_startDate),
                                style: const TextStyle(color: Color(0xff7f9461)),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('to', style: TextStyle(color: Color(0xff7f9461))),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC1CFA1).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _logic.formatDate(_endDate),
                                style: const TextStyle(color: Color(0xff7f9461)),
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
                            backgroundColor: const Color(0xff7f9461),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pie_chart_outline, color: Color(0xff7f9461), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Mental Health Analysis Distribution",
                          style: TextStyle(
                            color: const Color(0xff7f9461),
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
                            color: const Color(0xff7f9461),
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
                      style: TextStyle(color: const Color(0xff7f9461)),
                    ),
                  )
                      : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _logic.getMaxY(_classificationCounts).toDouble(),
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
                                final String raw = _classifications[index];
                                final String label =
                                    _chartAxisShortLabels[raw] ?? raw;
                                return Container(
                                  width: 52,
                                  alignment: Alignment.center,
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      color: Color(0xff7f9461),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                            reservedSize: 44,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: const Color(0xff7f9461),
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
                        horizontalInterval: _logic.getInterval(_classificationCounts),
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: const Color(0xFFC1CFA1).withOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(_classifications.length, (index) {
                        String classification = _classifications[index];
                        int count = _classificationCounts[classification] ?? 0;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: count.toDouble(),
                              width: 16,
                              color: const Color(0xff7f9461),
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
                          color: const Color(0xff7f9461),
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
                        double percentage = _totalAnalyses > 0 ? (count / _totalAnalyses * 100) : 0;
                        String displayName = classification.split(' ').map((word) =>
                        word[0].toUpperCase() + word.substring(1)).join(' ');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xff7f9461),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    color: const Color(0xff7f9461),
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
                                    color: const Color(0xff7f9461),
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
                                    color: const Color(0xFFC1CFA1),
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(color: Color(0xFFC1CFA1), height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Total Analyses:",
                            style: TextStyle(
                              color: const Color(0xff7f9461),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '$_totalAnalyses',
                            style: TextStyle(
                              color: const Color(0xff7f9461),
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
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _isGeneratingReport || _allAnalysesData.isEmpty ? null : _generatePDFReport,
                    icon: _isGeneratingReport
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                    label: Text(
                      _isGeneratingReport ? "Generating Report..." : "Download PDF Report",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff7f9461),
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
        backgroundColor: const Color(0xFFC1CFA1),
        shape: const CircleBorder(),
        child: const Icon(Icons.home, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildLoadingShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          _buildShimmerLine(
            height: 56,
            borderRadius: 18,
            baseColor: const Color(0xffd9e7c8),
            highlightColor: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 14),
          _buildShimmerLine(
            height: 110,
            borderRadius: 20,
            baseColor: const Color(0xffe6f1f8),
            highlightColor: Colors.white.withValues(alpha: 0.84),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildShimmerLine(
                  height: 88,
                  borderRadius: 16,
                  baseColor: const Color(0xfff3e7de),
                  highlightColor: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildShimmerLine(
                  height: 88,
                  borderRadius: 16,
                  baseColor: const Color(0xffe9e3f4),
                  highlightColor: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildShimmerLine(
                  height: 88,
                  borderRadius: 16,
                  baseColor: const Color(0xffe7f0db),
                  highlightColor: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildShimmerLine(
                  height: 88,
                  borderRadius: 16,
                  baseColor: const Color(0xffe6f1f8),
                  highlightColor: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildShimmerLine(
            height: 320,
            borderRadius: 20,
            baseColor: const Color(0xffedf4e5),
            highlightColor: Colors.white.withValues(alpha: 0.82),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLine({
    required double height,
    required double borderRadius,
    required Color baseColor,
    required Color highlightColor,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: baseColor,
      ),
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (BuildContext context, Widget? child) {
          final double t = _shimmerController.value;
          final double beginX = -1.2 + (2.4 * t);
          final double endX = beginX + 0.9;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment(beginX, -0.3),
                end: Alignment(endX, 0.3),
                colors: <Color>[
                  baseColor.withValues(alpha: 0.65),
                  highlightColor,
                  baseColor.withValues(alpha: 0.65),
                ],
                stops: const <double>[0.2, 0.5, 0.8],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({required String title, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff7f9461).withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xff7f9461), size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: const Color(0xff7f9461),
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
              color: const Color(0xFFC1CFA1),
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
        height: 58,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.local_florist_outlined, "Garden", 0),
            _navItem(Icons.storefront_outlined, "Shop", 1),
            const SizedBox(width: 36),
            _navItem(Icons.bar_chart_rounded, "Analysis", 3),
            _navItem(Icons.person_outline_rounded, "Profile", 4),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xff7f9461) : Colors.grey,
              size: isSelected ? 22 : 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? const Color(0xff7f9461) : Colors.grey,
                fontSize: isSelected ? 10 : 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
