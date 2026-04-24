import 'package:appforhumman/presentation/notifications_screen.dart';
import 'package:appforhumman/presentation/splash_screen.dart';
import 'package:appforhumman/services/local_timezone_config.dart';
import 'package:appforhumman/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await configureLocalTimeZone();

  final NotificationService notificationService = NotificationService();
  await notificationService.initLocalNotifications();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    NotificationService().setOpenNotificationsInboxHandler(_openNotificationsInboxFromSystem);
  }

  @override
  void dispose() {
    NotificationService().setOpenNotificationsInboxHandler(null);
    super.dispose();
  }

  void _openNotificationsInboxFromSystem() {
    final NavigatorState? nav = _navigatorKey.currentState;
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (nav == null || uid == null || uid.isEmpty) return;
    nav.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(userId: uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
