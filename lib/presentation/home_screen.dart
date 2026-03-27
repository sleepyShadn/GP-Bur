// ========== lib/presentation/home_screen.dart ==========
import 'package:appforhumman/presentation/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../domain/home_logic.dart';
import '../../data/home_data.dart';
import 'all_goals_and_activities_page.dart';
import 'analysis_screen.dart';
import 'garden_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeLogic _logic = HomeLogic();
  final HomeData _data = HomeData();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  final TextEditingController _textController = TextEditingController();

  int _selectedIndex = 2;

  String _currentClassification = '';
  String _currentGoal = '';
  List<Map<String, dynamic>> _currentActivities = [];
  bool _isAnalyzing = false;

  DateTime? _goalStartDate;
  int? _goalDurationDays;
  DateTime? _goalExpiryDate;
  bool _isGoalCompleted = false;

  final List<String> _classifications = [
    'anxiety', 'depression', 'anorexia', 'bipolar', 'ADHD',
    'antisocial personality', 'bulimia'
  ];

  String _userId = '';
  int _userPoints = 0;
  String _currentAnalysisId = '';
  int _todayAnalysisCount = 0;
  List<String> _recentDiagnoses = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _getCurrentUser();
    _checkTodayAnalysisCount();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNotifications();
    });
  }

  @override
  void dispose() {
    _data.cancelSubscription();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    if (_userId.isNotEmpty) {
      await _data.initNotifications(_userId);
    }
  }

  Future<void> _getCurrentUser() async {
    final user = await _data.getCurrentUser();
    if (user != null) {
      setState(() {
        _userId = user['uid'] ?? '';
      });
      _loadUserPoints();
      _loadRecentDiagnoses();
      _checkTodayAnalysisCount();
      _listenToLatestAnalysis();
    }
  }

  void _listenToLatestAnalysis() {
    _data.listenToLatestAnalysis(_userId, (data) {
      if (data != null && mounted) {
        setState(() {
          _currentAnalysisId = data['analysisId'] ?? '';
          _currentClassification = data['classification'] ?? '';
          _currentGoal = data['goal'] ?? '';
          _goalStartDate = data['goalStartDate'];
          _goalDurationDays = data['goalDurationDays'];
          _goalExpiryDate = data['goalExpiryDate'];
          _isGoalCompleted = data['isGoalCompleted'] ?? false;
          _currentActivities = data['activities'] ?? [];
        });
      }
    });
  }

  Future<void> _loadUserPoints() async {
    final points = await _data.loadUserPoints(_userId);
    if (mounted) setState(() => _userPoints = points);
  }

  Future<void> _loadRecentDiagnoses() async {
    final diagnoses = await _data.loadRecentDiagnoses(_userId);
    if (mounted) setState(() => _recentDiagnoses = diagnoses);
  }

  Future<void> _checkTodayAnalysisCount() async {
    final count = await _data.checkTodayAnalysisCount(_userId);
    if (mounted) setState(() => _todayAnalysisCount = count);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();

      if (available) {
        setState(() => _isListening = true);

        // الحصول على قائمة اللغات
        var locales = await _speech.locales();

        // البحث عن اللغة الإنجليزية فقط
        var englishLocale = locales.firstWhere(
              (locale) => locale.localeId.contains('en'),
          orElse: () => locales.first, // إذا لم يوجد انجليزي، استخدم الافتراضي
        );

        _speech.listen(
          onResult: (val) {
            setState(() {
              _textController.text = val.recognizedWords;
            });
          },
          localeId: englishLocale.localeId, // فرض الإنجليزية
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
          ),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }


  void _showDailyLimitMessage() {
    _logic.showDailyLimitMessage(context);
  }

  Future<void> _analyzeMood() async {
    if (_textController.text.isEmpty) {
      _logic.showErrorDialog(context, 'Please enter or speak your mood first');
      return;
    }

    if (_todayAnalysisCount >= 2) {
      _showDailyLimitMessage();
      return;
    }

    setState(() => _isAnalyzing = true);

    final isValid = await _data.isValidText(_textController.text);
    if (!isValid) {
      _logic.showRandomTextError(context);
      setState(() => _isAnalyzing = false);
      return;
    }

    final isPositive = await _data.checkForPositiveSentiment(_textController.text);
    if (isPositive) {
      _logic.showPositivePopup(context);
      setState(() => _isAnalyzing = false);
      return;
    }

    final result = await _data.analyzeMood(_textController.text, _classifications);

    if (result != null && mounted) {
      final saved = await _data.saveAnalysisToFirestore(
        userId: _userId,
        text: _textController.text,
        classification: result['classification'],
        goal: result['goal'],
        startDate: DateTime.now(),
        duration: result['duration'],
        activities: result['activities'],
      );

      if (saved) {
        setState(() {
          _todayAnalysisCount++;
          _textController.clear();
        });
        await _checkForRecurringDiagnosis(result['classification']);
      }
    } else {
      _logic.showErrorDialog(context, result?['error'] ?? 'Error analyzing mood');
    }

    setState(() => _isAnalyzing = false);
  }

  Future<void> _checkForRecurringDiagnosis(String newDiagnosis) async {
    final shouldNotify = await _data.checkForRecurringDiagnosis(_userId, newDiagnosis, _recentDiagnoses);
    if (shouldNotify && mounted) {
      _logic.showRecurringDiagnosisNotification(context);
    }
  }

  void _toggleActivity(int index) async {
    if (_userId.isEmpty || _currentAnalysisId.isEmpty || _isGoalCompleted) return;

    final activity = _currentActivities[index];
    if (_logic.isActivityCompletedToday(activity)) return;

    final success = await _data.toggleActivity(_userId, _currentAnalysisId, index, activity);

    if (success && mounted) {
      // Safe conversion from num to int
      int pointsToAdd = (activity['points'] as num?)?.toInt() ?? 5;
      setState(() {
        _userPoints += pointsToAdd;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const GardenPage()));
        break;
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopPage()));
        break;
      case 2:
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsPage()));
        break;
      case 4:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
        break;
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
            colors: [Color(0xFFE7CCCC), Color(0xFFEDE8DC), Color(0xFFC1CFA1)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.5),
                      radius: 22,
                      child: const Icon(Icons.person, color: Color(0xff7f9461), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _logic.getWelcomeMessage(_currentClassification),
                            style: const TextStyle(
                              color: Color(0xff7f9461),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_todayAnalysisCount > 0)
                            Text(
                              "Today's entries: $_todayAnalysisCount/2",
                              style: const TextStyle(
                                color: Color(0xff7f9461),
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xff7f9461).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars, color: Color(0xff7f9461), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$_userPoints',
                            style: const TextStyle(
                              color: Color(0xff7f9461),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  "How are you",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff7f9461),
                    height: 1.1,
                  ),
                ),
                const Text(
                  "feeling today?",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff7f9461),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _textController,
                        maxLines: 4,
                        minLines: 3,
                        decoration: InputDecoration(
                          hintText: "Tell me how you're feeling...",
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFFE7CCCC).withOpacity(0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isAnalyzing ? null : _listen,
                              icon: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: Text(
                                _isListening ? "Listening..." : "Voice Input",
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC1CFA1),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (_isAnalyzing || _todayAnalysisCount >= 2) ? null : _analyzeMood,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _todayAnalysisCount >= 2 ? Colors.grey : const Color(0xff7f9461),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 0,
                              ),
                              child: _isAnalyzing
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : Text(
                                _todayAnalysisCount >= 2 ? "Daily Limit Reached" : "Analyze",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_currentClassification.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xff7f9461).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xff7f9461).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Analysis Result:",
                          style: TextStyle(
                            color: Color(0xff7f9461),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentClassification.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xff7f9461),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (_goalDurationDays != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isGoalCompleted
                          ? const Color(0xff7f9461).withOpacity(0.3)
                          : const Color(0xFFC1CFA1).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _isGoalCompleted ? const Color(0xff7f9461) : const Color(0xFFC1CFA1),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _logic.getGoalStatusMessage(_isGoalCompleted, _goalExpiryDate),
                      style: TextStyle(
                        color: _isGoalCompleted ? const Color(0xff7f9461) : const Color(0xff7f9461),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_currentGoal.isNotEmpty)
                  _buildCard(
                    icon: Icons.flag,
                    title: "YOUR GOAL",
                    content: _currentGoal,
                  ),
                const SizedBox(height: 20),
                if (_currentActivities.isNotEmpty)
                  _buildCard(
                    icon: Icons.star,
                    title: _isGoalCompleted ? "COMPLETED ACTIVITIES" : "TODAY'S ACTIVITIES (5 points each)",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...List.generate(_currentActivities.length, (index) => _buildActivityItem(index)),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AllGoalsAndActivitiesPage(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff7f9461),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "View All Activities",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onItemTapped(2),
        backgroundColor: const Color(0xff7f9461),
        shape: const CircleBorder(),
        child: const Icon(Icons.home, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildActivityItem(int index) {
    final activity = _currentActivities[index];
    final isCompletedToday = _logic.isActivityCompletedToday(activity);
    final lastCompleted = activity['lastCompletedDate'] as DateTime?;
    final canCompleteToday = !_isGoalCompleted && !isCompletedToday;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE7CCCC).withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isCompletedToday ? const Color(0xff7f9461) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: canCompleteToday ? () => _toggleActivity(index) : null,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompletedToday ? const Color(0xff7f9461) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: canCompleteToday ? const Color(0xff7f9461) : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: isCompletedToday
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity['title'],
                      style: TextStyle(
                        color: isCompletedToday ? Colors.grey : const Color(0xff7f9461),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: isCompletedToday ? TextDecoration.lineThrough : null,
                        decorationColor: const Color(0xff7f9461),
                        decorationThickness: 2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lastCompleted != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.history,
                              size: 12,
                              color: const Color(0xff7f9461).withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Last: ${lastCompleted.day}/${lastCompleted.month}',
                                style: TextStyle(
                                  color: const Color(0xff7f9461).withOpacity(0.5),
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompletedToday
                      ? const Color(0xff7f9461)
                      : const Color(0xFFC1CFA1).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stars,
                      size: 14,
                      color: isCompletedToday ? Colors.white : const Color(0xff7f9461),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${activity['points']}',
                      style: TextStyle(
                        color: isCompletedToday ? Colors.white : const Color(0xff7f9461),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isCompletedToday)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 36),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: const Color(0xff7f9461).withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  const Flexible(
                    child: Text(
                      'Completed today',
                      style: TextStyle(
                        color: Color(0xff7f9461),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard({required IconData icon, required String title, String? content, Widget? child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7CCCC).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xff7f9461), size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xff7f9461),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (content != null)
            Text(
              content,
              style: const TextStyle(
                color: Color(0xff7f9461),
                fontWeight: FontWeight.bold,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          if (child != null) child,
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.local_florist_outlined, "Garden", 0),
            _navItem(Icons.storefront, "Shop", 1),
            const SizedBox(width: 40),
            _navItem(Icons.bar_chart, "Analysis", 3),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xff7f9461) : Colors.grey,
            size: isSelected ? 24 : 22,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xff7f9461) : Colors.grey,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

