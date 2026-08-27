import 'package:flutter/material.dart';

import '../../application/notification_service.dart';
import '../../domain/hrms_notification.dart';
import '../pages/notification_center_page.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _service = NotificationService();
  late final Future<Stream<List<HrmsNotification>>> _future = _service
      .watchMine();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<List<HrmsNotification>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return IconButton(
            tooltip: 'Notifications',
            onPressed: () => _open(context),
            icon: const Icon(Icons.notifications_outlined),
          );
        }
        return StreamBuilder<List<HrmsNotification>>(
          stream: snapshot.data!,
          builder: (context, notifications) {
            final unread = (notifications.data ?? const <HrmsNotification>[])
                .where((item) => !item.isRead)
                .length;
            return IconButton(
              tooltip: 'Notifications',
              onPressed: () => _open(context),
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: const Icon(Icons.notifications_outlined),
              ),
            );
          },
        );
      },
    );
  }

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationCenterPage()),
    );
  }
}
