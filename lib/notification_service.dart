import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  String? _userId;

  // دالة للتوافق مع الكود القديم
  Future<void> initNotifications(String userId) async {
    _userId = userId;
    await initLocalNotifications();
    print('✅ تم تهيئة الاشعارات للمستخدم: $userId');
  }

  // تهيئة الاشعارات المحلية
  Future<void> initLocalNotifications() async {
    try {
      // تهيئة إعدادات الأندرويد
      const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      // تهيئة إعدادات iOS
      const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings();

      // دمج الإعدادات
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // ✅ التصحيح النهائي: استخدام named parameter 'settings'
      await _localNotifications.initialize(
        settings: initSettings,  // 👈 هذا هو الحل
      );

      // إنشاء قناة للأندرويد
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'local_notifications_channel',
        'الإشعارات المحلية',
        description: 'قناة للإشعارات المحلية',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      print('✅ تم تهيئة الاشعارات المحلية');
    } catch (e) {
      print('❌ خطأ في تهيئة الاشعارات: $e');
    }
  }

  // دالة عرض الاشعار المحلي فقط
  Future<void> showLocalNotificationOnly({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'local_notifications_channel',
            'الإشعارات المحلية',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
      print('✅ تم عرض الاشعار المحلي: $title');
    } catch (e) {
      print('❌ خطأ في عرض الاشعار: $e');
    }
  }

  // إنشاء اشعار داخلي في Firestore
  Future<void> createInAppNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? diagnosis,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'diagnosis': diagnosis,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
      print('✅ تم إنشاء اشعار داخلي');
    } catch (e) {
      print('❌ خطأ في إنشاء الاشعار الداخلي: $e');
    }
  }
}