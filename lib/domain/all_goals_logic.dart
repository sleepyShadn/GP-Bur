// ========== lib/domain/all_goals_logic.dart ==========
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Pre-parsed analysis row for the all-goals list (avoids heavy work in [build]).
class AnalysisCardModel {
  AnalysisCardModel({
    required this.analysisId,
    required this.goal,
    required this.professionalEscalation,
    required this.durationDays,
    required this.isGoalCompleted,
    required this.isExpired,
    required this.analysisDateStr,
    required this.activities,
    required this.todayKey,
  });

  final String analysisId;
  final String goal;
  final bool professionalEscalation;
  final int durationDays;
  final bool isGoalCompleted;
  final bool isExpired;
  final String analysisDateStr;
  final List<Activity> activities;
  final String todayKey;

  int get todayCompletedCount =>
      activities.where((Activity a) => a.isCompletedToday(todayKey)).length;

  static AnalysisCardModel fromFirestore(
    String analysisId,
    Map<String, dynamic> data,
  ) {
    final DateTime now = DateTime.now();
    final String todayKey = '${now.year}-${now.month}-${now.day}';

    final Timestamp? expiryTimestamp = data['goalExpiryDate'] as Timestamp?;
    final int durationDays = (data['goalDurationDays'] as num?)?.toInt() ?? 5;
    bool isGoalCompleted = data['isGoalCompleted'] == true;

    final DateTime? expiryDate = expiryTimestamp?.toDate();
    final bool isExpired =
        expiryDate != null && now.isAfter(expiryDate);
    if (isExpired && !isGoalCompleted) {
      isGoalCompleted = true;
    }

    final List<dynamic> activitiesData =
        data['activities'] as List<dynamic>? ?? <dynamic>[];
    final List<Activity> activities = <Activity>[];
    for (final dynamic raw in activitiesData) {
      if (raw is! Map) continue;
      final Map<String, dynamic> act = Map<String, dynamic>.from(raw);
      activities.add(
        Activity(
          title: act['title'] as String? ?? 'Unknown activity',
          isCompleted: act['completed'] == true,
          points: (act['points'] as num?)?.toInt() ?? 5,
          activityId: act['activityId'] as String? ?? '',
          lastCompletedDate: act['lastCompletedDate'] is Timestamp
              ? (act['lastCompletedDate'] as Timestamp).toDate()
              : null,
          dailyHistory: act['dailyHistory'] is Map
              ? Map<String, bool>.from(
                  (act['dailyHistory'] as Map).map(
                    (dynamic k, dynamic v) =>
                        MapEntry(k.toString(), v == true),
                  ),
                )
              : <String, bool>{},
        ),
      );
    }

    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
    String analysisDateStr = '';
    if (timestamp != null) {
      final DateTime d = timestamp.toDate();
      analysisDateStr = '${d.day}/${d.month}/${d.year}';
    }

    return AnalysisCardModel(
      analysisId: analysisId,
      goal: data['goal'] as String? ?? 'No goal set',
      professionalEscalation: data['professionalEscalation'] == true,
      durationDays: durationDays,
      isGoalCompleted: isGoalCompleted,
      isExpired: isExpired,
      analysisDateStr: analysisDateStr,
      activities: activities,
      todayKey: todayKey,
    );
  }
}

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

  Widget buildAnalysisCard(
    BuildContext context,
    AnalysisCardModel model,
    void Function(String analysisId, int index, bool newValue) onToggle, {
    Map<String, bool>? optimisticTodayByKey,
  }) {
    final String analysisId = model.analysisId;
    final String goal = model.goal;
    final bool professionalEscalation = model.professionalEscalation;
    final int durationDays = model.durationDays;
    final bool isGoalCompleted = model.isGoalCompleted;
    final bool isExpired = model.isExpired;
    final String analysisDateStr = model.analysisDateStr;
    final List<Activity> activities = model.activities;
    final String todayKey = model.todayKey;
    final int todayCompletedCount = model.todayCompletedCount;

    bool isCompletedTodayAt(int index) {
      final String key = '$analysisId-$index';
      if (optimisticTodayByKey != null && optimisticTodayByKey.containsKey(key)) {
        return optimisticTodayByKey[key]!;
      }
      if (index >= activities.length) return false;
      return activities[index].isCompletedToday(todayKey);
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
              for (int index = 0; index < activities.length; index++)
                _buildActivityItem(
                  context,
                  activities[index],
                  analysisId,
                  index,
                  isGoalCompleted,
                  isExpired,
                  onToggle,
                  isCompletedToday: isCompletedTodayAt(index),
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
    void Function(String, int, bool) onToggle, {
    required bool isCompletedToday,
  }) {
    final DateTime? lastCompleted = activity.lastCompletedDate;
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

  bool isCompletedToday(String todayKey) => dailyHistory[todayKey] == true;
}