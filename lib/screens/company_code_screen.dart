import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/storage/session_store.dart';
import '../features/attendance/application/attendance_service.dart';
import '../features/attendance/domain/attendance_qr.dart';

class CompanyCodeScreen extends StatefulWidget {
  const CompanyCodeScreen({super.key});

  @override
  State<CompanyCodeScreen> createState() => _CompanyCodeScreenState();
}

class _CompanyCodeScreenState extends State<CompanyCodeScreen> {
  final _service = AttendanceApplicationService();

  Timer? _timer;
  String? _companyId;
  String _qrData = '';
  int _secondsLeft = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _secondsLeft <= 0) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft == 0) _refresh();
    });
  }

  Future<void> _load() async {
    _companyId = await SessionStore.getCompanyId();
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_companyId == null || _companyId!.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (mounted) setState(() => _loading = true);
    try {
      final token = await _service.issueQr();
      final payload = AttendanceQrPayload(companyId: _companyId!, token: token);
      if (!mounted) return;
      setState(() {
        _qrData = payload.encode();
        _secondsLeft = 90;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Code'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.verified_user_outlined, size: 46),
                const SizedBox(height: 12),
                const Text(
                  'Secure Company Attendance Code',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _companyId == null
                      ? 'No active company workspace'
                      : 'Company $_companyId',
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: _loading
                        ? const SizedBox(
                            width: 240,
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _qrData.isEmpty
                        ? const SizedBox(
                            width: 240,
                            height: 240,
                            child: Center(
                              child: Text('Attendance code unavailable'),
                            ),
                          )
                        : QrImageView(
                            data: _qrData,
                            size: 240,
                            backgroundColor: Colors.white,
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _secondsLeft > 0
                      ? 'Refreshes in $_secondsLeft seconds'
                      : 'Refreshing…',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The token is created by Veyra Cloud Functions and validated '
                  'again when an employee clocks attendance.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
