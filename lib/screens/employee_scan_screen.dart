import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../core/storage/session_store.dart';
import '../features/attendance/domain/attendance_qr.dart';
import '../services/attendance_service.dart';

class EmployeeScanScreen extends StatefulWidget {
  const EmployeeScanScreen({super.key});

  @override
  State<EmployeeScanScreen> createState() => _EmployeeScanScreenState();
}

class _EmployeeScanScreenState extends State<EmployeeScanScreen> {
  late final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  bool _torchEnabled = false;

  void _onVisibilityChanged(VisibilityInfo info) {
    final isVisible = info.visibleFraction > 0.5;
    if (isVisible) {
      _controller.start();
      if (mounted) setState(() => _isProcessing = false);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || capture.barcodes.isEmpty) return;

    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    final companyId = await SessionStore.getCompanyId();
    if (companyId == null || companyId.isEmpty) {
      await _showMessage('No active company workspace.', isError: true);
      return;
    }

    final validation = AttendanceQrPayload.parseAndValidate(
      rawValue,
      expectedCompanyId: companyId,
    );
    if (!validation.isValid) {
      await _showMessage(
        validation.errorMessage ?? 'Invalid QR code.',
        isError: true,
      );
      return;
    }

    setState(() => _isProcessing = true);
    await _controller.stop();

    try {
      final result = await AttendanceService.clockInOut(
        source: 'qr',
        qrToken: validation.payload!.token,
      );
      if (!mounted) return;
      await _showMessage(result ?? 'Attendance recorded.', isError: false);
    } catch (error) {
      if (!mounted) return;
      await _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _showMessage(String message, {required bool isError}) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: isError ? Colors.red : Colors.green,
          size: 40,
        ),
        title: Text(isError ? 'Unable to scan' : 'Attendance recorded'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);
    await _controller.start();
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (mounted) setState(() => _torchEnabled = !_torchEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Attendance'),
        actions: [
          IconButton(
            tooltip: 'Flashlight',
            onPressed: _toggleTorch,
            icon: Icon(
              _torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: _controller.switchCamera,
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: VisibilityDetector(
        key: const Key('employee-scan-screen'),
        onVisibilityChanged: _onVisibilityChanged,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(controller: _controller, onDetect: _onDetect),
            IgnorePointer(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
            ),
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 44,
              child: Card(
                color: Colors.black.withValues(alpha: 0.62),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Text(
                    'Scan the current Veyra company attendance QR.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            if (_isProcessing)
              const ColoredBox(
                color: Color(0x55000000),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
