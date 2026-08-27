class LifecycleTask {
  const LifecycleTask({
    required this.id,
    required this.title,
    required this.category,
    required this.completed,
    required this.employeeCanComplete,
  });

  final String id;
  final String title;
  final String category;
  final bool completed;
  final bool employeeCanComplete;

  factory LifecycleTask.fromMap(Map<String, dynamic> data) => LifecycleTask(
    id: data['id'] as String? ?? '',
    title: data['title'] as String? ?? 'Task',
    category: data['category'] as String? ?? 'General',
    completed: data['completed'] as bool? ?? false,
    employeeCanComplete: data['employeeCanComplete'] as bool? ?? false,
  );
}

class EmployeeLifecycleCase {
  const EmployeeLifecycleCase({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.type,
    required this.status,
    required this.tasks,
    this.startDateKey,
    this.endDateKey,
    this.probationEndDateKey,
    this.reason,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String type;
  final String status;
  final List<LifecycleTask> tasks;
  final String? startDateKey;
  final String? endDateKey;
  final String? probationEndDateKey;
  final String? reason;

  double get progress {
    if (tasks.isEmpty) return 0;
    return tasks.where((task) => task.completed).length / tasks.length;
  }

  factory EmployeeLifecycleCase.fromMap(Map<String, dynamic> data) =>
      EmployeeLifecycleCase(
        id: data['id'] as String? ?? '',
        employeeId: data['employeeId'] as String? ?? '',
        employeeName: data['employeeName'] as String? ?? 'Employee',
        type: data['type'] as String? ?? 'onboarding',
        status: data['status'] as String? ?? 'active',
        tasks: (data['tasks'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (item) => LifecycleTask.fromMap(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
        startDateKey: data['startDateKey'] as String?,
        endDateKey: data['endDateKey'] as String?,
        probationEndDateKey: data['probationEndDateKey'] as String?,
        reason: data['reason'] as String?,
      );
}
