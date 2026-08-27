import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/meeting_room.dart';
import '../domain/meeting_room_booking.dart';

class MeetingRoomRepository {
  const MeetingRoomRepository();

  FirebaseFirestore get _db => FirebaseServices.firestore;

  CollectionReference<Map<String, dynamic>> _rooms(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('meetingRooms');
  }

  CollectionReference<Map<String, dynamic>> _bookings(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('meetingRoomBookings');
  }

  Stream<List<MeetingRoom>> watchRooms(String companyId) {
    return _rooms(companyId).snapshots().map((snapshot) {
      final rooms = snapshot.docs
          .map((doc) => MeetingRoom.fromFirestore(doc.id, doc.data()))
          .toList();

      rooms.sort((a, b) {
        if (a.isActive != b.isActive) {
          return a.isActive ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return rooms;
    });
  }

  Stream<List<MeetingRoomBooking>> watchBookings({
    required String companyId,
    required DateTime from,
    required DateTime to,
  }) {
    return _bookings(companyId)
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('startAt', isLessThan: Timestamp.fromDate(to))
        .snapshots()
        .map((snapshot) {
          final bookings = snapshot.docs
              .map(
                (doc) => MeetingRoomBooking.fromFirestore(doc.id, doc.data()),
              )
              .toList();

          bookings.sort((a, b) => a.startAt.compareTo(b.startAt));
          return bookings;
        });
  }

  Future<bool> hasConflict({
    required String companyId,
    required String roomId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final snapshot = await _bookings(
      companyId,
    ).where('roomId', isEqualTo: roomId).get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['status'] != 'active') continue;

      final existingStart = (data['startAt'] as Timestamp?)?.toDate();
      final existingEnd = (data['endAt'] as Timestamp?)?.toDate();
      if (existingStart == null || existingEnd == null) continue;

      final overlaps =
          existingStart.isBefore(endAt) && existingEnd.isAfter(startAt);
      if (overlaps) {
        return true;
      }
    }

    return false;
  }

  Future<void> createBooking({
    required String companyId,
    required MeetingRoom room,
    required String employeeId,
    required String uid,
    required String displayName,
    required String purpose,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    await _bookings(companyId).add({
      'roomId': room.id,
      'roomName': room.name,
      'employeeId': employeeId,
      'uid': uid,
      'displayName': displayName.trim(),
      'purpose': purpose.trim(),
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'cancelledAt': null,
    });
  }

  Future<void> cancelBooking({
    required String companyId,
    required String bookingId,
  }) {
    return _bookings(companyId).doc(bookingId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createRoom({
    required String companyId,
    required String name,
    required String location,
    required int capacity,
    required List<String> equipment,
  }) {
    final now = FieldValue.serverTimestamp();
    return _rooms(companyId).add({
      'name': name.trim(),
      'location': location.trim(),
      'capacity': capacity,
      'equipment': equipment,
      'isActive': true,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> updateRoom({
    required String companyId,
    required MeetingRoom room,
    required String name,
    required String location,
    required int capacity,
    required List<String> equipment,
  }) {
    return _rooms(companyId).doc(room.id).update({
      'name': name.trim(),
      'location': location.trim(),
      'capacity': capacity,
      'equipment': equipment,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setRoomActive({
    required String companyId,
    required MeetingRoom room,
    required bool isActive,
  }) {
    return _rooms(companyId).doc(room.id).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
