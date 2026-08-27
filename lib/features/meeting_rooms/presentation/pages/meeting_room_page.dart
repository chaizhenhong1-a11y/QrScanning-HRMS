import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../../../core/utils/firebase_error_message.dart';
import '../../application/meeting_room_service.dart';
import '../../domain/meeting_room.dart';
import '../../domain/meeting_room_booking.dart';

class MeetingRoomPage extends StatefulWidget {
  const MeetingRoomPage({super.key});

  @override
  State<MeetingRoomPage> createState() => _MeetingRoomPageState();
}

class _MeetingRoomPageState extends State<MeetingRoomPage> {
  final MeetingRoomService _service = MeetingRoomService();

  late Future<MeetingRoomSession> _sessionFuture;
  bool _busy = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _service.session();
  }

  Future<void> _reload() async {
    setState(() => _sessionFuture = _service.session());
    await _sessionFuture;
  }

  DateTime get _windowStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _windowEnd => _windowStart.add(const Duration(days: 31));

  Future<DateTime?> _pickDateTime({
    required DateTime initial,
    required DateTime firstDate,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _openBooking(
    MeetingRoomSession session,
    MeetingRoom room,
  ) async {
    if (_busy || !room.isActive) return;

    final purposeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var startAt = DateTime.now().add(const Duration(minutes: 30));
    startAt = DateTime(
      startAt.year,
      startAt.month,
      startAt.day,
      startAt.hour,
      startAt.minute < 30 ? 30 : 0,
    ).add(startAt.minute < 30 ? Duration.zero : const Duration(hours: 1));
    var endAt = startAt.add(const Duration(hours: 1));
    var dialogBusy = false;

    final booked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              if (dialogBusy || !(formKey.currentState?.validate() ?? false)) {
                return;
              }

              setDialogState(() => dialogBusy = true);
              setState(() => _busy = true);

              try {
                await _service.book(
                  session: session,
                  room: room,
                  purpose: purposeController.text,
                  startAt: startAt,
                  endAt: endAt,
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(firebaseErrorMessage(error))),
                  );
                  setDialogState(() => dialogBusy = false);
                }
              } finally {
                if (mounted) {
                  setState(() => _busy = false);
                }
              }
            }

            return AlertDialog(
              title: Text('Book ${room.name}'),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: purposeController,
                          enabled: !dialogBusy,
                          maxLength: 160,
                          decoration: const InputDecoration(
                            labelText: 'Meeting purpose',
                          ),
                          validator: (value) {
                            final length = value?.trim().length ?? 0;
                            return length < 3
                                ? 'Enter at least 3 characters.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          enabled: !dialogBusy,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.login_rounded),
                          title: const Text('Start'),
                          subtitle: Text(_formatDateTime(startAt)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            final value = await _pickDateTime(
                              initial: startAt,
                              firstDate: DateTime.now(),
                            );
                            if (value != null && dialogContext.mounted) {
                              setDialogState(() {
                                startAt = value;
                                if (!endAt.isAfter(startAt)) {
                                  endAt = startAt.add(const Duration(hours: 1));
                                }
                              });
                            }
                          },
                        ),
                        ListTile(
                          enabled: !dialogBusy,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.logout_rounded),
                          title: const Text('End'),
                          subtitle: Text(_formatDateTime(endAt)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            final value = await _pickDateTime(
                              initial: endAt,
                              firstDate: startAt,
                            );
                            if (value != null && dialogContext.mounted) {
                              setDialogState(() => endAt = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogBusy
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: dialogBusy ? null : submit,
                  child: dialogBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Book room'),
                ),
              ],
            );
          },
        );
      },
    );

    purposeController.dispose();

    if (booked == true && mounted) {
      setState(() => _selectedTab = 1);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Meeting room booked.')));
    }
  }

  Future<void> _openRoomEditor(
    MeetingRoomSession session, {
    MeetingRoom? room,
  }) async {
    if (_busy || !session.canManageRooms) return;

    final nameController = TextEditingController(text: room?.name ?? '');
    final locationController = TextEditingController(
      text: room?.location ?? '',
    );
    final capacityController = TextEditingController(
      text: room?.capacity.toString() ?? '4',
    );
    final equipmentController = TextEditingController(
      text: room?.equipment.join(', ') ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var dialogBusy = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              if (dialogBusy || !(formKey.currentState?.validate() ?? false)) {
                return;
              }

              final capacity = int.tryParse(capacityController.text.trim());
              if (capacity == null) return;

              setDialogState(() => dialogBusy = true);
              setState(() => _busy = true);

              try {
                final equipment = equipmentController.text
                    .split(',')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toList(growable: false);

                if (room == null) {
                  await _service.createRoom(
                    session: session,
                    name: nameController.text,
                    location: locationController.text,
                    capacity: capacity,
                    equipment: equipment,
                  );
                } else {
                  await _service.updateRoom(
                    session: session,
                    room: room,
                    name: nameController.text,
                    location: locationController.text,
                    capacity: capacity,
                    equipment: equipment,
                  );
                }

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(firebaseErrorMessage(error))),
                  );
                  setDialogState(() => dialogBusy = false);
                }
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            }

            return AlertDialog(
              title: Text(
                room == null ? 'Add meeting room' : 'Edit meeting room',
              ),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          enabled: !dialogBusy,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'Room name',
                          ),
                          validator: (value) {
                            final length = value?.trim().length ?? 0;
                            return length < 2
                                ? 'Enter at least 2 characters.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: locationController,
                          enabled: !dialogBusy,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Location / floor',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: capacityController,
                          enabled: !dialogBusy,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Capacity',
                          ),
                          validator: (value) {
                            final capacity = int.tryParse(value?.trim() ?? '');
                            if (capacity == null ||
                                capacity < 1 ||
                                capacity > 500) {
                              return 'Enter a capacity from 1 to 500.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: equipmentController,
                          enabled: !dialogBusy,
                          decoration: const InputDecoration(
                            labelText: 'Equipment',
                            helperText:
                                'Separate items with commas, e.g. TV, Whiteboard',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogBusy
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: dialogBusy ? null : submit,
                  child: dialogBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(room == null ? 'Add room' : 'Save changes'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    locationController.dispose();
    capacityController.dispose();
    equipmentController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(room == null ? 'Meeting room added.' : 'Room updated.'),
        ),
      );
    }
  }

  Future<void> _toggleRoom(MeetingRoomSession session, MeetingRoom room) async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      await _service.setRoomActive(
        session: session,
        room: room,
        isActive: !room.isActive,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(room.isActive ? 'Room disabled.' : 'Room enabled.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelBooking(
    MeetingRoomSession session,
    MeetingRoomBooking booking,
  ) async {
    if (_busy || booking.isCancelled) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text(
          '${booking.roomName} · ${_formatDateTime(booking.startAt)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service.cancel(session: session, booking: booking);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Booking cancelled.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MeetingRoomSession>(
      future: _sessionFuture,
      builder: (context, sessionSnapshot) {
        if (sessionSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (sessionSnapshot.hasError || !sessionSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Meeting Rooms')),
            body: _ErrorState(
              message: firebaseErrorMessage(
                sessionSnapshot.error ??
                    StateError('Unable to load your HRMS session.'),
              ),
              onRetry: _reload,
            ),
          );
        }

        final session = sessionSnapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Meeting Rooms'),
            actions: [
              if (session.canManageRooms)
                IconButton(
                  tooltip: 'Add meeting room',
                  onPressed: _busy ? null : () => _openRoomEditor(session),
                  icon: const Icon(Icons.add_business_rounded),
                ),
            ],
          ),
          body: DecoratedBox(
            decoration: VeyraDesign.pageBackground,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.meeting_room_outlined),
                        label: Text('Rooms'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.event_note_rounded),
                        label: Text('Bookings'),
                      ),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (selection) {
                      setState(() => _selectedTab = selection.first);
                    },
                  ),
                ),
                Expanded(
                  child: _selectedTab == 0
                      ? _roomsView(session)
                      : _bookingsView(session),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _roomsView(MeetingRoomSession session) {
    return StreamBuilder<List<MeetingRoom>>(
      stream: _service.watchRooms(session),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(
            message: firebaseErrorMessage(snapshot.error!),
            onRetry: _reload,
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rooms = snapshot.data!
            .where((room) {
              return session.canManageRooms || room.isActive;
            })
            .toList(growable: false);

        if (rooms.isEmpty) {
          return _EmptyRooms(
            canManage: session.canManageRooms,
            onCreate: _busy ? null : () => _openRoomEditor(session),
          );
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            itemCount: rooms.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final room = rooms[index];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: VeyraDesign.primary.withValues(
                              alpha: .1,
                            ),
                            child: const Icon(
                              Icons.meeting_room_rounded,
                              color: VeyraDesign.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (room.location.isNotEmpty)
                                  Text(
                                    room.location,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!room.isActive)
                            const Chip(label: Text('Unavailable')),
                          if (session.canManageRooms)
                            PopupMenuButton<String>(
                              enabled: !_busy,
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openRoomEditor(session, room: room);
                                } else if (value == 'toggle') {
                                  _toggleRoom(session, room);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(
                                    room.isActive
                                        ? 'Disable room'
                                        : 'Enable room',
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(
                            Icons.groups_2_outlined,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text('Capacity ${room.capacity}'),
                        ],
                      ),
                      if (room.equipment.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: room.equipment
                              .map((item) => Chip(label: Text(item)))
                              .toList(growable: false),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: room.isActive && !_busy
                              ? () => _openBooking(session, room)
                              : null,
                          icon: const Icon(Icons.event_available_rounded),
                          label: const Text('Book room'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _bookingsView(MeetingRoomSession session) {
    return StreamBuilder<List<MeetingRoomBooking>>(
      stream: _service.watchBookings(
        session: session,
        from: _windowStart,
        to: _windowEnd,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(
            message: firebaseErrorMessage(snapshot.error!),
            onRetry: _reload,
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data!
            .where((booking) {
              if (session.canManageRooms) return true;
              return booking.uid == session.uid;
            })
            .toList(growable: false);

        if (bookings.isEmpty) {
          return const _EmptyBookings();
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            itemCount: bookings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final canCancel =
                  !booking.isCancelled &&
                  (booking.uid == session.uid || session.canManageRooms);

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: VeyraDesign.primary.withValues(alpha: .1),
                    child: const Icon(
                      Icons.event_note_rounded,
                      color: VeyraDesign.primary,
                    ),
                  ),
                  title: Text(
                    booking.roomName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${booking.purpose}\n'
                      '${_formatDateTime(booking.startAt)} → '
                      '${_formatTime(booking.endAt)}'
                      '${session.canManageRooms ? '\nBy ${booking.displayName}' : ''}',
                    ),
                  ),
                  isThreeLine: true,
                  trailing: booking.isCancelled
                      ? const Chip(label: Text('Cancelled'))
                      : canCancel
                      ? IconButton(
                          tooltip: 'Cancel booking',
                          onPressed: _busy
                              ? null
                              : () => _cancelBooking(session, booking),
                          icon: const Icon(Icons.cancel_outlined),
                        )
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${_formatTime(local)}';
  }

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms({required this.canManage, required this.onCreate});

  final bool canManage;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.meeting_room_outlined,
              size: 54,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 14),
            const Text(
              'No meeting rooms yet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              canManage
                  ? 'Add your company meeting rooms so employees can book them.'
                  : 'Your company has not published any meeting rooms yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            if (canManage) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add meeting room'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 54,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 14),
            Text(
              'No room bookings',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Upcoming meeting room reservations will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF475569)),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
