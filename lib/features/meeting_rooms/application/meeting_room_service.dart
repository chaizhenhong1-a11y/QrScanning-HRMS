import '../../identity/application/identity_service.dart';
import '../../identity/domain/hrms_role.dart';
import '../data/meeting_room_repository.dart';
import '../domain/meeting_room.dart';
import '../domain/meeting_room_booking.dart';

class MeetingRoomSession {
  const MeetingRoomSession({
    required this.companyId,
    required this.uid,
    required this.employeeId,
    required this.displayName,
    required this.canManageRooms,
  });

  final String companyId;
  final String uid;
  final String employeeId;
  final String displayName;
  final bool canManageRooms;
}

class MeetingRoomService {
  MeetingRoomService({
    MeetingRoomRepository? repository,
    IdentityService? identityService,
  }) : _repository = repository ?? const MeetingRoomRepository(),
       _identityService = identityService ?? IdentityService();

  final MeetingRoomRepository _repository;
  final IdentityService _identityService;

  Future<MeetingRoomSession> session() async {
    final identity = await _identityService.restoreIdentity();
    if (identity == null) {
      throw StateError('Your Veyra HRMS session is unavailable.');
    }

    return MeetingRoomSession(
      companyId: identity.companyId,
      uid: identity.uid,
      employeeId: identity.employeeId,
      displayName: identity.displayName.isEmpty
          ? identity.employeeId
          : identity.displayName,
      canManageRooms:
          identity.role == HrmsRole.companyOwner ||
          identity.role == HrmsRole.hrAdmin,
    );
  }

  Stream<List<MeetingRoom>> watchRooms(MeetingRoomSession session) {
    return _repository.watchRooms(session.companyId);
  }

  Stream<List<MeetingRoomBooking>> watchBookings({
    required MeetingRoomSession session,
    required DateTime from,
    required DateTime to,
  }) {
    return _repository.watchBookings(
      companyId: session.companyId,
      from: from,
      to: to,
    );
  }

  Future<void> book({
    required MeetingRoomSession session,
    required MeetingRoom room,
    required String purpose,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final cleanPurpose = purpose.trim();
    final now = DateTime.now();

    if (!room.isActive) {
      throw StateError('This meeting room is currently unavailable.');
    }
    if (cleanPurpose.length < 3 || cleanPurpose.length > 160) {
      throw ArgumentError(
        'Meeting purpose must contain between 3 and 160 characters.',
      );
    }
    if (!startAt.isAfter(now.subtract(const Duration(minutes: 1)))) {
      throw ArgumentError('Meeting start time must be in the future.');
    }
    if (!endAt.isAfter(startAt)) {
      throw ArgumentError('Meeting end time must be after the start time.');
    }

    final duration = endAt.difference(startAt);
    if (duration < const Duration(minutes: 15)) {
      throw ArgumentError('Meeting duration must be at least 15 minutes.');
    }
    if (duration > const Duration(hours: 8)) {
      throw ArgumentError('A meeting room booking cannot exceed 8 hours.');
    }

    final conflict = await _repository.hasConflict(
      companyId: session.companyId,
      roomId: room.id,
      startAt: startAt,
      endAt: endAt,
    );

    if (conflict) {
      throw StateError(
        'This room already has a booking that overlaps the selected time.',
      );
    }

    await _repository.createBooking(
      companyId: session.companyId,
      room: room,
      employeeId: session.employeeId,
      uid: session.uid,
      displayName: session.displayName,
      purpose: cleanPurpose,
      startAt: startAt,
      endAt: endAt,
    );
  }

  Future<void> cancel({
    required MeetingRoomSession session,
    required MeetingRoomBooking booking,
  }) async {
    if (booking.uid != session.uid && !session.canManageRooms) {
      throw StateError('You can cancel only your own meeting room bookings.');
    }
    if (booking.isCancelled) {
      return;
    }

    await _repository.cancelBooking(
      companyId: session.companyId,
      bookingId: booking.id,
    );
  }

  Future<void> createRoom({
    required MeetingRoomSession session,
    required String name,
    required String location,
    required int capacity,
    required List<String> equipment,
  }) async {
    _requireRoomManager(session);
    _validateRoom(name: name, location: location, capacity: capacity);

    await _repository.createRoom(
      companyId: session.companyId,
      name: name,
      location: location,
      capacity: capacity,
      equipment: _normalizeEquipment(equipment),
    );
  }

  Future<void> updateRoom({
    required MeetingRoomSession session,
    required MeetingRoom room,
    required String name,
    required String location,
    required int capacity,
    required List<String> equipment,
  }) async {
    _requireRoomManager(session);
    _validateRoom(name: name, location: location, capacity: capacity);

    await _repository.updateRoom(
      companyId: session.companyId,
      room: room,
      name: name,
      location: location,
      capacity: capacity,
      equipment: _normalizeEquipment(equipment),
    );
  }

  Future<void> setRoomActive({
    required MeetingRoomSession session,
    required MeetingRoom room,
    required bool isActive,
  }) async {
    _requireRoomManager(session);

    await _repository.setRoomActive(
      companyId: session.companyId,
      room: room,
      isActive: isActive,
    );
  }

  void _requireRoomManager(MeetingRoomSession session) {
    if (!session.canManageRooms) {
      throw StateError(
        'Only Company Owner or HR Admin can manage meeting rooms.',
      );
    }
  }

  void _validateRoom({
    required String name,
    required String location,
    required int capacity,
  }) {
    if (name.trim().length < 2 || name.trim().length > 80) {
      throw ArgumentError('Room name must contain 2 to 80 characters.');
    }
    if (location.trim().length > 120) {
      throw ArgumentError('Room location cannot exceed 120 characters.');
    }
    if (capacity < 1 || capacity > 500) {
      throw ArgumentError('Room capacity must be between 1 and 500 people.');
    }
  }

  List<String> _normalizeEquipment(List<String> equipment) {
    final normalized = equipment
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(20)
        .toList(growable: false);

    return normalized;
  }
}
