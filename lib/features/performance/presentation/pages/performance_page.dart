import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../application/performance_service.dart';
import '../../domain/performance_review.dart';

class PerformancePage extends StatefulWidget {
  const PerformancePage({super.key});

  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  final _service = PerformanceService();
  late String _period;
  late Future<_Overview> _future;

  @override
  void initState() {
    super.initState();
    _period = '${DateTime.now().year}';
    _future = _load();
  }

  Future<_Overview> _load() async {
    final data = await _service.overview(_period);
    return _Overview(
      canManage: data.canManage,
      currentEmployeeId: data.currentEmployeeId,
      reviews: data.reviews,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance & KPI'),
        actions: [
          IconButton(
            tooltip: 'Change review year',
            onPressed: _pickYear,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: VeyraDesign.pageBackground,
        child: FutureBuilder<_Overview>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: FilledButton(
                  onPressed: _reload,
                  child: const Text('Retry'),
                ),
              );
            }

            final data = snapshot.data!;
            final mine = data.reviews
                .where((item) => item.employeeId == data.currentEmployeeId)
                .toList(growable: false);
            final team = data.reviews
                .where((item) => item.employeeId != data.currentEmployeeId)
                .toList(growable: false);

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                children: [
                  _hero(mine),
                  const SizedBox(height: 18),
                  _heading('My review'),
                  if (mine.isEmpty)
                    _emptyReview(
                      label: 'Start my $_period performance review',
                      employeeId: null,
                    )
                  else
                    ...mine.map(
                      (review) => _reviewCard(
                        review,
                        canManage: data.canManage,
                        isMine: true,
                      ),
                    ),
                  if (data.canManage) ...[
                    const SizedBox(height: 24),
                    _heading('Team reviews'),
                    if (team.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('No team reviews have been started yet.'),
                        ),
                      )
                    else
                      ...team.map(
                        (review) =>
                            _reviewCard(review, canManage: true, isMine: false),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _startTeamReview,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Start employee review'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hero(List<PerformanceReview> mine) {
    final review = mine.isEmpty ? null : mine.first;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: VeyraDesign.brandGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white24,
            child: Icon(Icons.insights_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_period Performance',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  review == null
                      ? 'No review started'
                      : _statusLabel(review.status),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          if (review?.managerRating != null)
            Text(
              '${review!.managerRating!.toStringAsFixed(1)}/5',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    ),
  );

  Widget _emptyReview({required String label, required String? employeeId}) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: FilledButton.icon(
            onPressed: () async {
              try {
                await _service.ensureReview(
                  period: _period,
                  employeeId: employeeId,
                );
                await _reload();
              } catch (error) {
                if (mounted) _notice(_friendly(error));
              }
            },
            icon: const Icon(Icons.flag_rounded),
            label: Text(label),
          ),
        ),
      );

  Widget _reviewCard(
    PerformanceReview review, {
    required bool canManage,
    required bool isMine,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.employeeName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Chip(label: Text(_statusLabel(review.status))),
              ],
            ),
            Text(
              '${review.employeeId} · ${review.department}',
              style: const TextStyle(color: VeyraDesign.muted),
            ),
            const SizedBox(height: 14),
            if (review.goals.isEmpty)
              const Text('No KPI / goals added yet.')
            else
              ...review.goals.map(
                (goal) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: VeyraDesign.softBrand,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                goal.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text('${goal.weight.toStringAsFixed(0)}%'),
                          ],
                        ),
                        if (goal.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(goal.description),
                        ],
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (goal.progress / 100).clamp(0, 1),
                        ),
                        const SizedBox(height: 5),
                        Text('${goal.progress.toStringAsFixed(0)}% complete'),
                      ],
                    ),
                  ),
                ),
              ),
            if (review.selfRating != null) ...[
              const Divider(height: 22),
              Text('Self rating: ${review.selfRating!.toStringAsFixed(1)}/5'),
              if (review.selfComment?.isNotEmpty == true)
                Text(review.selfComment!),
            ],
            if (review.managerRating != null) ...[
              const SizedBox(height: 8),
              Text(
                'Manager rating: ${review.managerRating!.toStringAsFixed(1)}/5',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (review.managerComment?.isNotEmpty == true)
                Text(review.managerComment!),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isMine &&
                    (review.status == 'goalSetting' ||
                        review.status == 'selfReview'))
                  OutlinedButton.icon(
                    onPressed: () => _editGoal(review),
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('Add KPI / Goal'),
                  ),
                if (isMine &&
                    review.goals.isNotEmpty &&
                    review.status != 'managerReview' &&
                    !review.isCompleted)
                  FilledButton(
                    onPressed: () => _selfReview(review),
                    child: const Text('Submit self review'),
                  ),
                if (!isMine && canManage && review.awaitingManager)
                  FilledButton.icon(
                    onPressed: () => _managerReview(review),
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text('Manager review'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editGoal(PerformanceReview review) async {
    final title = TextEditingController();
    final description = TextEditingController();
    final weight = TextEditingController(text: '25');
    final progress = TextEditingController(text: '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add KPI / Goal'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Goal title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: weight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Weight %'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: progress,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Progress %'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final weightValue = double.tryParse(weight.text.trim());
    final progressValue = double.tryParse(progress.text.trim());
    if (ok == true &&
        title.text.trim().isNotEmpty &&
        weightValue != null &&
        progressValue != null) {
      try {
        await _service.saveGoal(
          reviewId: review.id,
          title: title.text,
          description: description.text,
          weight: weightValue,
          progress: progressValue,
        );
        await _reload();
      } catch (error) {
        if (mounted) _notice(_friendly(error));
      }
    }

    title.dispose();
    description.dispose();
    weight.dispose();
    progress.dispose();
  }

  Future<void> _selfReview(PerformanceReview review) => _ratingDialog(
    title: 'Submit self review',
    onSubmit: (rating, comment) => _service.submitSelfReview(
      reviewId: review.id,
      rating: rating,
      comment: comment,
    ),
  );

  Future<void> _managerReview(PerformanceReview review) => _ratingDialog(
    title: 'Finalize ${review.employeeName}',
    onSubmit: (rating, comment) => _service.finalizeManagerReview(
      reviewId: review.id,
      rating: rating,
      comment: comment,
    ),
  );

  Future<void> _ratingDialog({
    required String title,
    required Future<void> Function(double rating, String comment) onSubmit,
  }) async {
    final rating = TextEditingController(text: '3');
    final comment = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rating,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Rating (1-5)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: comment,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Comments'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    final value = double.tryParse(rating.text.trim());
    if (ok == true && value != null) {
      try {
        await onSubmit(value, comment.text.trim());
        await _reload();
        if (mounted) _notice('Performance review updated.');
      } catch (error) {
        if (mounted) _notice(_friendly(error));
      }
    }

    rating.dispose();
    comment.dispose();
  }

  Future<void> _startTeamReview() async {
    final employee = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start employee review'),
        content: TextField(
          controller: employee,
          decoration: const InputDecoration(labelText: 'Employee ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (ok == true && employee.text.trim().isNotEmpty) {
      try {
        await _service.ensureReview(
          period: _period,
          employeeId: employee.text.trim(),
        );
        await _reload();
      } catch (error) {
        if (mounted) _notice(_friendly(error));
      }
    }
    employee.dispose();
  }

  Future<void> _pickYear() async {
    final controller = TextEditingController(text: _period);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Review year'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Year'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    if (ok == true && RegExp(r'^\d{4}$').hasMatch(controller.text.trim())) {
      setState(() {
        _period = controller.text.trim();
        _future = _load();
      });
    }
    controller.dispose();
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  static String _friendly(Object error) => error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');

  static String _statusLabel(String status) => switch (status) {
    'goalSetting' => 'Goal setting',
    'selfReview' => 'Self review',
    'managerReview' => 'Manager review',
    'completed' => 'Completed',
    _ => status,
  };
}

class _Overview {
  const _Overview({
    required this.canManage,
    required this.currentEmployeeId,
    required this.reviews,
  });

  final bool canManage;
  final String currentEmployeeId;
  final List<PerformanceReview> reviews;
}
