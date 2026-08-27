import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingRoom {
  const MeetingRoom({
    required this.id,
    required this.name,
    required this.location,
    required this.capacity,
    required this.equipment,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String location;
  final int capacity;
  final List<String> equipment;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MeetingRoom.fromFirestore(String id, Map<String, dynamic> data) {
    return MeetingRoom(
      id: id,
      name: (data['name'] as String? ?? '').trim(),
      location: (data['location'] as String? ?? '').trim(),
      capacity: (data['capacity'] as num?)?.toInt() ?? 1,
      equipment: (data['equipment'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
