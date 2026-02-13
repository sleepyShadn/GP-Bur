import 'package:flutter/material.dart';

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

  // Sample data for goals and activities
  final List<Goal> goals = [
    Goal(
      title: "Mental Wellness",
      description: "Improve mental health and reduce stress",
      activities: [
        Activity(title: "Meditate for 10 minutes", isCompleted: false),
        Activity(title: "Write in gratitude journal", isCompleted: true),
        Activity(title: "Practice deep breathing", isCompleted: false),
      ],
    ),
    Goal(
      title: "Physical Health",
      description: "Stay active and maintain fitness",
      activities: [
        Activity(title: "30-minute morning walk", isCompleted: true),
        Activity(title: "Drink 8 glasses of water", isCompleted: false),
        Activity(title: "Stretching exercises", isCompleted: false),
      ],
    ),
    Goal(
      title: "Personal Growth",
      description: "Learn new skills and grow personally",
      activities: [
        Activity(title: "Read 20 pages of a book", isCompleted: false),
        Activity(title: "Practice a new language", isCompleted: false),
        Activity(title: "Work on a creative project", isCompleted: true),
      ],
    ),
    Goal(
      title: "Social Connections",
      description: "Strengthen relationships and social bonds",
      activities: [
        Activity(title: "Call a friend or family member", isCompleted: true),
        Activity(title: "Plan a social activity", isCompleted: false),
        Activity(title: "Send a thoughtful message", isCompleted: false),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Goals & Activities'),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: goals.length,
            itemBuilder: (context, index) {
              return _buildGoalCard(goals[index]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard(Goal goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorWhite.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: colorGreenDark.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal Header
            Row(
              children: [
                Icon(
                  Icons.flag,
                  color: colorGreenDark,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: TextStyle(
                          color: colorGreenDark,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        goal.description,
                        style: TextStyle(
                          color: colorGreenDark.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorGreenLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${goal.completedActivitiesCount}/${goal.activities.length}",
                    style: TextStyle(
                      color: colorGreenDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Activities List
            Column(
              children: goal.activities.map((activity) {
                return _buildActivityItem(activity, goal);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Activity activity, Goal goal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Checkbox(
            value: activity.isCompleted,
            onChanged: (value) {
              setState(() {
                activity.isCompleted = value ?? false;
              });
            },
            activeColor: colorGreenDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activity.title,
              style: TextStyle(
                color: colorGreenDark,
                fontSize: 16,
                decoration:
                    activity.isCompleted ? TextDecoration.lineThrough : null,
                decorationColor: colorGreenDark,
                decorationThickness: 2,
              ),
            ),
          ),
          if (activity.isCompleted)
            Icon(
              Icons.check_circle,
              color: colorGreenDark,
              size: 20,
            ),
        ],
      ),
    );
  }
}

class Goal {
  final String title;
  final String description;
  final List<Activity> activities;

  Goal({
    required this.title,
    required this.description,
    required this.activities,
  });

  int get completedActivitiesCount {
    return activities.where((activity) => activity.isCompleted).length;
  }
}

class Activity {
  final String title;
  bool isCompleted;

  Activity({
    required this.title,
    required this.isCompleted,
  });
}
