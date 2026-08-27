import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../../../core/utils/firebase_error_message.dart';
import '../../application/training_feedback_service.dart';
import '../../domain/training_feedback.dart';

class TrainingFeedbackPage extends StatefulWidget {
  const TrainingFeedbackPage({super.key});

  @override
  State<TrainingFeedbackPage> createState() => _TrainingFeedbackPageState();
}

class _TrainingFeedbackPageState extends State<TrainingFeedbackPage> {
  final TrainingFeedbackService _service = TrainingFeedbackService();

  late Future<TrainingFeedbackSession> _sessionFuture;
  bool _busy = false;
  bool _companyView = false;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _service.session();
  }

  Future<void> _reload() async {
    setState(() => _sessionFuture = _service.session());
    await _sessionFuture;
  }

  Future<void> _submit(TrainingFeedbackSession session) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final commentController = TextEditingController();
    var trainingDate = DateTime.now();
    var rating = 3;
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> save() async {
              if (saving || !(formKey.currentState?.validate() ?? false)) {
                return;
              }

              setDialogState(() => saving = true);
              setState(() => _busy = true);

              try {
                await _service.submit(
                  session: session,
                  trainingTitle: titleController.text,
                  trainingDate: trainingDate,
                  rating: rating,
                  comment: commentController.text,
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(firebaseErrorMessage(error))),
                  );
                  setDialogState(() => saving = false);
                }
              } finally {
                if (mounted) {
                  setState(() => _busy = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Training feedback'),
              content: SizedBox(
                width: 540,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: titleController,
                          enabled: !saving,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Training title',
                          ),
                          validator: (value) {
                            final length = value?.trim().length ?? 0;
                            if (length < 3) {
                              return 'Enter at least 3 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        ListTile(
                          enabled: !saving,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Training date'),
                          subtitle: Text(_date(trainingDate)),
                          trailing: const Icon(Icons.calendar_month_rounded),
                          onTap: () async {
                            final value = await showDatePicker(
                              context: dialogContext,
                              initialDate: trainingDate,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 730),
                              ),
                              lastDate: DateTime.now(),
                            );

                            if (value != null && dialogContext.mounted) {
                              setDialogState(() => trainingDate = value);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              'Rating',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            Text(
                              '$rating / 5',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: rating.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: rating.toString(),
                          onChanged: saving
                              ? null
                              : (value) {
                                  setDialogState(() => rating = value.round());
                                },
                        ),
                        TextFormField(
                          controller: commentController,
                          enabled: !saving,
                          maxLength: 2000,
                          minLines: 3,
                          maxLines: 7,
                          decoration: const InputDecoration(
                            labelText: 'Comments (optional)',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit feedback'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    commentController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Training feedback submitted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TrainingFeedbackSession>(
      future: _sessionFuture,
      builder: (context, sessionSnapshot) {
        if (sessionSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (sessionSnapshot.hasError || !sessionSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Training Feedback')),
            body: _ErrorState(
              message: firebaseErrorMessage(
                sessionSnapshot.error ??
                    StateError('Unable to load your HRMS session.'),
              ),
              onRetry: _reload,
            ),
          );
        }

        final session = sessionSnapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Training Feedback'),
            actions: [
              IconButton(
                tooltip: 'Submit feedback',
                onPressed: _busy ? null : () => _submit(session),
                icon: const Icon(Icons.add_comment_rounded),
              ),
            ],
          ),
          body: DecoratedBox(
            decoration: VeyraDesign.pageBackground,
            child: Column(
              children: [
                if (session.canReviewCompanyFeedback)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.person_outline),
                          label: Text('My Feedback'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.groups_rounded),
                          label: Text('Company'),
                        ),
                      ],
                      selected: {_companyView},
                      onSelectionChanged: (selection) {
                        setState(() => _companyView = selection.first);
                      },
                    ),
                  ),
                Expanded(
                  child: StreamBuilder<List<TrainingFeedback>>(
                    stream: _companyView && session.canReviewCompanyFeedback
                        ? _service.watchCompany(session)
                        : _service.watchMine(session),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _ErrorState(
                          message: firebaseErrorMessage(snapshot.error!),
                          onRetry: _reload,
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final items = snapshot.data!;
                      if (items.isEmpty) {
                        return _EmptyState(
                          companyView: _companyView,
                          onCreate: _busy ? null : () => _submit(session),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(18),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.trainingTitle,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        _RatingChip(rating: item.rating),
                                      ],
                                    ),
                                    if (_companyView) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        item.employeeName,
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      'Training date: ${_date(item.trainingDate)}',
                                    ),
                                    if (item.comment.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        item.comment,
                                        style: const TextStyle(
                                          color: Color(0xFF334155),
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                    if (item.submittedAt != null) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        'Submitted ${_dateTime(item.submittedAt!)}',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _busy ? null : () => _submit(session),
            icon: const Icon(Icons.rate_review_rounded),
            label: const Text('Give feedback'),
          ),
        );
      },
    );
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String _dateTime(DateTime value) {
    final local = value.toLocal();
    return '${_date(local)} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.star_rounded, size: 18),
      label: Text('$rating / 5'),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.companyView, required this.onCreate});

  final bool companyView;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.school_outlined,
              size: 54,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 14),
            Text(
              companyView
                  ? 'No company training feedback'
                  : 'No training feedback yet',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            if (!companyView) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_comment_rounded),
                label: const Text('Give feedback'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
