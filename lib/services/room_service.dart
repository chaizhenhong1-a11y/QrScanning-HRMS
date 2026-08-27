class RoomService {
  static List<String> getRooms() => [
    'Room A (4p)',
    'Room B (8p)',
    'Conference Hall',
  ];
  static List<Map<String, String>> getBookings() => [
    {'room': 'Room A', 'time': '2026-06-18 10:00-11:00', 'by': 'Alice'},
  ];
  static Future<void> book(String room, String timeSlot, String userId) async {
    // 模拟保存
  }
}
