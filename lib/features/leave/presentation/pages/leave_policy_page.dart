import 'package:flutter/material.dart';

import '../../application/leave_service.dart';
import '../../domain/leave_policy.dart';

class LeavePolicyPage extends StatefulWidget {
  const LeavePolicyPage({super.key});

  @override
  State<LeavePolicyPage> createState() => _LeavePolicyPageState();
}

class _LeavePolicyPageState extends State<LeavePolicyPage> {
  final _service = LeaveService();
  late Future<LeavePolicy> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _service.policy();
  }

  Future<void> _edit(LeavePolicy policy, LeaveTypePolicy type) async {
    final quota = TextEditingController(
      text: type.quotaDays?.toStringAsFixed(type.quotaDays! % 1 == 0 ? 0 : 1),
    );
    var paid = type.paid;
    var requiresAttachment = type.requiresAttachment;

    final updated = await showDialog<LeaveTypePolicy>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(type.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quota,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: type.quotaDays == null
                      ? 'Annual quota (blank = unlimited)'
                      : 'Annual quota',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: paid,
                onChanged: (value) => setDialogState(() => paid = value),
                title: const Text('Paid leave'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: requiresAttachment,
                onChanged: (value) =>
                    setDialogState(() => requiresAttachment = value),
                title: const Text('Require attachment'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final raw = quota.text.trim();
                Navigator.pop(
                  dialogContext,
                  LeaveTypePolicy(
                    id: type.id,
                    name: type.name,
                    quotaDays: raw.isEmpty ? null : double.tryParse(raw),
                    paid: paid,
                    requiresAttachment: requiresAttachment,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    quota.dispose();
    if (updated == null) return;

    final types = policy.types
        .map((item) => item.id == updated.id ? updated : item)
        .toList(growable: false);

    setState(() => _saving = true);
    try {
      await _service.updatePolicy(types);
      if (!mounted) return;
      setState(() {
        _future = _service.policy();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Leave policy updated.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Policy')),
      body: FutureBuilder<LeavePolicy>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final policy = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                '${policy.year} Entitlements',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Changes apply when employee leave balances are initialized '
                'for the leave year. Existing used and pending amounts are preserved.',
              ),
              const SizedBox(height: 16),
              ...policy.types.map(
                (type) => Card(
                  child: ListTile(
                    enabled: !_saving,
                    leading: const CircleAvatar(
                      child: Icon(Icons.beach_access_rounded),
                    ),
                    title: Text(type.name),
                    subtitle: Text(
                      '${type.quotaDays == null ? 'Unlimited / no quota' : '${type.quotaDays} days'}'
                      ' • ${type.paid ? 'Paid' : 'Unpaid'}'
                      '${type.requiresAttachment ? ' • Attachment required' : ''}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _edit(policy, type),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
