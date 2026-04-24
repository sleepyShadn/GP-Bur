// ========== lib/services/garden_care_notification_coordinator.dart ==========
import '../data/garden_care_data.dart';
import 'notification_service.dart';

class GardenCareNotificationCoordinator {
  factory GardenCareNotificationCoordinator() => _singleton;

  GardenCareNotificationCoordinator._();

  static final GardenCareNotificationCoordinator _singleton =
      GardenCareNotificationCoordinator._();

  final GardenCareData _garden = GardenCareData();
  final NotificationService _notifications = NotificationService();

  Future<void> syncForUser(String userId) async {
    if (userId.isEmpty) return;
    final GardenCarePublicState state =
        await _garden.loadReconcileAndDescribe(userId);
    await _notifications.syncGardenCareScheduledReminders(
      userId: userId,
      vitality: state.vitality,
      lastActivityDayKey: state.lastActivityDayKey,
      hasPlants: state.hasPlants,
    );
  }
}
