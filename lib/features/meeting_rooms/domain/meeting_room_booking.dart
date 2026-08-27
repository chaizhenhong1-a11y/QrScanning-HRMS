import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingRoomBooking {
  const MeetingRoomBooking({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.employeeId,
    required this.uid,
    required this.displayName,
    required this.purpose,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.createdAt,
    required this.cancelledAt,
  });

  final String id;
  final String roomId;
  final String roomName;
  final String employeeId;
  final String uid;
  final String displayName;
  final String purpose;
  final DateTime startAt;
  final DateTime endAt;
  final String status;
  final DateTime? createdAt;
  final DateTime? cancelledAt;

  bool get isCancelled => status == 'cancelled';

  factory MeetingRoomBooking.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final start = (data['startAt'] as Timestamp?)?.toDate();
    final end = (data['endAt'] as Timestamp?)?.toDate();

    if (start == null || end == null) {
      throw StateError('Meeting room booking is missing its time range.');
    }

    return MeetingRoomBooking(
      id: id,
      roomId: (data['roomId'] as String? ?? '').trim(),
      roomName: (data['roomName'] as String? ?? '').trim(),
      employeeId: (data['employeeId'] as String? ?? '').trim(),
      uid: (data['uid'] as String? ?? '').trim(),
      displayName: (data['displayName'] as String? ?? '').trim(),
      purpose: (data['purpose'] as String? ?? '').trim(),
      startAt: start,
      endAt: end,
      status: (data['status'] as String? ?? 'active').trim(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
    );
  }
}
