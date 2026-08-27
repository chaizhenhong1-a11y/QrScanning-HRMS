import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LeaveRequest {
  final String startDate;
  final String endDate;
  final String type;
  final String reason;
  final String submitTime;
  final String? attachmentPath; // 新增：附件路径（可选）

  LeaveRequest({
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.reason,
    required this.submitTime,
    this.attachmentPath,
  });

  Map<String, dynamic> toJson() => {
    'startDate': startDate,
    'endDate': endDate,
    'type': type,
    'reason': reason,
    'submitTime': submitTime,
    'attachmentPath': attachmentPath, // 新增
  };

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
    startDate: json['startDate'],
    endDate: json['endDate'],
    type: json['type'],
    reason: json['reason'],
    submitTime: json['submitTime'],
    attachmentPath: json['attachmentPath'], // 新增
  );
}

class LeaveService {
  static const String _key = 'leave_requests';

  static Future<void> addRequest(LeaveRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    final requests = await getRequests();
    requests.add(request);
    final jsonList = requests.map((r) => r.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }

  static Future<List<LeaveRequest>> getRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((j) => LeaveRequest.fromJson(j)).toList();
  }
}
