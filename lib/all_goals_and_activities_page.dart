import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AllGoalsAndActivitiesPage extends StatefulWidget {
  const AllGoalsAndActivitiesPage({super.key});

  @override
  State<AllGoalsAndActivitiesPage> createState() =>
      _AllGoalsAndActivitiesPageState();
}

class _AllGoalsAndActivitiesPageState extends State<AllGoalsAndActivitiesPage> {
  static const Color colorPinkish = Color(0xFFE7CCCC);
  static const Color colorCream = Color(0xFFEDE8DC);
  static const Color colorGreenDark = Color(0xff7f9461);
  static const Color colorGreenLight = Color(0xFFC1CFA1);
  static const Color colorWhite = Colors.white;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _userId = '';
  bool _isLoading = true;

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
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // دالة لجلب جميع التحليلات من Firestore
  Stream<QuerySnapshot> _getAnalysesStream() {
    if (_userId.isEmpty) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('analyses')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All Goals & Activities',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorGreenDark,
        foregroundColor: colorWhite,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorPinkish, colorCream, colorGreenLight],
            stops: [0.1, 0.5, 1.0],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: colorGreenDark))
            : _userId.isEmpty
            ? _buildNoUserWidget()
            : _buildAnalysesList(),
      ),
    );
  }

  Widget _buildNoUserWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle,
            size: 80,
            color: colorGreenDark.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No user logged in',
            style: TextStyle(
              color: colorGreenDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please log in to view your goals and activities',
            style: TextStyle(
              color: colorGreenDark.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getAnalysesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red.withOpacity(0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading data',
                  style: TextStyle(
                    color: colorGreenDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: colorGreenDark),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 80,
                  color: colorGreenDark.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No analyses yet',
                  style: TextStyle(
                    color: colorGreenDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete your first mood analysis to see goals and activities',
                  style: TextStyle(
                    color: colorGreenDark.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // عرض جميع التحليلات
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            // استخراج البيانات
            String classification = data['classification'] ?? 'Unknown';
            String goal = data['goal'] ?? 'No goal set';
            List<dynamic> activitiesData = data['activities'] ?? [];

            // تحويل الأنشطة إلى كائنات Activity
            List<Activity> activities = activitiesData.map((act) {
              return Activity(
                title: act['title'] ?? 'Unknown activity',
                isCompleted: act['completed'] ?? false,
                points: act['points'] ?? 5,
                activityId: act['activityId'] ?? '',
              );
            }).toList();

            // تنسيق التاريخ
            Timestamp? timestamp = data['timestamp'];
            String dateStr = '';
            if (timestamp != null) {
              DateTime date = timestamp.toDate();
              dateStr = '${date.day}/${date.month}/${date.year}';
            }

            return _buildAnalysisCard(
              classification: classification,
              goal: goal,
              activities: activities,
              date: dateStr,
              text: data['text'] ?? '',
              analysisId: doc.id,
            );
          },
        );
      },
    );
  }

  Widget _buildAnalysisCard({
    required String classification,
    required String goal,
    required List<Activity> activities,
    required String date,
    required String text,
    required String analysisId,
  }) {
    // حساب عدد الأنشطة المكتملة
    int completedCount = activities.where((a) => a.isCompleted).length;

    // الحصول على أيقونة ولون حسب التصنيف
    Map<String, dynamic> classificationStyle = _getClassificationStyle(classification);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: colorWhite.withOpacity(0.95),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: colorGreenDark.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: classificationStyle['color'] ?? colorGreenDark,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // التاريخ
            if (date.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.calendar_today, size: 14, color: colorGreenDark.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(
                    date,
                    style: TextStyle(
                      color: colorGreenDark.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

            // التصنيف
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: classificationStyle['color']?.withOpacity(0.15) ?? colorPinkish,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    classificationStyle['icon'] ?? Icons.psychology,
                    color: classificationStyle['color'] ?? colorGreenDark,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classification.toUpperCase(),
                        style: TextStyle(
                          color: classificationStyle['color'] ?? colorGreenDark,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        goal,
                        style: TextStyle(
                          color: colorGreenDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // عداد الأنشطة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorGreenLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: colorGreenDark),
                      const SizedBox(width: 4),
                      Text(
                        "$completedCount/${activities.length}",
                        style: TextStyle(
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

            const SizedBox(height: 16),

            // النص الأصلي
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorPinkish.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote, size: 18, color: colorGreenDark.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"$text"',
                      style: TextStyle(
                        color: colorGreenDark.withOpacity(0.8),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // عنوان الأنشطة
            Row(
              children: [
                Icon(Icons.star, color: colorGreenDark, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Activities (5 points each)',
                  style: TextStyle(
                    color: colorGreenDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // قائمة الأنشطة
            Column(
              children: activities.asMap().entries.map((entry) {
                int index = entry.key;
                Activity activity = entry.value;
                return _buildActivityItem(
                  activity: activity,
                  analysisId: analysisId,
                  activityIndex: index,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem({
    required Activity activity,
    required String analysisId,
    required int activityIndex,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorPinkish.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: activity.isCompleted ? colorGreenDark : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Checkbox مخصص
          GestureDetector(
            onTap: () => _toggleActivity(analysisId, activityIndex, !activity.isCompleted),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: activity.isCompleted ? colorGreenDark : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: colorGreenDark,
                  width: 2,
                ),
              ),
              child: activity.isCompleted
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
                  activity.title,
                  style: TextStyle(
                    color: colorGreenDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: activity.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: colorGreenDark,
                    decorationThickness: 2,
                  ),
                ),
              ],
            ),
          ),
          // النقاط
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: activity.isCompleted
                  ? colorGreenDark
                  : colorGreenLight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.stars,
                  size: 14,
                  color: activity.isCompleted ? Colors.white : colorGreenDark,
                ),
                const SizedBox(width: 2),
                Text(
                  '${activity.points}',
                  style: TextStyle(
                    color: activity.isCompleted ? Colors.white : colorGreenDark,
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

  // دالة لتحديث حالة النشاط
  Future<void> _toggleActivity(String analysisId, int activityIndex, bool newValue) async {
    if (_userId.isEmpty) return;

    try {
      // جلب التحليل الحالي
      DocumentSnapshot analysisDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('analyses')
          .doc(analysisId)
          .get();

      if (analysisDoc.exists) {
        var data = analysisDoc.data() as Map<String, dynamic>;
        List<dynamic> activities = List.from(data['activities'] ?? []);

        // تحديث النشاط المحدد
        if (activityIndex < activities.length) {
          activities[activityIndex]['completed'] = newValue;

          // تحديث في Firestore
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('analyses')
              .doc(analysisId)
              .update({'activities': activities});

          // إذا اكتمل النشاط، أضف النقاط
          if (newValue) {
            int points = activities[activityIndex]['points'] ?? 5;
            await _firestore.collection('users').doc(_userId).update({
              'points': FieldValue.increment(points),
            });
          }

          // تحديث واجهة المستخدم سيحدث تلقائياً عبر StreamBuilder
        }
      }
    } catch (e) {
      print('Error updating activity: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update activity: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // دالة لإرجاع الأيقونة واللون حسب التصنيف
  Map<String, dynamic> _getClassificationStyle(String classification) {
    switch (classification.toLowerCase()) {
      case 'anxiety':
        return {
          'icon': Icons.spa,
          'color': Colors.purple,
        };
      case 'depression':
        return {
          'icon': Icons.cloud,
          'color': Colors.blue,
        };
      case 'anorexia':
        return {
          'icon': Icons.restaurant,
          'color': Colors.orange,
        };
      case 'bipolar':
        return {
          'icon': Icons.bolt,
          'color': Colors.red,
        };
      case 'adhd':
        return {
          'icon': Icons.auto_awesome,
          'color': Colors.amber,
        };
      case 'antisocial personality':
        return {
          'icon': Icons.people_outline,
          'color': Colors.teal,
        };
      case 'bulimia':
        return {
          'icon': Icons.fastfood,
          'color': Colors.pink,
        };
      default:
        return {
          'icon': Icons.psychology,
          'color': colorGreenDark,
        };
    }
  }
}

// كلاس النشاط
class Activity {
  final String title;
  bool isCompleted;
  final int points;
  final String activityId;

  Activity({
    required this.title,
    required this.isCompleted,
    required this.points,
    required this.activityId,
  });
}