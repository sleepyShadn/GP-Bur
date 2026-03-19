// ========== lib/data/home_data.dart ==========
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../services/notification_service.dart';




class HomeData {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  final String _apiKey = "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";

  StreamSubscription<DocumentSnapshot>? _analysisSubscription;

  Future<Map<String, dynamic>?> getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      return {'uid': user.uid, 'email': user.email};
    }
    return null;
  }

  Future<void> initNotifications(String userId) async {
    await _notificationService.initNotifications(userId);
  }

  void listenToLatestAnalysis(String userId, Function(Map<String, dynamic>?) onData) {
    _analysisSubscription?.cancel();

    _analysisSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('analyses')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;

        DateTime? goalStartDate;
        if (data['goalStartDate'] != null) {
          goalStartDate = (data['goalStartDate'] as Timestamp).toDate();
        }

        DateTime? goalExpiryDate;
        if (data['goalExpiryDate'] != null) {
          goalExpiryDate = (data['goalExpiryDate'] as Timestamp).toDate();
        }

        List<Map<String, dynamic>> activities = [];
        if (data['activities'] != null) {
          activities = (data['activities'] as List).map((activity) {
            DateTime? lastCompletedDate;
            if (activity['lastCompletedDate'] != null) {
              lastCompletedDate = (activity['lastCompletedDate'] as Timestamp).toDate();
            }

            Map<String, dynamic> dailyHistory = {};
            if (activity['dailyHistory'] != null) {
              dailyHistory = Map<String, dynamic>.from(activity['dailyHistory']);
            }

            return {
              'title': activity['title'],
              'points': activity['points'],
              'completed': activity['completed'] ?? false,
              'activityId': activity['activityId'] ?? '',
              'lastCompletedDate': lastCompletedDate,
              'dailyHistory': dailyHistory,
            };
          }).toList();
        }

        onData({
          'analysisId': doc.id,
          'classification': data['classification'] ?? '',
          'goal': data['goal'] ?? '',
          'goalStartDate': goalStartDate,
          'goalDurationDays': data['goalDurationDays'],
          'goalExpiryDate': goalExpiryDate,
          'isGoalCompleted': data['isGoalCompleted'] ?? false,
          'activities': activities,
        });
      } else {
        onData(null);
      }
    }, onError: (error) {
      print('Error listening to analysis: $error');
      onData(null);
    }) as StreamSubscription<DocumentSnapshot<Object?>>?;
  }

  void cancelSubscription() {
    _analysisSubscription?.cancel();
  }

  Future<int> loadUserPoints(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.get('points') ?? 0;
    } catch (e) {
      print('Error loading points: $e');
      return 0;
    }
  }

  Future<List<String>> loadRecentDiagnoses(String userId) async {
    try {
      QuerySnapshot analysisSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('analyses')
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();

      return analysisSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['classification']?.toString() ?? '')
          .where((classification) => classification.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error loading recent diagnoses: $e');
      return [];
    }
  }

  Future<int> checkTodayAnalysisCount(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      QuerySnapshot todayAnalyses = await _firestore
          .collection('users')
          .doc(userId)
          .collection('analyses')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();

      return todayAnalyses.docs.length;
    } catch (e) {
      print('Error checking today analysis count: $e');
      return 0;
    }
  }

  Future<bool> isValidText(String text) async {
    if (text.trim().isEmpty) return false;

    try {
      String prompt = '''
Analyze if the following text is meaningful, coherent, and not random gibberish. 
Return ONLY "valid" if the text appears to be a real, coherent sentence or phrase in English that a person would actually say about their feelings or mental state.
Return ONLY "invalid" if the text appears to be random characters, keyboard mash, repeated letters, or nonsensical input.

Examples of valid text:
- "I'm feeling anxious today"
- "I had a great day at work"
- "feeling sad and lonely"

Examples of invalid text:
- "hdjsjaih"
- "fjkdjdjkdfjlkj"
- "aaaaaaa"

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
            {'role': 'system', 'content': 'You are a text validator. Return only "valid" or "invalid".'},
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

  Future<bool> checkForPositiveSentiment(String text) async {
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

  Future<Map<String, dynamic>?> analyzeMood(String text, List<String> classifications) async {
    try {
      String prompt = '''
Based on the following text, analyze the user's mental state and provide:
1. Classification: Choose exactly ONE from these categories: ${classifications.join(', ')}
2. Goal: Create a personalized goal based on the classification (one sentence)
3. Duration: Suggest a duration for completing this goal. Choose either 5 or 6 days oir any number of days as appropriate depoend text.
4. Activities: Generate 4 specific, actionable activities.

Text to analyze: "$text"

Return in JSON format:
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
            {'role': 'system', 'content': 'You are a mental health assistant. Return valid JSON only.'},
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

        if (classifications.contains(result['classification'].toString().toLowerCase())) {
          List<Map<String, dynamic>> activities = (result['activities'] as List).map((activity) {
            return {
              'title': activity['title'],
              'points': activity['points'] ?? 5,
              'completed': false,
              'activityId': DateTime.now().millisecondsSinceEpoch.toString() + activity['title'],
              'lastCompletedDate': null,
              'dailyHistory': {},
            };
          }).toList();

          return {
            'classification': result['classification'].toString().toLowerCase(),
            'goal': result['goal'],
            'duration': result['duration'] ?? 5,
            'activities': activities,
          };
        }
      }
    } catch (e) {
      print('Error analyzing mood: $e');
    }
    return null;
  }

  Future<bool> saveAnalysisToFirestore({
    required String userId,
    required String text,
    required String classification,
    required String goal,
    required DateTime startDate,
    required int duration,
    required List<Map<String, dynamic>> activities,
  }) async {
    if (userId.isEmpty) return false;

    try {
      DateTime expiryDate = startDate.add(Duration(days: duration));
      String analysisId = DateTime.now().millisecondsSinceEpoch.toString();

      Map<String, dynamic> analysisData = {
        'timestamp': FieldValue.serverTimestamp(),
        'text': text,
        'classification': classification,
        'goal': goal,
        'goalStartDate': startDate,
        'goalDurationDays': duration,
        'goalExpiryDate': expiryDate,
        'isGoalCompleted': false,
        'activities': activities.map((activity) => {
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
          .doc(userId)
          .collection('analyses')
          .doc(analysisId)
          .set(analysisData);

      return true;
    } catch (e) {
      print('Error saving analysis: $e');
      return false;
    }
  }

  Future<bool> checkForRecurringDiagnosis(String userId, String newDiagnosis, List<String> recentDiagnoses) async {
    if (userId.isEmpty || newDiagnosis.isEmpty) return false;

    recentDiagnoses.insert(0, newDiagnosis);
    if (recentDiagnoses.length > 3) {
      recentDiagnoses = recentDiagnoses.sublist(0, 3);
    }

    if (recentDiagnoses.length == 3 && recentDiagnoses.every((d) => d == newDiagnosis)) {
      await _notificationService.showLocalNotificationOnly(
        title: 'Checking in',
        body: 'It looks like it\'s been a heavy few days. When you have a moment, let\'s take a breath and check in together.',
        payload: 'recurring_diagnosis',
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Early Warning Alert',
        'body': 'Our system identified a recurring pattern in your recent logs.',
        'type': 'recurring_diagnosis',
        'diagnosis': newDiagnosis,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      return true;
    }
    return false;
  }

  Future<bool> toggleActivity(String userId, String analysisId, int index, Map<String, dynamic> activity) async {
    try {
      DocumentSnapshot analysisDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('analyses')
          .doc(analysisId)
          .get();

      if (analysisDoc.exists) {
        var data = analysisDoc.data() as Map<String, dynamic>;
        List<dynamic> activities = List.from(data['activities'] ?? []);

        Timestamp? expiryTimestamp = data['goalExpiryDate'];
        bool isGoalCompleted = data['isGoalCompleted'] ?? false;

        if (expiryTimestamp != null) {
          DateTime expiryDate = expiryTimestamp.toDate();
          if (DateTime.now().isAfter(expiryDate) || isGoalCompleted) {
            return false;
          }
        }

        if (index < activities.length) {
          DateTime now = DateTime.now();
          String todayKey = '${now.year}-${now.month}-${now.day}';

          activities[index]['completed'] = true;
          activities[index]['lastCompletedDate'] = Timestamp.fromDate(now);

          if (activities[index]['dailyHistory'] == null) {
            activities[index]['dailyHistory'] = {};
          }
          activities[index]['dailyHistory'][todayKey] = true;

          await _firestore
              .collection('users')
              .doc(userId)
              .collection('analyses')
              .doc(analysisId)
              .update({'activities': activities});

          int points = activities[index]['points'] ?? 5;
          await _firestore.collection('users').doc(userId).update({
            'points': FieldValue.increment(points),
          });

          return true;
        }
      }
    } catch (e) {
      print('Error updating activity: $e');
    }
    return false;
  }
}