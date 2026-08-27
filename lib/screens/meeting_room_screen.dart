import 'package:flutter/material.dart';
import '../services/room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MeetingRoomScreen extends StatefulWidget {
  const MeetingRoomScreen({super.key});
  @override
  State<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends State<MeetingRoomScreen> {
  String? _selectedRoom;
  DateTime? _start;
  DateTime? _end;
  Future<void> _book() async {
    if (_selectedRoom == null || _start == null || _end == null) return;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '001';
    await RoomService.book(_selectedRoom!, '$_start - $_end', userId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Booked')));
  }

  @override
  Widget build(BuildContext context) {
    final rooms = RoomService.getRooms();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meeting Room Booking'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Room',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            DropdownButton<String>(
              value: _selectedRoom,
              hint: const Text('Choose a room'),
              items: rooms
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedRoom = v),
            ),
            const SizedBox(height: 20),
            ListTile(
              title: const Text('Start Time'),
              subtitle: Text(_start == null ? 'Not set' : _start.toString()),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (d != null) {
                  if (!context.mounted) return;
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (t != null) {
                    setState(
                      () => _start = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        t.hour,
                        t.minute,
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              title: const Text('End Time'),
              subtitle: Text(_end == null ? 'Not set' : _end.toString()),
              onTap: () async {
                /* 同理 */
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _book, child: const Text('Book Room')),
          ],
        ),
      ),
    );
  }
}
