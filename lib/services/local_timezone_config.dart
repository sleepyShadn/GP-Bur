// ========== lib/services/local_timezone_config.dart ==========
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Future<void> configureLocalTimeZone() async {
  tzdata.initializeTimeZones();
  if (kIsWeb) {
    tz.setLocalLocation(tz.UTC);
    return;
  }
  try {
    final String name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));
  } catch (_) {
    tz.setLocalLocation(tz.UTC);
  }
}
