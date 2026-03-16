import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'analysis_screen.dart';
import 'notification_service.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';
import 'garden_screen.dart';
import 'all_goals_and_activities_page.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color colorPinkish = Color(0xFFE7CCCC);
  static const Color colorCream = Color(0xFFEDE8DC);
  static const Color colorGreenDark = Color(0xff7f9461);
  static const Color colorGreenLight = Color(0xFFC1CFA1);

  // OpenAI API Key
  final String _apiKey = "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";

  final NotificationService _notificationService = NotificationService();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  final TextEditingController _textController = TextEditingController();

  int _selectedIndex = 2;

  // Analysis results
  String _currentClassification = '';
  String _currentGoal = '';
  List<Map<String, dynamic>> _currentActivities = [];
  bool _isAnalyzing = false;

  // New fields for daily tracking and expiry
  DateTime? _goalStartDate;
  int? _goalDurationDays; // Number of days suggested by AI (5-6 days)
  DateTime? _goalExpiryDate;
  bool _isGoalCompleted = false;
  Map<String, dynamic> _dailyActivitiesStatus = {}; // Track daily completions

  // Available classifications
  final List<String> _classifications = [
    'anxiety',
    'depression',
    'anorexia',
    'bipolar',
    'ADHD',
    'antisocial personality',
    'bulimia'
  ];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _userId = '';
  int _userPoints = 0;
  String _currentAnalysisId = '';

  // Analysis daily limit
  int _todayAnalysisCount = 0;

  // For tracking consecutive diagnoses
  List<String> _recentDiagnoses = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _getCurrentUser();
    _loadLatestAnalysis();
    _checkTodayAnalysisCount();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNotifications();
    });
  }

  Future<void> _checkTodayAnalysisCount() async {
    if (_userId.isEmpty) return;

    try {
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      QuerySnapshot todayAnalyses = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('analyses')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();

      setState(() {
        _todayAnalysisCount = todayAnalyses.docs.length;
      });
    } catch (e) {
      print('Error checking today analysis count: $e');
    }
  }

  Future<void> _initNotifications() async {
    if (_userId.isNotEmpty) {
      await _notificationService.initNotifications(_userId);
    }
  }

  Future<void> _getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      _loadUserPoints();
      _loadRecentDiagnoses();
      _checkTodayAnalysisCount();
    }
  }

  Future<void> _loadUserPoints() async {
    if (_userId.isEmpty) return;

    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_userId).get();
      if (userDoc.exists) {
        setState(() {
          _userPoints = userDoc.get('points') ?? 0;
        });
      }
    } catch (e) {
      print('Error loading points: $e');
    }
  }

  Future<void> _loadRecentDiagnoses() async {
    if (_userId.isEmpty) return;

    try {
      QuerySnapshot analysisSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('analyses')
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();

      setState(() {
        _recentDiagnoses = analysisSnapshot.docs
            .map((doc) => (doc.data() as Map<String, dynamic>)['classification']?.toString() ?? '')
            .where((classification) => classification.isNotEmpty)
            .toList();
      });
    } catch (e) {
      print('Error loading recent diagnoses: $e');
    }
  }

  Future<void> _checkForRecurringDiagnosis(String newDiagnosis) async {
    if (_userId.isEmpty || newDiagnosis.isEmpty) return;

    _recentDiagnoses.insert(0, newDiagnosis);
    if (_recentDiagnoses.length > 3) {
      _recentDiagnoses = _recentDiagnoses.sublist(0, 3);
    }

    if (_recentDiagnoses.length == 3 &&
        _recentDiagnoses.every((diagnosis) => diagnosis == newDiagnosis)) {

      await _notificationService.showLocalNotificationOnly(
        title: 'Checking in',
        body: 'It looks like it\'s been a heavy few days. When you have a moment, let\'s take a breath and check in together.',
        payload: 'recurring_diagnosis',
      );

      await _createInAppNotification(_recentDiagnoses.first);
    }
  }

  Future<void> _createInAppNotification(String diagnosis) async {
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('notifications')
          .add({
        'title': 'Early Warning Alert',
        'body': 'Our system identified a recurring pattern in your recent logs that suggests you may be feeling overwhelmed. We\'re here to help.',
        'type': 'recurring_diagnosis',
        'diagnosis': diagnosis,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  Future<void> _loadLatestAnalysis() async {
    if (_userId.isEmpty) return;

    try {
      QuerySnapshot analysisSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('analyses')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (analysisSnapshot.docs.isNotEmpty) {
        var data = analysisSnapshot.docs.first.data() as Map<String, dynamic>;

        // Load goal dates
        Timestamp? startDateTimestamp = data['goalStartDate'];
        DateTime? loadedStartDate = startDateTimestamp?.toDate();
        int? loadedDuration = data['goalDurationDays'];
        bool loadedGoalCompleted = data['isGoalCompleted'] ?? false;

        setState(() {
          _currentAnalysisId = analysisSnapshot.docs.first.id;
          _currentClassification = data['classification'] ?? '';
          _currentGoal = data['goal'] ?? '';
          _goalStartDate = loadedStartDate;
          _goalDurationDays = loadedDuration;

          if (_goalStartDate != null && _goalDurationDays != null) {
            _goalExpiryDate = _goalStartDate!.add(Duration(days: _goalDurationDays!));
            _isGoalCompleted = loadedGoalCompleted || DateTime.now().isAfter(_goalExpiryDate!);
          }

          // Load activities from Firestore
          List<dynamic> activitiesData = data['activities'] ?? [];
          _currentActivities = activitiesData.map((activity) {
            return {
              'title': activity['title'],
              'points': activity['points'],
              'completed': activity['completed'] ?? false,
              'activityId': activity['activityId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'lastCompletedDate': activity['lastCompletedDate'] != null
                  ? (activity['lastCompletedDate'] as Timestamp).toDate()
                  : null,
              'dailyHistory': activity['dailyHistory'] ?? {},
            };
          }).toList();

          // Check if activities need to be reset for a new day
          _checkAndResetDailyActivities();
        });
      }
    } catch (e) {
      print('Error loading analysis: $e');
    }
  }

  void _checkAndResetDailyActivities() {
    if (_goalStartDate == null || _goalExpiryDate == null) return;

    DateTime now = DateTime.now();

    // If goal is expired, mark as completed
    if (now.isAfter(_goalExpiryDate!) && !_isGoalCompleted) {
      setState(() {
        _isGoalCompleted = true;
      });
      _updateGoalCompletionStatus();
      return;
    }

    // Don't reset if goal is completed
    if (_isGoalCompleted) return;

    // Check if we need to reset activities for a new day
    bool needsReset = false;
    for (var activity in _currentActivities) {
      DateTime? lastCompleted = activity['lastCompletedDate'];
      if (lastCompleted != null) {
        if (lastCompleted.day != now.day ||
            lastCompleted.month != now.month ||
            lastCompleted.year != now.year) {
          // This activity was completed on a previous day, reset it
          needsReset = true;
          break;
        }
      }
    }

    if (needsReset) {
      for (var activity in _currentActivities) {
        activity['completed'] = false;
        // Keep the lastCompletedDate for history
      }
    }
  }

  Future<void> _updateGoalCompletionStatus() async {
    if (_userId.isEmpty || _currentAnalysisId.isEmpty) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('analyses')
          .doc(_currentAnalysisId)
          .update({
        'isGoalCompleted': _isGoalCompleted,
      });
    } catch (e) {
      print('Error updating goal completion: $e');
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _textController.text = val.recognizedWords;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _showDailyLimitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: const Text(
            'You have reached the daily limit for symptom entries (2 per day). Please return tomorrow to provide further updates.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        backgroundColor: colorGreenDark,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  Future<bool> _isValidText(String text) async {
    if (text.trim().isEmpty) return false;

    try {
      String prompt = '''
Analyze if the following text is meaningful, coherent, and not random gibberish. 
Return ONLY "valid" if the text appears to be a real, coherent sentence or phrase in English that a person would actually say about their feelings or mental state.
Return ONLY "invalid" if the text appears to be random characters, keyboard mash (like "hdjsjaih" or "fjkdjdjkdfjlkj"), repeated letters, or nonsensical input.

Examples of valid text:
- "I'm feeling anxious today"
- "I had a great day at work"
- "feeling sad and lonely"
- "happy and excited"
- "I'm tired and stressed"

Examples of invalid text:
- "hdjsjaih"
- "fjkdjdjkdfjlkj"
- "aaaaaaa"
- "hjkhjkhjk"
- "asdfghjkl"
- "qwertyuiop"

Text to analyze: "$text"

Return just one word: either "valid" or "invalid".
''';

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a text validator that determines if text is meaningful or random gibberish. Return only "valid" or "invalid".'
            },
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.3,
          'max_tokens': 10,
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String result = data['choices'][0]['message']['content'].trim().toLowerCase();
        return result == 'valid';
      } else {
        return _basicTextValidation(text);
      }
    } catch (e) {
      print('Error checking text validity: $e');
      return _basicTextValidation(text);
    }
  }

  bool _basicTextValidation(String text) {
    if (text.trim().isEmpty) return false;

    String lowerText = text.toLowerCase();

    bool hasVowel = RegExp(r'[aeiou]').hasMatch(lowerText);

    int vowelCount = RegExp(r'[aeiou]').allMatches(lowerText).length;
    int consonantCount = RegExp(r'[bcdfghjklmnpqrstvwxyz]').allMatches(lowerText).length;

    if (vowelCount + consonantCount == 0) return false;

    double vowelRatio = vowelCount / (vowelCount + consonantCount);
    bool hasValidVowelRatio = vowelRatio >= 0.1 && vowelRatio <= 0.7;

    bool hasRepeatedPattern = RegExp(r'(.)\1{3,}').hasMatch(lowerText) ||
        RegExp(r'(.{2,})\1{2,}').hasMatch(lowerText);

    List<String> words = text.split(RegExp(r'\s+'));
    bool hasValidWords = words.any((word) => word.length >= 2);

    return hasVowel && hasValidVowelRatio && !hasRepeatedPattern && hasValidWords;
  }

  Future<bool> _checkForPositiveSentiment(String text) async {
    try {
      String prompt = '''
Analyze the sentiment of the following text. Return ONLY "positive" if the text expresses happiness, joy, contentment, or other positive emotions. Otherwise, return "not_positive".

Text to analyze: "$text"

Return just one word: either "positive" or "not_positive".
''';

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {'role': 'system', 'content': 'You are a sentiment analyzer. Return only "positive" or "not_positive".'},
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.3,
          'max_tokens': 10,
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String sentiment = data['choices'][0]['message']['content'].trim().toLowerCase();
        return sentiment == 'positive';
      }
    } catch (e) {
      print('Error checking sentiment: $e');
    }
    return false;
  }

  void _showPositivePopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        title: const Text(
          "Wonderful to hear!",
          style: TextStyle(
            color: colorGreenDark,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sentiment_very_satisfied,
              color: colorGreenDark,
              size: 60,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorGreenDark.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "No mental health conditions are flagged within our current system. Keep up the positive outlook!",
                style: TextStyle(
                  color: colorGreenDark,
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: colorGreenDark,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                "Got it!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRandomTextError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        title: const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 50,
        ),
        content: const Text(
          "The text you entered appears to be random or unintelligible. Please provide meaningful text about how you're feeling.",
          style: TextStyle(
            color: colorGreenDark,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: colorGreenDark,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                "OK",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeMood() async {
    if (_textController.text.isEmpty) {
      _showErrorDialog('Please enter or speak your mood first');
      return;
    }

    // Check daily limit first
    if (_todayAnalysisCount >= 2) {
      _showDailyLimitMessage();
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      bool isValid = await _isValidText(_textController.text);

      if (!isValid) {
        _showRandomTextError();
        setState(() {
          _isAnalyzing = false;
        });
        return;
      }

      bool isPositive = await _checkForPositiveSentiment(_textController.text);

      if (isPositive) {
        _showPositivePopup();
        setState(() {
          _isAnalyzing = false;
        });
        return;
      }

      // Updated prompt to include duration suggestion
      String prompt = '''
Based on the following text, analyze the user's mental state and provide:
1. Classification: Choose exactly ONE from these categories: ${_classifications.join(', ')}
2. Goal: Create a personalized goal based on the classification (one sentence)
3. Duration: Suggest a duration for completing this goal. Choose either 5 or 6 days or any number of appropriate daysto based on the severity and complexity of the condition.
4. Activities: Generate 4 specific, actionable activities that help achieve the goal. Each activity should be a short, clear task.

Text to analyze: "${_textController.text}"

Return the response in this exact JSON format:
{
  "classification": "category name",
  "goal": "personalized goal sentence",
  "duration": 5 or 6,
  "activities": [
    {"title": "activity 1 description", "points": 5},
    {"title": "activity 2 description", "points": 5},
    {"title": "activity 3 description", "points": 5},
    {"title": "activity 4 description", "points": 5}
  ]
}

Return ONLY the JSON, no other text.
''';

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a mental health assistant. You must respond with valid JSON only, following the exact format specified.'
            },
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String content = data['choices'][0]['message']['content'].trim();

        Map<String, dynamic> result = jsonDecode(content);
        String classification = result['classification'].toString().toLowerCase();

        if (_classifications.contains(classification)) {
          String goal = result['goal'];
          int duration = result['duration'] ?? 5; // Default to 5 if not provided
          List<dynamic> activitiesData = result['activities'];

          DateTime now = DateTime.now();
          DateTime startDate = now;
          DateTime expiryDate = startDate.add(Duration(days: duration));

          setState(() {
            _currentClassification = classification;
            _currentGoal = goal;
            _goalStartDate = startDate;
            _goalDurationDays = duration;
            _goalExpiryDate = expiryDate;
            _isGoalCompleted = false;
            _todayAnalysisCount++; // Increment the counter

            _currentActivities = activitiesData.map((activity) {
              return {
                'title': activity['title'],
                'points': activity['points'] ?? 5,
                'completed': false,
                'activityId': DateTime.now().millisecondsSinceEpoch.toString() + activity['title'],
                'lastCompletedDate': null,
                'dailyHistory': {},
              };
            }).toList();
          });

          await _checkForRecurringDiagnosis(classification);
          await _saveAnalysisToFirestore();
        } else {
          _showErrorDialog('Could not classify your mood. Please try again.');
        }
      } else {
        _showErrorDialog('Error analyzing mood. Please try again.');
      }
    } catch (e) {
      print('Error: $e');
      _showErrorDialog('Network error. Please check your connection.');
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _saveAnalysisToFirestore() async {
    if (_userId.isEmpty || _currentClassification.isEmpty) return;

    try {
      String analysisId = DateTime.now().millisecondsSinceEpoch.toString();

      Map<String, dynamic> analysisData = {
        'timestamp': FieldValue.serverTimestamp(),
        'text': _textController.text,
        'classification': _currentClassification,
        'goal': _currentGoal,
        'goalStartDate': _goalStartDate,
        'goalDurationDays': _goalDurationDays,
        'goalExpiryDate': _goalExpiryDate,
        'isGoalCompleted': _isGoalCompleted,
        'activities': _currentActivities.map((activity) => {
          'title': activity['title'],
          'points': activity['points'],
          'completed': activity['completed'],
          'activityId': activity['activityId'],
          'lastCompletedDate': activity['lastCompletedDate'],
          'dailyHistory': activity['dailyHistory'],
        }).toList(),
      };

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('analyses')
          .doc(analysisId)
          .set(analysisData);

      setState(() {
        _currentAnalysisId = analysisId;
      });

      print('Analysis saved successfully');
    } catch (e) {
      print('Error saving analysis: $e');
    }
  }

  Future<void> _toggleActivity(int index) async {
    if (_userId.isEmpty || _currentAnalysisId.isEmpty || _isGoalCompleted) return;

    // Check if already completed today
    if (_currentActivities[index]['completed']) return;

    DateTime now = DateTime.now();

    setState(() {
      _currentActivities[index]['completed'] = true;
      _currentActivities[index]['lastCompletedDate'] = now;

      // Store in daily history
      String todayKey = '${now.year}-${now.month}-${now.day}';
      if (_currentActivities[index]['dailyHistory'] == null) {
        _currentActivities[index]['dailyHistory'] = {};
      }
      _currentActivities[index]['dailyHistory'][todayKey] = true;

      // Add points
      int pointsToAdd = _currentActivities[index]['points'];
      _userPoints += pointsToAdd;
    });

    // Update user points in Firestore
    await _firestore.collection('users').doc(_userId).update({
      'points': FieldValue.increment(_currentActivities[index]['points']),
    });

    // Update the specific analysis document
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('analyses')
          .doc(_currentAnalysisId)
          .update({
        'activities': _currentActivities.map((activity) => {
          'title': activity['title'],
          'points': activity['points'],
          'completed': activity['completed'],
          'activityId': activity['activityId'],
          'lastCompletedDate': activity['lastCompletedDate'],
          'dailyHistory': activity['dailyHistory'],
        }).toList(),
      });
    } catch (e) {
      print('Error updating activity: $e');
    }
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

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

  String _getWelcomeMessage() {
    if (_currentClassification.isEmpty) {
      return "Welcome back! How are you feeling today?";
    }

    Map<String, String> welcomeMessages = {
      'anxiety': "Let's work on finding your calm today",
      'depression': "Small steps lead to big changes",
      'anorexia': "Nurture your body with kindness",
      'bipolar': "Balance is key - you've got this",
      'ADHD': "Focus on one thing at a time",
      'antisocial personality': "Every connection starts with a smile",
      'bulimia': "Be gentle with yourself today",
    };

    return welcomeMessages[_currentClassification] ?? "Welcome back!";
  }

  String _getGoalStatusMessage() {
    if (_isGoalCompleted) {
      return "✓ Goal Completed - Great job!";
    } else if (_goalExpiryDate != null) {
      int daysLeft = _goalExpiryDate!.difference(DateTime.now()).inDays;
      if (daysLeft < 0) {
        return "✓ Goal Period Ended - Well done!";
      } else {
        return "$daysLeft days remaining in goal period";
      }
    }
    return "";
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
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Header with user info and points
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.5),
                      radius: 22,
                      child: const Icon(Icons.person, color: colorGreenDark, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getWelcomeMessage(),
                            style: const TextStyle(
                              color: colorGreenDark,
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
                                color: colorGreenDark,
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
                        color: colorGreenDark.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars, color: colorGreenDark, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$_userPoints',
                            style: const TextStyle(
                              color: colorGreenDark,
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
                // Main title
                const Text(
                  "How are you",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: colorGreenDark,
                    height: 1.1,
                  ),
                ),
                const Text(
                  "feeling today?",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: colorGreenDark,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 24),
                // Input card with voice
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
                          hintStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: colorPinkish.withOpacity(0.3),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorGreenLight,
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
                                backgroundColor: _todayAnalysisCount >= 2 ? Colors.grey : colorGreenDark,
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
                // Classification result
                if (_currentClassification.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorGreenDark.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorGreenDark.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Analysis Result:",
                          style: TextStyle(
                            color: colorGreenDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentClassification.toUpperCase(),
                          style: const TextStyle(
                            color: colorGreenDark,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // Goal status
                if (_goalDurationDays != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isGoalCompleted
                          ? colorGreenDark.withOpacity(0.3)
                          : colorGreenLight.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _isGoalCompleted ? colorGreenDark : colorGreenLight,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getGoalStatusMessage(),
                      style: TextStyle(
                        color: _isGoalCompleted ? colorGreenDark : colorGreenDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                // Goal card
                if (_currentGoal.isNotEmpty)
                  _buildCard(
                    icon: Icons.flag,
                    title: "YOUR GOAL",
                    content: _currentGoal,
                  ),
                const SizedBox(height: 20),
                // Activities card
                if (_currentActivities.isNotEmpty)
                  _buildCard(
                    icon: Icons.star,
                    title: _isGoalCompleted
                        ? "COMPLETED ACTIVITIES"
                        : "TODAY'S ACTIVITIES (5 points each)",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...List.generate(_currentActivities.length, (index) {
                          return _buildActivityItem(
                            _currentActivities[index]['title'],
                            index,
                          );
                        }),
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
                              backgroundColor: colorGreenDark,
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
        onPressed: () {
          _onItemTapped(2);
        },
        backgroundColor: colorGreenDark,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.home,
          color: Colors.white,
          size: 28,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildActivityItem(String text, int index) {
    bool isCompletedToday = _currentActivities[index]['completed'] ?? false;
    DateTime? lastCompleted = _currentActivities[index]['lastCompletedDate'];
    bool canCompleteToday = !isCompletedToday && !_isGoalCompleted;

    // Check if it was completed on a previous day
    if (!isCompletedToday && lastCompleted != null) {
      DateTime now = DateTime.now();
      if (lastCompleted.day != now.day ||
          lastCompleted.month != now.month ||
          lastCompleted.year != now.year) {
        canCompleteToday = true;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorPinkish.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isCompletedToday,
            onChanged: canCompleteToday ? (value) => _toggleActivity(index) : null,
            activeColor: colorGreenDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isCompletedToday ? Colors.grey : colorGreenDark,
                fontSize: 13,
                decoration: isCompletedToday
                    ? TextDecoration.lineThrough
                    : null,
                decorationColor: colorGreenDark,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorGreenDark.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars, size: 12, color: colorGreenDark),
                const SizedBox(width: 2),
                Text(
                  '5',
                  style: const TextStyle(
                    color: colorGreenDark,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    String? content,
    Widget? child,
  }) {
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
                  color: colorPinkish.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colorGreenDark, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: colorGreenDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
                color: colorGreenDark,
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
            color: isSelected ? colorGreenDark : Colors.grey,
            size: isSelected ? 24 : 22,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? colorGreenDark : Colors.grey,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}