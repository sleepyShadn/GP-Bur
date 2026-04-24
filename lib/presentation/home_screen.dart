// ========== lib/presentation/home_screen.dart ==========
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:appforhumman/presentation/shop_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../domain/assessment_classifications.dart';
import '../../domain/feeling_input_validation.dart';
import '../../domain/garden_care_logic.dart';
import '../../domain/home_logic.dart';
import '../../domain/mood_input_verdict.dart';
import '../../data/garden_care_data.dart';
import '../../data/home_data.dart';
import '../../services/garden_care_notification_coordinator.dart';
import '../../services/local_notification_inbox_store.dart';
import '../../services/notification_service.dart';
import 'widgets/main_top_app_bar.dart';
import 'all_goals_and_activities_page.dart';
import 'analysis_screen.dart';
import 'garden_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final HomeLogic _logic = HomeLogic();
  final HomeData _data = HomeData();
  final GardenCareData _gardenCareData = GardenCareData();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  final TextEditingController _textController = TextEditingController();

  int _selectedIndex = 2;

  String _currentGoal = '';
  List<Map<String, dynamic>> _currentActivities = [];
  bool _isAnalyzing = false;

  DateTime? _goalStartDate;
  int? _goalDurationDays;
  DateTime? _goalExpiryDate;
  bool _isGoalCompleted = false;

  final List<String> _classifications = List<String>.from(
    kAssessmentClassifications,
  );

  String _userId = '';
  int _userPoints = 0;
  String? _profileImageBase64;
  String _currentAnalysisId = '';
  int _todayAnalysisCount = 0;
  List<String> _recentDiagnoses = [];

  int _gardenVitality = GardenCareLogic.defaultVitality;
  bool _gardenHasPlants = false;

  // Question management UI state
  bool _isCollectingInfo = false;
  String _currentQuestion = '';
  int _remainingQuestions = 0;
  bool _isGeneratingQuestions = false;
  bool _isSubmittingAnswer = false;

  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speech = stt.SpeechToText();
    _getCurrentUser();
    _checkTodayAnalysisCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocalNotificationInboxStore.instance.removeListener(_onLocalInboxChanged);
    _data.cancelSubscription();
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _userId.isNotEmpty) {
      unawaited(_loadGardenCare());
    }
  }

  Future<void> _loadGardenCare() async {
    if (_userId.isEmpty) return;
    final int v = await _gardenCareData.loadAndReconcileVitality(_userId);
    final bool has = await _gardenCareData.userHasAnyPlant(_userId);
    if (mounted) {
      setState(() {
        _gardenVitality = v;
        _gardenHasPlants = has;
      });
    }
    await GardenCareNotificationCoordinator().syncForUser(_userId);
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
      _loadProfileImage();
      _loadRecentDiagnoses();
      _checkTodayAnalysisCount();
      _listenToLatestAnalysis();
      await _loadGardenCare();
      await _initNotifications();
      _listenUnreadNotificationsCount();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _userId.isEmpty) return;
        unawaited(
          NotificationService().tryOpenInboxFromNotificationColdStart(_userId),
        );
      });
    }
  }

  void _onLocalInboxChanged() {
    if (!mounted || _userId.isEmpty) return;
    unawaited(_syncUnreadFromLocalInbox());
  }

  Future<void> _syncUnreadFromLocalInbox() async {
    if (_userId.isEmpty) return;
    final int unread = await LocalNotificationInboxStore.instance.unreadCount(_userId);
    if (mounted) {
      setState(() => _unreadNotificationsCount = unread);
    }
  }

  void _listenUnreadNotificationsCount() {
    LocalNotificationInboxStore.instance.removeListener(_onLocalInboxChanged);
    if (_userId.isEmpty) return;
    LocalNotificationInboxStore.instance.addListener(_onLocalInboxChanged);
    unawaited(_syncUnreadFromLocalInbox());
  }

  void _openNotificationsScreen() {
    if (_userId.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(userId: _userId),
      ),
    );
  }

  void _listenToLatestAnalysis() {
    _data.listenToLatestAnalysis(_userId, (data) {
      if (data != null && mounted) {
        setState(() {
          _currentAnalysisId = data['analysisId'] ?? '';
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

  Future<void> _loadProfileImage() async {
    if (_userId.isEmpty) return;
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(_userId)
          .get();
      if (!mounted) return;
      setState(() {
        _profileImageBase64 = doc.data()?['profileImageBase64'] as String?;
      });
    } catch (_) {}
  }

  Uint8List? _profileImageBytes() {
    final String? raw = _profileImageBase64;
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
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

        var locales = await _speech.locales();

        var englishLocale = locales.firstWhere(
              (locale) => locale.localeId.contains('en'),
          orElse: () => locales.first,
        );

        _speech.listen(
          onResult: (val) {
            setState(() {
              _textController.text = val.recognizedWords;
            });
          },
          localeId: englishLocale.localeId,
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

  // NEW: Start the question collection process
  Future<void> _startQuestionCollection() async {
    if (_todayAnalysisCount >= 2) {
      _showDailyLimitMessage();
      return;
    }

    final MoodInputVerdict local = FeelingInputValidation.checkLocalInitial(
      _textController.text,
    );
    if (local != MoodInputVerdict.okContinue) {
      _logic.showMoodInputRejection(context, local);
      return;
    }

    setState(() {
      _isGeneratingQuestions = true;
      _isCollectingInfo = false;
    });

    final MoodInputVerdict api =
        await _data.classifyInitialMoodInput(_textController.text);
    if (!mounted) {
      return;
    }

    if (api != MoodInputVerdict.okContinue) {
      setState(() {
        _isGeneratingQuestions = false;
      });
      _logic.showMoodInputRejection(context, api);
      return;
    }

    final bool success =
        await _data.startCollectingInfo(_textController.text);

    if (success && mounted) {
      setState(() {
        _isGeneratingQuestions = false;
        _isCollectingInfo = true;
        _updateCurrentQuestion();
      });
    } else if (mounted) {
      setState(() {
        _isGeneratingQuestions = false;
      });
      _logic.showErrorDialog(
        context,
        'Unable to generate questions. Please try again.',
      );
    }
  }

  void _updateCurrentQuestion() {
    if (_data.isCollectingInfo()) {
      String? question = _data.getCurrentQuestionText();
      int remaining = _data.getRemainingQuestionsCount();
      setState(() {
        _currentQuestion = question ?? 'No question available';
        _remainingQuestions = remaining;
      });
    } else {
      setState(() {
        _isCollectingInfo = false;
        _currentQuestion = '';
        _remainingQuestions = 0;
      });
    }
  }

  // NEW: Submit answer during question collection
  Future<void> _submitAnswer() async {
    if (_isSubmittingAnswer) {
      return;
    }

    setState(() => _isSubmittingAnswer = true);

    final SubmitAnswerOutcome outcome =
        await _data.submitAnswerValidated(_textController.text);
    if (!mounted) {
      return;
    }

    if (outcome.isRejected) {
      setState(() => _isSubmittingAnswer = false);
      _logic.showMoodInputRejection(context, outcome.rejection!);
      return;
    }

    if (outcome.collectionComplete) {
      setState(() {
        _isCollectingInfo = false;
        _isAnalyzing = true;
        _isSubmittingAnswer = false;
      });

      await _performAnalysisWithCollectedInfo();
    } else {
      _textController.clear();
      _updateCurrentQuestion();
      setState(() => _isSubmittingAnswer = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Answer saved. Next question is ready.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 1400),
          backgroundColor: const Color(0xff7f9461),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  // NEW: Perform analysis using all collected information
  Future<void> _performAnalysisWithCollectedInfo() async {
    final collectedInfo = _data.getCollectedInfo();
    final initialInput = collectedInfo['initial_input'] ?? '';

    final result = await _data.analyzeMood(initialInput, _classifications);

    if (result != null && mounted) {
      final saved = await _data.saveAnalysisToFirestore(
        userId: _userId,
        text: initialInput,
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
          _isAnalyzing = false;
        });
        await _checkForRecurringDiagnosis(result['classification']);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Analysis complete! Your goal and activities are ready below.',
            ),
            backgroundColor: const Color(0xff7f9461),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() => _isAnalyzing = false);
        _logic.showErrorDialog(context, 'Error saving analysis');
      }
    } else {
      setState(() => _isAnalyzing = false);
      _logic.showErrorDialog(context, 'Error analyzing your information');
    }
  }

  // Original analyze method - now redirects to question collection
  Future<void> _analyzeMood() async {
    await _startQuestionCollection();
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
    final bool wasCompletedToday = _logic.isActivityCompletedToday(activity);
    final DateTime now = DateTime.now();
    final String todayKey = '${now.year}-${now.month}-${now.day}';
    final bool wasTouchedToday =
        (activity['dailyHistory'] as Map<String, dynamic>?)?.containsKey(todayKey) ??
            false;

    final success = await _data.toggleActivity(_userId, _currentAnalysisId, index, activity);

    if (success && mounted) {
      final int points = (activity['points'] as num?)?.toInt() ?? 5;
      final int delta = wasCompletedToday ? -points : points;
      int newVitality = _gardenVitality;
      if (!wasCompletedToday && !wasTouchedToday) {
        newVitality = await _gardenCareData.recordActivityCareBoost(_userId);
      }
      if (!mounted) return;
      setState(() {
        _userPoints = (_userPoints + delta).clamp(0, 1 << 31);
        _gardenVitality = newVitality;
      });
      await GardenCareNotificationCoordinator().syncForUser(_userId);
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
    final bool isBusy =
        _isAnalyzing || _isGeneratingQuestions || _isSubmittingAnswer;
    final bool canStartCheckIn = !isBusy && _todayAnalysisCount < 2;

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 236, 177, 187),
              Color.fromARGB(255, 252, 226, 202),
              Color.fromARGB(255, 196, 214, 188),
              Color(0xFFD1E2CF),
            ],
            stops: [0.0, 0.32, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                MainTopAppBar(
                  title: 'Home',
                  coins: _userPoints,
                  primaryTint: const Color(0xffdceccf),
                  secondaryTint: const Color(0xfff8fcf5),
                  accentColor: const Color(0xff496238),
                  unreadNotificationsCount: _unreadNotificationsCount,
                  onNotificationsPressed: _userId.isEmpty ? null : _openNotificationsScreen,
                ),
                const SizedBox(height: 12),
                _buildHomeWelcomeHeader(),
                const SizedBox(height: 16),
                _buildGardenVitalityCard(),
                const SizedBox(height: 24),
                _buildSectionTitle(
                  icon: Icons.psychology_alt_outlined,
                  title: 'Daily Check-in',
                ),
                const SizedBox(height: 10),
                const Text(
                  "How are you",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff7f9461),
                    height: 1.1,
                  ),
                ),
                const Text(
                  "feeling today?",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff7f9461),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 24),

                // Main input area
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.97),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: const Color(0xff7f9461).withOpacity(0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff7f9461).withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _textController,
                        maxLines: 4,
                        minLines: 3,
                        enabled: !isBusy,
                        decoration: InputDecoration(
                          hintText: _isCollectingInfo
                              ? 'Type your answer in English...'
                              : "How are you feeling? (English only — describe mood, stress, or sleep)",
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFFE7CCCC).withOpacity(0.22),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: const Color(0xff7f9461).withOpacity(0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: const Color(0xff7f9461).withOpacity(0.14),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: Color(0xff7f9461),
                              width: 1.3,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      if (!_isCollectingInfo) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: const Color(0xff7f9461).withOpacity(0.6),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Write naturally in English. Short clear details help the assistant understand you better.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: const Color(0xff7f9461).withOpacity(0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  (isBusy || _isCollectingInfo) ? null : _listen,
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
                              onPressed: (isBusy || _todayAnalysisCount >= 2)
                                  ? null
                                  : (_isCollectingInfo ? _submitAnswer : _analyzeMood),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: !canStartCheckIn
                                    ? Colors.grey
                                    : const Color(0xff7f9461),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 0,
                              ),
                              child: isBusy
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : Text(
                                _isCollectingInfo
                                    ? "Submit Answer"
                                    : (_todayAnalysisCount >= 2 ? "Daily Limit Reached" : "Start"),
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

                // NEW: Questions display area - shows current question below input
                if (_isCollectingInfo && _currentQuestion.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xff7f9461).withOpacity(0.18),
                          const Color(0xFFC1CFA1).withOpacity(0.22),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xff7f9461).withOpacity(0.25),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff7f9461).withOpacity(0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
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
                                color: Colors.white.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.question_answer,
                                color: Color(0xff7f9461),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Question ${_data.getAllQuestions().length - _remainingQuestions + 1} of ${_data.getAllQuestions().length}",
                                style: TextStyle(
                                  color: Color(0xff7f9461),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.58),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$_remainingQuestions left',
                                style: const TextStyle(
                                  color: Color(0xff7f9461),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.62),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _currentQuestion,
                            style: const TextStyle(
                              color: Color(0xff7f9461),
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.58),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: const Color(0xff7f9461).withOpacity(0.7),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  "Type your answer above, then tap Submit once.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xff7f9461),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Loading questions indicator
                if (_isGeneratingQuestions) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xff7f9461).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      children: [
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xff7f9461),
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Generating personalized questions for you...",
                          style: TextStyle(
                            color: Color(0xff7f9461),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                _buildSectionTitle(
                  icon: Icons.track_changes_outlined,
                  title: 'Current Plan',
                ),
                const SizedBox(height: 10),

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
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC1CFA1).withOpacity(0.22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.spa_outlined,
                                color: Color(0xff7f9461),
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Each completed activity plants a healthier habit. Use your points to buy seeds, then grow your garden.',
                                  style: TextStyle(
                                    color: Color(0xff7f9461),
                                    fontSize: 12.5,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...List.generate(_currentActivities.length, (index) => _buildActivityItem(index)),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ShopPage()),
                              );
                            },
                            icon: const Icon(
                              Icons.storefront_outlined,
                              color: Color(0xff7f9461),
                              size: 18,
                            ),
                            label: const Text(
                              "Get Seeds from Shop",
                              style: TextStyle(
                                color: Color(0xff7f9461),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: const Color(0xff7f9461).withOpacity(0.4),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
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
                if (_currentActivities.isEmpty)
                  _buildCard(
                    icon: Icons.eco_outlined,
                    title: "NO ACTIVITIES YET",
                    child: _buildActivitiesEmptyState(),
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
        backgroundColor: const Color(0xff6f8551),
        elevation: 3,
        shape: const CircleBorder(),
        child: const Icon(Icons.home_rounded, color: Colors.white, size: 29),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildGardenVitalityCard() {
    if (_userId.isEmpty) return const SizedBox.shrink();

    final GardenVitalityTier tier = GardenCareLogic.tierFromVitality(_gardenVitality);
    final Color accent = switch (tier) {
      GardenVitalityTier.thriving => const Color(0xff7f9461),
      GardenVitalityTier.steady => const Color(0xFFC1A564),
      GardenVitalityTier.fading => const Color(0xFFB07A6A),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const GardenPage()),
          ).then((_) => _loadGardenCare());
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(0.45)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_florist_rounded, color: accent, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Garden vitality',
                    style: TextStyle(
                      color: Color(0xff7f9461),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_gardenVitality%',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_gardenVitality.clamp(0, 100)) / 100.0,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE7CCCC).withOpacity(0.35),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                GardenCareLogic.vitalityHeadline(
                  _gardenVitality,
                  hasPlants: _gardenHasPlants,
                ),
                style: TextStyle(
                  color: const Color(0xff7f9461).withOpacity(0.92),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                GardenCareLogic.vitalityHint(_gardenVitality),
                style: TextStyle(
                  color: const Color(0xff7f9461).withOpacity(0.65),
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Open garden',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: accent, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(int index) {
    final activity = _currentActivities[index];
    final isCompletedToday = _logic.isActivityCompletedToday(activity);
    final lastCompleted = activity['lastCompletedDate'] as DateTime?;
    final canToggleToday = !_isGoalCompleted;

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
                onTap: canToggleToday ? () => _toggleActivity(index) : null,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompletedToday ? const Color(0xff7f9461) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: canToggleToday ? const Color(0xff7f9461) : Colors.grey,
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
        color: Colors.white.withOpacity(0.97),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xff7f9461).withOpacity(0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff7f9461).withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 7),
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
                    color: Color(0xff6f8551),
                    fontWeight: FontWeight.w800,
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
                color: Color(0xff6f8551),
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

  Widget _buildSectionTitle({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xff7f9461).withOpacity(0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xff7f9461), size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xff7f9461),
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildHomeWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xff5f7744).withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff5f7744).withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xffe2efda),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _profileImageBytes() != null
                  ? Image.memory(
                      _profileImageBytes()!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_rounded,
                        color: Color(0xff4f6a3d),
                        size: 23,
                      ),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      color: Color(0xff4f6a3d),
                      size: 23,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _logic.getWelcomeMessage(''),
                  style: const TextStyle(
                    color: Color(0xff4f6a3d),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 3,
                ),
                if (_todayAnalysisCount > 0)
                  Text(
                    "Today's entries: $_todayAnalysisCount/2",
                    style: TextStyle(
                      color: const Color(0xff4f6a3d).withOpacity(0.85),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesEmptyState() {
    final String body = _gardenHasPlants
        ? 'Your garden is ready for growth. Start a quick check-in to generate today\'s habit activities and keep your plants thriving.'
        : 'Start a quick check-in to generate your first habit activities. Then use points to buy seeds and grow your first plant.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          body,
          style: TextStyle(
            color: const Color(0xff7f9461).withOpacity(0.9),
            fontSize: 13.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Write how you feel above, then tap Start to generate today\'s activities.',
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xff7f9461),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.psychology_alt_outlined,
              color: Color(0xff7f9461),
              size: 18,
            ),
            label: const Text(
              "Create Today's Plan",
              style: TextStyle(
                color: Color(0xff7f9461),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: const Color(0xff7f9461).withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopPage()),
              );
            },
            icon: const Icon(Icons.storefront_outlined, color: Colors.white, size: 18),
            label: Text(
              _gardenHasPlants ? 'Get More Seeds' : 'Get Your First Seed',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff7f9461),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
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
