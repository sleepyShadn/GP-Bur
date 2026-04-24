// ========== lib/services/local_notification_inbox_store.dart ==========
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalInboxNotification {
  const LocalInboxNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAtMs,
    this.read = false,
    this.type,
    this.diagnosis,
  });

  final String id;
  final String title;
  final String body;
  final int createdAtMs;
  final bool read;
  final String? type;
  final String? diagnosis;

  LocalInboxNotification copyWith({
    String? id,
    String? title,
    String? body,
    int? createdAtMs,
    bool? read,
    String? type,
    String? diagnosis,
  }) {
    return LocalInboxNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      read: read ?? this.read,
      type: type ?? this.type,
      diagnosis: diagnosis ?? this.diagnosis,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'createdAtMs': createdAtMs,
        'read': read,
        if (type != null) 'type': type,
        if (diagnosis != null) 'diagnosis': diagnosis,
      };

  static LocalInboxNotification fromJson(Map<String, dynamic> j) {
    return LocalInboxNotification(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      createdAtMs: (j['createdAtMs'] as num?)?.toInt() ?? 0,
      read: j['read'] == true,
      type: j['type'] as String?,
      diagnosis: j['diagnosis'] as String?,
    );
  }
}

/// Persists notification inbox rows in [SharedPreferences] keyed by user id.
class LocalNotificationInboxStore extends ChangeNotifier {
  LocalNotificationInboxStore._();

  static final LocalNotificationInboxStore instance = LocalNotificationInboxStore._();

  static const String _prefsKeyPrefix = 'local_notification_inbox_v1_';
  static const int _maxItems = 300;

  String _key(String userId) => '$_prefsKeyPrefix$userId';

  Future<List<LocalInboxNotification>> loadItems(String userId) async {
    if (userId.isEmpty) return <LocalInboxNotification>[];
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return <LocalInboxNotification>[];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      final List<LocalInboxNotification> out = list
          .map((dynamic e) => LocalInboxNotification.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((LocalInboxNotification n) => n.id.isNotEmpty)
          .toList();
      out.sort((LocalInboxNotification a, LocalInboxNotification b) => b.createdAtMs.compareTo(a.createdAtMs));
      return out;
    } catch (_) {
      return <LocalInboxNotification>[];
    }
  }

  Future<int> unreadCount(String userId) async {
    final List<LocalInboxNotification> items = await loadItems(userId);
    return items.where((LocalInboxNotification e) => !e.read).length;
  }

  Future<void> _save(String userId, List<LocalInboxNotification> items) async {
    if (userId.isEmpty) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(items.map((LocalInboxNotification e) => e.toJson()).toList());
    await prefs.setString(_key(userId), encoded);
  }

  Future<void> append({
    required String userId,
    required String title,
    required String body,
    String? type,
    String? diagnosis,
  }) async {
    if (userId.isEmpty) return;
    final List<LocalInboxNotification> items = await loadItems(userId);
    final String id = '${DateTime.now().microsecondsSinceEpoch}_${items.length}';
    final LocalInboxNotification row = LocalInboxNotification(
      id: id,
      title: title.trim().isEmpty ? 'Notification' : title.trim(),
      body: body.trim(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      read: false,
      type: type,
      diagnosis: diagnosis,
    );
    items.insert(0, row);
    final List<LocalInboxNotification> trimmed =
        items.length > _maxItems ? items.sublist(0, _maxItems) : items;
    await _save(userId, trimmed);
    notifyListeners();
  }

  Future<void> markRead(String userId, String id) async {
    if (userId.isEmpty || id.isEmpty) return;
    final List<LocalInboxNotification> items = await loadItems(userId);
    final List<LocalInboxNotification> next = items
        .map((LocalInboxNotification e) => e.id == id ? e.copyWith(read: true) : e)
        .toList();
    await _save(userId, next);
    notifyListeners();
  }

  Future<void> deleteItem(String userId, String id) async {
    if (userId.isEmpty || id.isEmpty) return;
    final List<LocalInboxNotification> items = await loadItems(userId);
    final List<LocalInboxNotification> next =
        items.where((LocalInboxNotification e) => e.id != id).toList();
    await _save(userId, next);
    notifyListeners();
  }
}
