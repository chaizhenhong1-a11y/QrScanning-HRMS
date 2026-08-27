import 'package:flutter/material.dart';

class FlexibleWorkScreen extends StatefulWidget {
  const FlexibleWorkScreen({super.key});
  @override
  State<FlexibleWorkScreen> createState() => _FlexibleWorkScreenState();
}

class _FlexibleWorkScreenState extends State<FlexibleWorkScreen> {
  bool _wfh = false;
  TimeOfDay? _startTime;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flexible Work Arrangement'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Work From Home Today'),
              value: _wfh,
              onChanged: (v) => setState(() => _wfh = v),
            ),
            if (_wfh) ...[
              ListTile(
                title: const Text('Start Time'),
                subtitle: Text(
                  _startTime != null ? _startTime!.format(context) : 'Not set',
                ),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (t != null) setState(() => _startTime = t);
                },
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('WFH request submitted')),
                  );
                },
                child: const Text('Submit'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
