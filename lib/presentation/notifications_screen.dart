// ========== lib/presentation/notifications_screen.dart ==========
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/local_notification_inbox_store.dart';

/// Lists notifications persisted on device for this user.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.userId});

  final String userId;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color _bgTop = Color(0xFFF7F2EA);
  static const Color _bgBottom = Color(0xFFE9EEDF);
  static const Color _accent = Color(0xff496238);
  static const Color _accentSoft = Color(0xff7f9461);
  static const Color _ink = Color(0xff2d3d24);
  static const String _logoAsset = 'assets/logo.png';

  List<LocalInboxNotification> _items = <LocalInboxNotification>[];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    LocalNotificationInboxStore.instance.addListener(_onStoreChanged);
    unawaited(_reload());
  }

  @override
  void dispose() {
    LocalNotificationInboxStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    unawaited(_reload());
  }

  Future<void> _reload() async {
    if (widget.userId.isEmpty) {
      if (mounted) {
        setState(() {
          _items = <LocalInboxNotification>[];
          _loading = false;
        });
      }
      return;
    }
    try {
      final List<LocalInboxNotification> list =
          await LocalNotificationInboxStore.instance.loadItems(widget.userId);
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: _bgTop,
      appBar: _buildAppBar(context),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[_bgTop, _bgBottom],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: const Color(0xFFE8F0DC),
      foregroundColor: _accent,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: _accent),
      centerTitle: false,
      titleSpacing: 10,
      title: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              _logoAsset,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.notifications_rounded, color: _accent, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Notifications',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        fontSize: 18,
                      ),
                ),
                Text(
                  'Bur · saved on this device',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    height: 1.2,
                    color: _accent.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.red.shade100),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 14),
                  Text(
                    'Could not load notifications',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                color: _accentSoft,
                strokeWidth: 3.2,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Loading your inbox…',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: _accent.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _accentSoft.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 52,
                  color: _accentSoft.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'No notifications yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'When Bur sends you reminders or alerts, they will appear here. You can clear any item anytime.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final LocalInboxNotification row = _items[index];
        final bool read = row.read;
        final String timeLabel = _formatTimeFromMs(row.createdAtMs);

        return DecoratedBox(
          decoration: BoxDecoration(
            color: read ? Colors.white : const Color(0xFFF2F8EA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: read
                  ? Colors.black.withValues(alpha: 0.06)
                  : _accentSoft.withValues(alpha: 0.45),
              width: read ? 1 : 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: read ? 0.05 : 0.07),
                blurRadius: read ? 12 : 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (!read)
                    Container(
                      width: 5,
                      color: _accentSoft,
                    ),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          if (!read) {
                            await LocalNotificationInboxStore.instance
                                .markRead(widget.userId, row.id);
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(read ? 16 : 11, 14, 8, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _accentSoft.withValues(alpha: read ? 0.12 : 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  read
                                      ? Icons.notifications_rounded
                                      : Icons.mark_email_unread_rounded,
                                  color: read ? _accent.withValues(alpha: 0.55) : _accent,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            row.title,
                                            style: TextStyle(
                                              fontWeight:
                                                  read ? FontWeight.w600 : FontWeight.w800,
                                              fontSize: 15.5,
                                              height: 1.25,
                                              color: _ink,
                                            ),
                                          ),
                                        ),
                                        if (!read)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 6, top: 2),
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: _accentSoft,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (row.body.isNotEmpty) ...<Widget>[
                                      const SizedBox(height: 7),
                                      Text(
                                        row.body,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.38,
                                          color: Color(0xff4a5a40),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                    if (row.diagnosis != null &&
                                        row.diagnosis!.trim().isNotEmpty) ...<Widget>[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.white.withValues(alpha: read ? 0.65 : 0.55),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _accent.withValues(alpha: 0.08),
                                          ),
                                        ),
                                        child: Text(
                                          row.diagnosis!.trim(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.32,
                                            color: Colors.grey.shade800,
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (timeLabel.isNotEmpty) ...<Widget>[
                                      const SizedBox(height: 10),
                                      Row(
                                        children: <Widget>[
                                          Icon(
                                            Icons.schedule_rounded,
                                            size: 15,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            timeLabel,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        await LocalNotificationInboxStore.instance
                            .deleteItem(widget.userId, row.id);
                      },
                      child: SizedBox(
                        width: 52,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.grey.shade600,
                              size: 22,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _formatTimeFromMs(int ms) {
    if (ms <= 0) return '';
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
    final DateTime now = DateTime.now();
    final DateTime local = d.toLocal();
    if (now.difference(local).inDays == 0) {
      final int h = local.hour;
      final int m = local.minute;
      final String am = h >= 12 ? 'PM' : 'AM';
      final int hr = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return 'Today, $hr:${m.toString().padLeft(2, '0')} $am';
    }
    if (now.difference(local).inDays == 1) {
      return 'Yesterday';
    }
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
