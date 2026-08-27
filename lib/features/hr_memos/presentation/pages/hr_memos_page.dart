import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../../../core/utils/firebase_error_message.dart';
import '../../application/hr_memo_service.dart';
import '../../domain/hr_memo.dart';

class HrMemosPage extends StatefulWidget {
  const HrMemosPage({super.key});

  @override
  State<HrMemosPage> createState() => _HrMemosPageState();
}

class _HrMemosPageState extends State<HrMemosPage> {
  final HrMemoService _service = HrMemoService();

  late Future<HrMemoSession> _sessionFuture;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _service.session();
  }

  Future<void> _reload() async {
    setState(() {
      _sessionFuture = _service.session();
    });
    await _sessionFuture;
  }

  Future<void> _openEditor(HrMemoSession session, {HrMemo? memo}) async {
    if (_actionBusy || !session.canManage) return;

    final titleController = TextEditingController(text: memo?.title ?? '');
    final bodyController = TextEditingController(text: memo?.body ?? '');
    final formKey = GlobalKey<FormState>();

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: !_actionBusy,
      builder: (dialogContext) {
        var saving = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> save() async {
              if (saving || !(formKey.currentState?.validate() ?? false)) {
                return;
              }

              setDialogState(() => saving = true);
              setState(() => _actionBusy = true);

              try {
                if (memo == null) {
                  await _service.create(
                    session: session,
                    title: titleController.text,
                    body: bodyController.text,
                  );
                } else {
                  await _service.update(
                    session: session,
                    memo: memo,
                    title: titleController.text,
                    body: bodyController.text,
                  );
                }

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(true);
              } catch (error) {
                if (!dialogContext.mounted) return;
                setDialogState(() => saving = false);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(firebaseErrorMessage(error))),
                );
              } finally {
                if (mounted) {
                  setState(() => _actionBusy = false);
                }
              }
            }

            return AlertDialog(
              title: Text(memo == null ? 'Publish HR memo' : 'Edit HR memo'),
              content: SizedBox(
                width: 520,
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
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.length < 3) {
                              return 'Enter at least 3 characters.';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Memo title',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: bodyController,
                          enabled: !saving,
                          minLines: 5,
                          maxLines: 10,
                          maxLength: 5000,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.length < 5) {
                              return 'Enter at least 5 characters.';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Announcement',
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
                      : Text(memo == null ? 'Publish' : 'Save changes'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    bodyController.dispose();

    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            memo == null ? 'HR memo published.' : 'HR memo updated.',
          ),
        ),
      );
    }
  }

  Future<void> _delete(HrMemoSession session, HrMemo memo) async {
    if (_actionBusy || !session.canManage) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove HR memo?'),
        content: Text(
          '"${memo.title}" will be removed for everyone in this company.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep memo'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _actionBusy = true);
    try {
      await _service.delete(session: session, memo: memo);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('HR memo removed.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HrMemoSession>(
      future: _sessionFuture,
      builder: (context, sessionSnapshot) {
        if (sessionSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (sessionSnapshot.hasError || !sessionSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('HR Memos')),
            body: _LoadError(
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
            title: const Text('HR Memos'),
            actions: [
              if (session.canManage)
                IconButton(
                  tooltip: 'Publish memo',
                  onPressed: _actionBusy ? null : () => _openEditor(session),
                  icon: const Icon(Icons.add_rounded),
                ),
            ],
          ),
          body: DecoratedBox(
            decoration: VeyraDesign.pageBackground,
            child: StreamBuilder<List<HrMemo>>(
              stream: _service.watch(session),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _LoadError(
                    message: firebaseErrorMessage(snapshot.error!),
                    onRetry: _reload,
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final memos = snapshot.data!;
                if (memos.isEmpty) {
                  return _EmptyState(
                    canManage: session.canManage,
                    onCreate: _actionBusy ? null : () => _openEditor(session),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                    itemCount: memos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final memo = memos[index];
                      return _MemoCard(
                        memo: memo,
                        canManage: session.canManage,
                        busy: _actionBusy,
                        onEdit: () => _openEditor(session, memo: memo),
                        onDelete: () => _delete(session, memo),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          floatingActionButton: session.canManage
              ? FloatingActionButton.extended(
                  onPressed: _actionBusy ? null : () => _openEditor(session),
                  icon: const Icon(Icons.campaign_rounded),
                  label: const Text('Publish memo'),
                )
              : null,
        );
      },
    );
  }
}

class _MemoCard extends StatelessWidget {
  const _MemoCard({
    required this.memo,
    required this.canManage,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final HrMemo memo;
  final bool canManage;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final timestamp = memo.updatedAt ?? memo.createdAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: VeyraDesign.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: VeyraDesign.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    memo.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    enabled: !busy,
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Remove')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              memo.body,
              style: const TextStyle(color: Color(0xFF334155), height: 1.5),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              _metadata(memo, timestamp),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _metadata(HrMemo memo, DateTime? timestamp) {
    final author = memo.authorName.isEmpty ? 'HR' : memo.authorName;
    if (timestamp == null) return 'Published by $author';

    final local = timestamp.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';

    return 'Published by $author · $date';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.canManage, required this.onCreate});

  final bool canManage;
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
              Icons.campaign_outlined,
              size: 54,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 14),
            const Text(
              'No HR memos yet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              canManage
                  ? 'Publish the first company announcement for your team.'
                  : 'Company announcements from HR will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            if (canManage) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Publish memo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

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
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF475569)),
            ),
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
