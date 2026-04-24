import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/garden_care_logic.dart';
import 'local_notification_inbox_store.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  static const String _androidDefaultNotificationIcon = '@mipmap/launcher_icon';

  static const String payloadOpenNotificationsInbox = 'open_notifications_inbox';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _localNotificationsInitialized = false;
  bool _launchDetailsFetched = false;
  bool _didLaunchFromNotificationTap = false;
  bool _coldStartInboxNavigationDone = false;
  DateTime? _lastInboxNavigationAt;
  VoidCallback? _openNotificationsInbox;

  String _inboxUserId = '';

  /// Register navigation to [NotificationsScreen] (e.g. from [MaterialApp] using a [GlobalKey]).
  void setOpenNotificationsInboxHandler(VoidCallback? handler) {
    _openNotificationsInbox = handler;
  }

  Future<void> tryOpenInboxFromNotificationColdStart(String userId) async {
    if (userId.isEmpty) return;
    if (!_launchDetailsFetched) {
      final NotificationAppLaunchDetails? details =
          await _localNotifications.getNotificationAppLaunchDetails();
      _didLaunchFromNotificationTap = details?.didNotificationLaunchApp == true;
      _launchDetailsFetched = true;
    }
    if (!_didLaunchFromNotificationTap || _coldStartInboxNavigationDone) return;
    _coldStartInboxNavigationDone = true;
    requestOpenNotificationsInbox();
  }

  void requestOpenNotificationsInbox() {
    final DateTime now = DateTime.now();
    if (_lastInboxNavigationAt != null &&
        now.difference(_lastInboxNavigationAt!) < const Duration(milliseconds: 900)) {
      return;
    }
    _lastInboxNavigationAt = now;
    _openNotificationsInbox?.call();
  }

  void _onLocalNotificationResponse(NotificationResponse response) {
    requestOpenNotificationsInbox();
  }

  static const List<int> gardenCareNotificationIds = <int>[
    9200,
    9201,
    9202,
    9203,
    9204,
  ];

  Future<void> initNotifications(String userId) async {
    _inboxUserId = userId;
    await initLocalNotifications();
    await requestPostNotificationPermissions();
    debugPrint('NotificationService ready for user: $userId');
  }

  Future<void> initLocalNotifications() async {
    if (_localNotificationsInitialized) return;
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings(_androidDefaultNotificationIcon);

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings();

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationResponse,
      );

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'local_notifications_channel',
        'Bur',
        description: 'Bur app reminders and alerts',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      const AndroidNotificationChannel gardenChannel =
          AndroidNotificationChannel(
        'garden_care_channel',
        'Garden & activities',
        description: 'Gentle reminders to care for your garden and daily activities',
        importance: Importance.defaultImportance,
        enableVibration: true,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(gardenChannel);

      _localNotificationsInitialized = true;
    } catch (e) {
      debugPrint('initLocalNotifications error: $e');
    }
  }

  Future<void> requestPostNotificationPermissions() async {
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('requestPostNotificationPermissions: $e');
    }
  }

  Future<ByteData?> loadImageFromAssets(String path) async {
    try {
      final ByteData data = await rootBundle.load(path);
      return data;
    } catch (e) {
      debugPrint('loadImageFromAssets: $e');
      return null;
    }
  }

  Future<void> showGardenPlantEncouragement({
    required String seedType,
    required String userId,
  }) async {
    final String seedLabel = _englishSeedKindLabel(seedType);
    await showLocalNotificationOnly(
      title: 'Your garden just smiled 🌱',
      body:
          'Planting done — $seedLabel is in the soil. Over the next days, showing up for your daily activities (even one tiny step) is what waters the growth and keeps your garden vibrant. You are on the right track—we are cheering you on!',
      inboxUserId: userId,
    );
  }

  String _englishSeedKindLabel(String seedType) {
    if (seedType.contains('Legendary')) return 'your legendary seeds';
    if (seedType.contains('Rare')) return 'your rare seeds';
    if (seedType.contains('Regular')) return 'your regular seeds';
    return 'your seeds';
  }

  Future<void> showLocalNotificationOnly({
    required String title,
    required String body,
    String? payload,
    /// When null, uses [_inboxUserId] from [initNotifications].
    String? inboxUserId,
    bool persistToInbox = true,
    String? type,
    String? diagnosis,
    String? inboxTitle,
    String? inboxBody,
  }) async {
    try {
      final ByteData? imageData = await loadImageFromAssets('assets/icon.jpeg');

      late final AndroidNotificationDetails androidDetails;

      if (imageData != null) {
        final BigPictureStyleInformation bigPictureStyle =
            BigPictureStyleInformation(
          ByteArrayAndroidBitmap(imageData.buffer.asUint8List()),
          largeIcon: ByteArrayAndroidBitmap(imageData.buffer.asUint8List()),
          contentTitle: 'Bur',
          summaryText: body,
        );

        androidDetails = AndroidNotificationDetails(
          'local_notifications_channel',
          'Bur',
          channelDescription: 'Bur app reminders and alerts',
          importance: Importance.high,
          icon: _androidDefaultNotificationIcon,
          color: const Color(0xFF7f9461),
          styleInformation: bigPictureStyle,
          largeIcon: ByteArrayAndroidBitmap(imageData.buffer.asUint8List()),
          enableVibration: true,
          playSound: true,
          showWhen: true,
          usesChronometer: true,
        );
      } else {
        androidDetails = const AndroidNotificationDetails(
          'local_notifications_channel',
          'Bur',
          channelDescription: 'Bur app reminders and alerts',
          importance: Importance.high,
          color: Color(0xFF7f9461),
          icon: _androidDefaultNotificationIcon,
          largeIcon: DrawableResourceAndroidBitmap(_androidDefaultNotificationIcon),
          enableVibration: true,
          playSound: true,
          showWhen: true,
          usesChronometer: true,
        );
      }

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final String formattedTitle = 'Bur • $title';

      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: formattedTitle,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload ?? payloadOpenNotificationsInbox,
      );

      if (persistToInbox) {
        final String uid = (inboxUserId ?? _inboxUserId).trim();
        if (uid.isNotEmpty) {
          await LocalNotificationInboxStore.instance.append(
            userId: uid,
            title: inboxTitle ?? formattedTitle,
            body: inboxBody ?? body,
            type: type,
            diagnosis: diagnosis,
          );
        }
      }
    } catch (e) {
      debugPrint('showLocalNotificationOnly: $e');
    }
  }

  Future<void> cancelGardenCareSchedules() async {
    for (final int id in gardenCareNotificationIds) {
      await _localNotifications.cancel(id: id);
    }
  }

  Future<void> syncGardenCareScheduledReminders({
    required String userId,
    required int vitality,
    required String lastActivityDayKey,
    required bool hasPlants,
  }) async {
    if (userId.isEmpty) return;

    await cancelGardenCareSchedules();

    final String todayKey = GardenCareLogic.careDayKey(DateTime.now());
    final bool actedToday = lastActivityDayKey == todayKey;
    final bool healthy = actedToday && vitality >= 68;

    if (healthy) {
      return;
    }

    final String plantLine = hasPlants
        ? 'Your planted flowers reflect your daily habits.'
        : 'Your next healthy habit can become your first planted seed.';

    final NotificationDetails details = _gardenScheduledDetails();

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    Future<void> scheduleIfFuture(
      int id,
      tz.TZDateTime when,
      String title,
      String body,
    ) async {
      if (!when.isAfter(now.add(const Duration(seconds: 20)))) return;
      try {
        await _localNotifications.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payloadOpenNotificationsInbox,
        );
      } catch (e) {
        debugPrint('zonedSchedule id=$id error: $e');
      }
    }

    if (!actedToday || vitality < 72) {
      final tz.TZDateTime evening = _todayAt(19, 30);
      await scheduleIfFuture(
        9200,
        evening,
        'Habit check-in',
        actedToday
            ? 'Your streak is soft today. One small activity keeps momentum. $plantLine'
            : 'You still have one small habit waiting today. $plantLine Open Bur when you can.',
      );
    }

    if (vitality < 50) {
      final tz.TZDateTime lunch = _todayAt(13, 15);
      await scheduleIfFuture(
        9201,
        lunch,
        'Tiny habit, big boost',
        'Complete one activity now to restore vitality and protect your growth loop. $plantLine',
      );
    }

    final tz.TZDateTime tomorrowAm = _offsetDayAt(1, 9, 35);
    await scheduleIfFuture(
      9202,
      tomorrowAm,
      'Fresh start for your habits',
      hasPlants
          ? 'Good morning. Water your habits with one small activity and your blooms will show it.'
          : 'Good morning. Start one small activity today, then plant a seed from the shop.',
    );

    if (!actedToday || vitality < 62) {
      final tz.TZDateTime tomorrowPm = _offsetDayAt(1, 19, 15);
      await scheduleIfFuture(
        9203,
        tomorrowPm,
        'Plan one tiny win',
        'If today was busy, choose one doable habit for tomorrow. Consistency grows the garden.',
      );
    }

    if (vitality < 42) {
      final tz.TZDateTime day2 = _offsetDayAt(2, 14, 45);
      await scheduleIfFuture(
        9204,
        day2,
        'Time to restart your streak',
        'Vitality is low, but recovery is simple: complete one activity and begin rebuilding your habit garden.',
      );
    }
  }

  NotificationDetails _gardenScheduledDetails() {
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'garden_care_channel',
      'Garden & activities',
      channelDescription:
          'Gentle reminders to care for your garden and daily activities',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: _androidDefaultNotificationIcon,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(android: android, iOS: ios);
  }

  tz.TZDateTime _todayAt(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    return tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
  }

  tz.TZDateTime _offsetDayAt(int daysFromToday, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime base = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    return base.add(Duration(days: daysFromToday));
  }

  Future<void> createInAppNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? diagnosis,
  }) async {
    try {
      await LocalNotificationInboxStore.instance.append(
        userId: userId,
        title: 'Bur • $title',
        body: body,
        type: type,
        diagnosis: diagnosis,
      );
    } catch (e) {
      debugPrint('createInAppNotification: $e');
    }
  }
}
