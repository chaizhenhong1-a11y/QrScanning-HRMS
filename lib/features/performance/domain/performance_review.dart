class PerformanceGoal {
  const PerformanceGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.weight,
    required this.progress,
    this.selfRating,
    this.managerRating,
  });

  final String id;
  final String title;
  final String description;
  final double weight;
  final double progress;
  final double? selfRating;
  final double? managerRating;

  factory PerformanceGoal.fromMap(Map<String, dynamic> data) => PerformanceGoal(
    id: data['id'] as String? ?? '',
    title: data['title'] as String? ?? 'Goal',
    description: data['description'] as String? ?? '',
    weight: (data['weight'] as num?)?.toDouble() ?? 0,
    progress: (data['progress'] as num?)?.toDouble() ?? 0,
    selfRating: (data['selfRating'] as num?)?.toDouble(),
    managerRating: (data['managerRating'] as num?)?.toDouble(),
  );
}

class PerformanceReview {
  const PerformanceReview({
    required this.id,
    required this.period,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.status,
    required this.goals,
    this.selfRating,
    this.managerRating,
    this.selfComment,
    this.managerComment,
  });

  final String id;
  final String period;
  final String employeeId;
  final String employeeName;
  final String department;
  final String status;
  final List<PerformanceGoal> goals;
  final double? selfRating;
  final double? managerRating;
  final String? selfComment;
  final String? managerComment;

  bool get isCompleted => status == 'completed';
  bool get awaitingManager => status == 'managerReview';

  factory PerformanceReview.fromMap(Map<String, dynamic> data) =>
      PerformanceReview(
        id: data['id'] as String? ?? '',
        period: data['period'] as String? ?? '',
        employeeId: data['employeeId'] as String? ?? '',
        employeeName: data['employeeName'] as String? ?? 'Employee',
        department: data['department'] as String? ?? '',
        status: data['status'] as String? ?? 'goalSetting',
        goals: (data['goals'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  PerformanceGoal.fromMap(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
        selfRating: (data['selfRating'] as num?)?.toDouble(),
        managerRating: (data['managerRating'] as num?)?.toDouble(),
        selfComment: data['selfComment'] as String?,
        managerComment: data['managerComment'] as String?,
      );
}
