class AttendanceQrPayload {
  const AttendanceQrPayload({required this.companyId, required this.token});

  final String companyId;
  final String token;

  String encode() => 'VEYRA_ATTENDANCE|$companyId|$token';

  static AttendanceQrValidation parseAndValidate(
    String raw, {
    required String expectedCompanyId,
  }) {
    final parts = raw.split('|');
    if (parts.length != 3 || parts.first != 'VEYRA_ATTENDANCE') {
      return const AttendanceQrValidation.invalid(
        'Invalid Veyra attendance QR code.',
      );
    }

    if (expectedCompanyId.isEmpty || parts[1] != expectedCompanyId) {
      return const AttendanceQrValidation.invalid(
        'This QR code belongs to another company.',
      );
    }

    if (parts[2].trim().isEmpty) {
      return const AttendanceQrValidation.invalid(
        'Attendance QR token is missing.',
      );
    }

    return AttendanceQrValidation.valid(
      AttendanceQrPayload(companyId: parts[1], token: parts[2]),
    );
  }
}

class AttendanceQrValidation {
  const AttendanceQrValidation._({this.payload, this.errorMessage});

  const AttendanceQrValidation.valid(AttendanceQrPayload payload)
    : this._(payload: payload);

  const AttendanceQrValidation.invalid(String message)
    : this._(errorMessage: message);

  final AttendanceQrPayload? payload;
  final String? errorMessage;

  bool get isValid => payload != null;
}
