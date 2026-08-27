import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../application/notification_service.dart';
import '../../domain/hrms_notification.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  final _service = NotificationService();
  late final Future<Stream<List<HrmsNotification>>> _streamFuture = _service
      .watchMine();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await _service.markAllRead();
            },
            child: const Text('Read all'),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: VeyraDesign.pageBackground,
        child: FutureBuilder<Stream<List<HrmsNotification>>>(
          future: _streamFuture,
          builder: (context, streamSnapshot) {
            if (streamSnapshot.hasError) {
              return const Center(child: Text('Unable to load notifications.'));
            }
            if (!streamSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<List<HrmsNotification>>(
              stream: streamSnapshot.data!,
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <HrmsNotification>[];
                if (items.isEmpty) {
                  return const Center(child: Text('You are all caught up.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: VeyraDesign.primary.withValues(
                            alpha: .12,
                          ),
                          child: Icon(
                            _icon(item.type),
                            color: VeyraDesign.primary,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: item.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w900,
                                ),
                              ),
                            ),
                            if (!item.isRead)
                              const CircleAvatar(
                                radius: 4,
                                backgroundColor: VeyraDesign.primary,
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(item.body),
                        ),
                        onTap: () async {
                          if (!item.isRead) {
                            await _service.markRead(item.id);
                          }
                          if (!context.mounted) return;
                          _openTarget(context, item);
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  static IconData _icon(HrmsNotificationType type) => switch (type) {
    HrmsNotificationType.leaveSubmitted ||
    HrmsNotificationType.leaveApproved ||
    HrmsNotificationType.leaveRejected => Icons.event_available_rounded,
    HrmsNotificationType.claimSubmitted ||
    HrmsNotificationType.claimApproved ||
    HrmsNotificationType.claimRejected ||
    HrmsNotificationType.claimPaid => Icons.receipt_long_rounded,
    HrmsNotificationType.payslipPublished => Icons.description_rounded,
    HrmsNotificationType.employeeInvitation => Icons.person_add_alt_1_rounded,
    HrmsNotificationType.general => Icons.notifications_rounded,
  };

  static void _openTarget(BuildContext context, HrmsNotification item) {
    // Target metadata is already stored so feature-specific deep links can
    // replace this lightweight destination without changing notification data.
    if (item.targetType == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${item.title}: ${item.body}')));
  }
}
