// ========== lib/services/notification_service.dart ==========
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';

class NotificationService {
final FlutterLocalNotificationsPlugin _localNotifications =
FlutterLocalNotificationsPlugin();

String? _userId;

Future<void> initNotifications(String userId) async {
_userId = userId;
await initLocalNotifications();
print('✅ تم تهيئة الاشعارات للمستخدم: $userId');
}

Future<void> initLocalNotifications() async {
try {
const AndroidInitializationSettings androidSettings =
AndroidInitializationSettings('@mipmap/ic_launcher');

const DarwinInitializationSettings iosSettings =
DarwinInitializationSettings();

const InitializationSettings initSettings = InitializationSettings(
android: androidSettings,
iOS: iosSettings,
);

await _localNotifications.initialize(settings: initSettings);

const AndroidNotificationChannel channel = AndroidNotificationChannel(
'local_notifications_channel',
'Bur',
description: 'إشعارات تطبيق Bur',
importance: Importance.high,
enableVibration: true,
playSound: true,
);

await _localNotifications
    .resolvePlatformSpecificImplementation<
AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(channel);

print('✅ تم تهيئة الاشعارات المحلية مع اسم التطبيق: Bur');
} catch (e) {
print('❌ خطأ في تهيئة الاشعارات: $e');
}
}

Future<ByteData?> loadImageFromAssets(String path) async {
try {
final ByteData data = await rootBundle.load(path);
return data;
} catch (e) {
print('⚠️ خطأ في تحميل الصورة من assets: $e');
return null;
}
}

Future<void> showLocalNotificationOnly({
required String title,
required String body,
String? payload,
}) async {
try {
ByteData? imageData = await loadImageFromAssets('assets/icon.jpeg');

AndroidNotificationDetails androidDetails;

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
channelDescription: 'إشعارات تطبيق Bur',
importance: Importance.high,
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
channelDescription: 'إشعارات تطبيق Bur',
importance: Importance.high,
color: Color(0xFF7f9461),
largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
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
payload: payload,
);

print('✅ تم عرض الاشعار المحلي: $title');
} catch (e) {
print('❌ خطأ في عرض الاشعار: $e');
}
}

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
'title': 'Bur - $title',
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

