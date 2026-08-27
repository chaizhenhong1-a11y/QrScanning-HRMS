import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ClaimRequest {
  final String title;
  final double amount;
  final String category;
  final String date;
  final String description;
  final String? receiptPath;
  final String submitTime;

  ClaimRequest({
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.description,
    this.receiptPath,
    required this.submitTime,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'amount': amount,
    'category': category,
    'date': date,
    'description': description,
    'receiptPath': receiptPath,
    'submitTime': submitTime,
  };

  factory ClaimRequest.fromJson(Map<String, dynamic> json) => ClaimRequest(
    title: json['title'],
    amount: json['amount'].toDouble(),
    category: json['category'],
    date: json['date'],
    description: json['description'],
    receiptPath: json['receiptPath'],
    submitTime: json['submitTime'],
  );
}

class ClaimService {
  static const _key = 'claims';
  static Future<void> add(ClaimRequest c) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    list.add(c);
    await prefs.setString(
      _key,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  static Future<List<ClaimRequest>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((j) => ClaimRequest.fromJson(j)).toList();
  }
}
