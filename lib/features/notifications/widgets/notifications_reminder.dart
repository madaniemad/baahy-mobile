import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

/// "Notifications are off" card (Emad, 2026-11-04: 22 of 47 customers who ordered in a month
/// had them off, so order updates reached half of them). The phone's own dialog can be shown once
/// on iPhone and twice on Android; after that only the app's notification settings can turn them
/// on, which is where «تفعيل» goes (PushNotificationService.enableFromReminder).
///
/// [order]: on an active order's page, every time. Otherwise the home card: at most once a week,
/// with a close button. Re-checked whenever the app comes back from Settings; gone once they are on.
class NotificationsReminder extends StatefulWidget {
  final bool order;
  const NotificationsReminder.order({super.key}) : order = true;
  const NotificationsReminder.home({super.key}) : order = false;

  @override
  State<NotificationsReminder> createState() => _NotificationsReminderState();
}

class _NotificationsReminderState extends State<NotificationsReminder> with WidgetsBindingObserver {
  static const _kHomeClosedAt = 'notif_reminder_home_closed_at';
  static const _homeEvery = Duration(days: 7);
  bool _show = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    var show = !await PushNotificationService.instance.notificationsEnabled();
    if (show && !widget.order) {
      final closed = (await SharedPreferences.getInstance()).getInt(_kHomeClosedAt) ?? 0;
      show = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(closed)) >= _homeEvery;
    }
    if (mounted && show != _show) setState(() => _show = show);
  }

  Future<void> _close() async {
    setState(() => _show = false);
    (await SharedPreferences.getInstance()).setInt(_kHomeClosedAt, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _turnOn() async {
    await PushNotificationService.instance.enableFromReminder();
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final s = context.s;
    final card = Container(
      padding: EdgeInsetsDirectional.fromSTEB(14, 12, widget.order ? 12 : 4, 12),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: const Icon(Icons.notifications_off_outlined, size: 20, color: AppColors.teal700),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(widget.order ? s.notifOffOrderTitle : s.notifOffHomeTitle,
            textAlign: TextAlign.start,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'], color: context.col.ink0,
              fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.35)),
          const SizedBox(height: 2),
          Text(widget.order ? s.notifOffOrderSub : s.notifOffHomeSub,
            textAlign: TextAlign.start,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'], color: context.col.ink3,
              fontSize: 12, height: 1.35)),
        ])),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _turnOn,
          style: TextButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: const Size(0, 34),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
          ),
          child: Text(s.notifTurnOn,
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        if (!widget.order)
          IconButton(
            onPressed: _close,
            icon: Icon(Icons.close_rounded, size: 18, color: context.col.ink3),
            visualDensity: VisualDensity.compact,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
      ]),
    );
    return widget.order ? Padding(padding: const EdgeInsets.only(bottom: 14), child: card)
        : Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0), child: card);
  }
}
