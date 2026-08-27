import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../../../core/utils/firebase_error_message.dart';
import '../../application/company_policy_service.dart';
import '../../domain/company_policy.dart';

class CompanyPolicyPage extends StatefulWidget {
  const CompanyPolicyPage({super.key});

  @override
  State<CompanyPolicyPage> createState() => _CompanyPolicyPageState();
}

class _CompanyPolicyPageState extends State<CompanyPolicyPage> {
  final CompanyPolicyService _service = CompanyPolicyService();

  late Future<CompanyPolicySession> _sessionFuture;
  CompanyPolicyCategory? _selectedCategory;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _service.session();
  }

  Future<void> _reload() async {
    setState(() => _sessionFuture = _service.session());
    await _sessionFuture;
  }

  Future<void> _openEditor(
    CompanyPolicySession session, {
    CompanyPolicy? policy,
  }) async {
    if (_busy || !session.canManage) return;

    final titleController = TextEditingController(text: policy?.title ?? '');
    final bodyController = TextEditingController(text: policy?.body ?? '');
    final formKey = GlobalKey<FormState>();
    var category = policy?.category ?? CompanyPolicyCategory.general;
    var dialogBusy = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              if (dialogBusy || !(formKey.currentState?.validate() ?? false)) {
                return;
              }

              setDialogState(() => dialogBusy = true);
              setState(() => _busy = true);

              try {
                if (policy == null) {
                  await _service.create(
                    session: session,
                    title: titleController.text,
                    body: bodyController.text,
                    category: category,
                  );
                } else {
                  await _service.update(
                    session: session,
                    policy: policy,
                    title: titleController.text,
                    body: bodyController.text,
                    category: category,
                  );
                }

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(firebaseErrorMessage(error))),
                  );
                  setDialogState(() => dialogBusy = false);
                }
              } finally {
                if (mounted) {
                  setState(() => _busy = false);
                }
              }
            }

            return AlertDialog(
              title: Text(policy == null ? 'Publish policy' : 'Edit policy'),
              content: SizedBox(
                width: 560,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<CompanyPolicyCategory>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: CompanyPolicyCategory.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: dialogBusy
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(() => category = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: titleController,
                          enabled: !dialogBusy,
                          maxLength: 120,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Policy title',
                          ),
                          validator: (value) {
                            final length = value?.trim().length ?? 0;
                            if (length < 3) {
                              return 'Enter at least 3 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: bodyController,
                          enabled: !dialogBusy,
                          minLines: 7,
                          maxLines: 14,
                          maxLength: 10000,
                          decoration: const InputDecoration(
                            labelText: 'Policy content',
                            alignLabelWithHint: true,
                          ),
                          validator: (value) {
                            final length = value?.trim().length ?? 0;
                            if (length < 10) {
                              return 'Enter at least 10 characters.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogBusy
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: dialogBusy ? null : submit,
                  child: dialogBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(policy == null ? 'Publish' : 'Save changes'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    bodyController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            policy == null ? 'Company policy published.' : 'Policy updated.',
          ),
        ),
      );
    }
  }

  Future<void> _togglePolicy(
    CompanyPolicySession session,
    CompanyPolicy policy,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await _service.setActive(
        session: session,
        policy: policy,
        isActive: !policy.isActive,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            policy.isActive ? 'Policy deactivated.' : 'Policy activated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePolicy(
    CompanyPolicySession session,
    CompanyPolicy policy,
  ) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete policy?'),
        content: Text(
          '"${policy.title}" will be permanently removed from this company.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service.delete(session: session, policy: policy);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Company policy deleted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CompanyPolicySession>(
      future: _sessionFuture,
      builder: (context, sessionSnapshot) {
        if (sessionSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (sessionSnapshot.hasError || !sessionSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Company Policy')),
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
            title: const Text('Company Policy'),
            actions: [
              if (session.canManage)
                IconButton(
                  tooltip: 'Publish policy',
                  onPressed: _busy ? null : () => _openEditor(session),
                  icon: const Icon(Icons.add_rounded),
                ),
            ],
          ),
          body: DecoratedBox(
            decoration: VeyraDesign.pageBackground,
            child: StreamBuilder<List<CompanyPolicy>>(
              stream: _service.watch(session),
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

                final policies = snapshot.data!
                    .where((policy) {
                      if (!session.canManage && !policy.isActive) {
                        return false;
                      }

                      return _selectedCategory == null ||
                          policy.category == _selectedCategory;
                    })
                    .toList(growable: false);

                return Column(
                  children: [
                    SizedBox(
                      height: 58,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: _selectedCategory == null,
                            onSelected: (_) {
                              setState(() => _selectedCategory = null);
                            },
                          ),
                          const SizedBox(width: 8),
                          for (final category
                              in CompanyPolicyCategory.values) ...[
                            ChoiceChip(
                              label: Text(category.label),
                              selected: _selectedCategory == category,
                              onSelected: (_) {
                                setState(() => _selectedCategory = category);
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: policies.isEmpty
                          ? _EmptyState(
                              canManage: session.canManage,
                              onCreate: _busy
                                  ? null
                                  : () => _openEditor(session),
                            )
                          : RefreshIndicator(
                              onRefresh: _reload,
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  8,
                                  18,
                                  28,
                                ),
                                itemCount: policies.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final policy = policies[index];
                                  return _PolicyCard(
                                    policy: policy,
                                    canManage: session.canManage,
                                    busy: _busy,
                                    onEdit: () =>
                                        _openEditor(session, policy: policy),
                                    onToggle: () =>
                                        _togglePolicy(session, policy),
                                    onDelete: () =>
                                        _deletePolicy(session, policy),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          floatingActionButton: session.canManage
              ? FloatingActionButton.extended(
                  onPressed: _busy ? null : () => _openEditor(session),
                  icon: const Icon(Icons.policy_rounded),
                  label: const Text('Publish policy'),
                )
              : null,
        );
      },
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.policy,
    required this.canManage,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final CompanyPolicy policy;
  final bool canManage;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final updatedAt = policy.updatedAt ?? policy.createdAt;

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
                    Icons.policy_rounded,
                    color: VeyraDesign.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    policy.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!policy.isActive)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Chip(label: Text('Inactive')),
                  ),
                if (canManage)
                  PopupMenuButton<String>(
                    enabled: !busy,
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                        case 'toggle':
                          onToggle();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(
                          policy.isActive ? 'Deactivate' : 'Activate',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Chip(label: Text(policy.category.label)),
            const SizedBox(height: 12),
            Text(
              policy.body,
              style: const TextStyle(color: Color(0xFF334155), height: 1.5),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              _metadata(policy, updatedAt),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _metadata(CompanyPolicy policy, DateTime? date) {
    final author = policy.authorName.isEmpty ? 'HR' : policy.authorName;
    if (date == null) return 'Published by $author';

    final local = date.toLocal();
    return 'Updated by $author · '
        '${local.year}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
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
              Icons.policy_outlined,
              size: 54,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 14),
            const Text(
              'No company policies yet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              canManage
                  ? 'Publish the first policy for your company.'
                  : 'Published company policies will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            if (canManage) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Publish policy'),
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
