// ========== lib/domain/all_goals_logic.dart ==========
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AllGoalsLogic {
  final Color colorPinkish = const Color(0xFFE7CCCC);
  final Color colorCream = const Color(0xFFEDE8DC);
  final Color colorGreenDark = const Color(0xff7f9461);
  final Color colorGreenLight = const Color(0xFFC1CFA1);
  final Color colorWhite = Colors.white;

  Widget buildNoUserWidget(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle, size: 80, color: colorGreenDark.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No user logged in', style: TextStyle(color: Color(0xff7f9461), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Please log in to view your goals and activities',
              style: TextStyle(color: colorGreenDark.withOpacity(0.7), fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildErrorWidget(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red.withOpacity(0.7)),
          const SizedBox(height: 16),
          const Text('Error loading data', style: TextStyle(color: Color(0xff7f9461), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyWidget(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, size: 80, color: colorGreenDark.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No analyses yet', style: TextStyle(color: Color(0xff7f9461), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Complete your first mood analysis to see goals and activities',
              style: TextStyle(color: colorGreenDark.withOpacity(0.7), fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAnalysisCard(BuildContext context, Map<String, dynamic> data, Function(String, int, bool) onToggle) {
    final bool professionalEscalation = data['professionalEscalation'] == true;
    String goal = data['goal'] ?? 'No goal set';
    String analysisId = data['analysisId'] ?? '';

    Timestamp? startTimestamp = data['goalStartDate'];
    Timestamp? expiryTimestamp = data['goalExpiryDate'];
    int? durationDays = data['goalDurationDays'] ?? 5;
    bool isGoalCompleted = data['isGoalCompleted'] ?? false;

    DateTime? expiryDate = expiryTimestamp?.toDate();
    DateTime now = DateTime.now();
    bool isExpired = expiryDate != null && now.isAfter(expiryDate);

    if (isExpired && !isGoalCompleted) {
      isGoalCompleted = true;
    }

    List<dynamic> activitiesData = data['activities'] ?? [];
    List<Activity> activities = [];

    for (var act in activitiesData) {
      activities.add(Activity(
        title: act['title'] ?? 'Unknown activity',
        isCompleted: act['completed'] ?? false,
        points: act['points'] ?? 5,
        activityId: act['activityId'] ?? '',
        lastCompletedDate: act['lastCompletedDate'] != null ? (act['lastCompletedDate'] as Timestamp).toDate() : null,
        dailyHistory: act['dailyHistory'] != null ? Map<String, bool>.from(act['dailyHistory']) : {},
      ));
    }

    int todayCompletedCount = 0;
    String todayKey = '${now.year}-${now.month}-${now.day}';
    for (var activity in activities) {
      if (activity.dailyHistory[todayKey] == true) {
        todayCompletedCount++;
      }
    }

    Timestamp? timestamp = data['timestamp'];
    String analysisDateStr = '';
    if (timestamp != null) {
      DateTime analysisDate = timestamp.toDate();
      analysisDateStr = '${analysisDate.day}/${analysisDate.month}/${analysisDate.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: colorWhite.withOpacity(0.95),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: colorGreenDark.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 5)),
        ],
        border: Border.all(
          color: isGoalCompleted ? colorGreenDark : colorGreenLight,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (analysisDateStr.isNotEmpty)
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: colorGreenDark.withOpacity(0.5)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            analysisDateStr,
                            style: TextStyle(color: colorGreenDark.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                Flexible(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isGoalCompleted ? colorGreenDark.withOpacity(0.2) : (isExpired ? Colors.orange.withOpacity(0.2) : colorGreenLight.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isGoalCompleted ? Icons.check_circle : (isExpired ? Icons.timer_off : Icons.timer),
                          size: 14,
                          color: isGoalCompleted ? colorGreenDark : (isExpired ? Colors.orange : colorGreenDark),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            isGoalCompleted ? 'Completed' : (isExpired ? 'Expired' : '$durationDays days'),
                            style: TextStyle(
                              color: isGoalCompleted ? colorGreenDark : (isExpired ? Colors.orange : colorGreenDark),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorGreenLight.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.flag_rounded, color: colorGreenDark, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        professionalEscalation ? 'Care plan' : 'Your goal',
                        style: TextStyle(
                          color: colorGreenDark.withOpacity(0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        goal,
                        style: TextStyle(
                          color: colorGreenDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!professionalEscalation && activities.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.star, color: colorGreenDark, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Suggested activities',
                            style: TextStyle(
                              color: colorGreenDark,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isGoalCompleted && !isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorGreenLight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Today: $todayCompletedCount/${activities.length}',
                        style: TextStyle(
                          color: colorGreenDark,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final Activity activity = activities[index];
                  return _buildActivityItem(
                    context,
                    activity,
                    analysisId,
                    index,
                    isGoalCompleted,
                    isExpired,
                    onToggle,
                  );
                },
              ),
            ],
            if (isGoalCompleted || isExpired)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: colorGreenDark.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(isGoalCompleted ? Icons.celebration : Icons.info_outline, color: colorGreenDark, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isGoalCompleted
                            ? 'Goal completed! Great job on finishing all activities within the $durationDays-day period.'
                            : 'This goal period has ended. You can no longer complete activities for this analysis.',
                        style: TextStyle(color: colorGreenDark, fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
      BuildContext context,
      Activity activity,
      String analysisId,
      int index,
      bool isGoalCompleted,
      bool isExpired,
      Function(String, int, bool) onToggle,
      ) {
    DateTime now = DateTime.now();
    String todayKey = '${now.year}-${now.month}-${now.day}';
    bool isCompletedToday = activity.dailyHistory[todayKey] == true;
    DateTime? lastCompleted = activity.lastCompletedDate;
    final bool canToggleToday = !isGoalCompleted && !isExpired;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canToggleToday
            ? () => onToggle(analysisId, index, !isCompletedToday)
            : null,
        borderRadius: BorderRadius.circular(15),
        child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorPinkish.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isCompletedToday ? colorGreenDark : Colors.transparent, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompletedToday ? colorGreenDark : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: canToggleToday ? colorGreenDark : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: isCompletedToday ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: TextStyle(
                        color: isCompletedToday ? Colors.grey : colorGreenDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: isCompletedToday ? TextDecoration.lineThrough : null,
                        decorationColor: colorGreenDark,
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
                            Icon(Icons.history, size: 12, color: colorGreenDark.withOpacity(0.5)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Last: ${lastCompleted.day}/${lastCompleted.month}',
                                style: TextStyle(color: colorGreenDark.withOpacity(0.5), fontSize: 10),
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
                  color: isCompletedToday ? colorGreenDark : colorGreenLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars, size: 14, color: isCompletedToday ? Colors.white : colorGreenDark),
                    const SizedBox(width: 2),
                    Text(
                      '${activity.points}',
                      style: TextStyle(color: isCompletedToday ? Colors.white : colorGreenDark, fontSize: 12, fontWeight: FontWeight.bold),
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
                  Icon(Icons.check_circle, size: 14, color: colorGreenDark.withOpacity(0.7)),
                  const SizedBox(width: 4),
                  const Flexible(
                    child: Text('Completed today', style: TextStyle(color: Color(0xff7f9461), fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
        ],
      ),
        ),
      ),
    );
  }

}

class Activity {
  final String title;
  bool isCompleted;
  final int points;
  final String activityId;
  final DateTime? lastCompletedDate;
  final Map<String, bool> dailyHistory;

  Activity({
    required this.title,
    required this.isCompleted,
    required this.points,
    required this.activityId,
    this.lastCompletedDate,
    required this.dailyHistory,
  });
}