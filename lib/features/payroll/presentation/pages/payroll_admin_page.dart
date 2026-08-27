import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../application/payroll_service.dart';
import '../../domain/payroll_models.dart';

class PayrollAdminPage extends StatefulWidget {
  const PayrollAdminPage({super.key});

  @override
  State<PayrollAdminPage> createState() => _PayrollAdminPageState();
}

class _PayrollAdminPageState extends State<PayrollAdminPage> {
  final _service = PayrollService();
  late String _month;
  late Future<Stream<List<Payslip>>> _streamFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _streamFuture = _service.watchMonth(_month);
  }

  void _reload() {
    setState(() => _streamFuture = _service.watchMonth(_month));
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      await _service.generateDraft(_month);
      _reload();
      if (mounted) _notice('Payroll draft generated.');
    } catch (error) {
      if (mounted) _notice(_friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalize() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Finalize payroll for $_month?'),
        content: const Text(
          'Finalized payslips become employee-visible and the included '
          'approved claims are marked as paid. This cannot be regenerated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    setState(() => _busy = true);
    try {
      await _service.finalize(_month);
      if (mounted) _notice('Payroll finalized.');
    } catch (error) {
      if (mounted) _notice(_friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payroll')),
      body: DecoratedBox(
        decoration: VeyraDesign.pageBackground,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _month,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _pickMonth,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: const Text('Month'),
                      ),
                      FilledButton.icon(
                        onPressed: _busy ? null : _generate,
                        icon: const Icon(Icons.calculate_rounded),
                        label: const Text('Generate draft'),
                      ),
                      FilledButton.icon(
                        onPressed: _busy ? null : _finalize,
                        icon: const Icon(Icons.lock_rounded),
                        label: const Text('Finalize'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<Stream<List<Payslip>>>(
                future: _streamFuture,
                builder: (context, streamSnapshot) {
                  if (!streamSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return StreamBuilder<List<Payslip>>(
                    stream: streamSnapshot.data!,
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? const <Payslip>[];
                      if (items.isEmpty) {
                        return const Center(
                          child: Text('No payroll draft for this month.'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final slip = items[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                slip.employeeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${slip.employeeId} · ${slip.status.toUpperCase()}\n'
                                'Claims RM ${slip.claimReimbursement.toStringAsFixed(2)} · '
                                'Unpaid leave -RM ${slip.unpaidLeaveDeduction.toStringAsFixed(2)}',
                              ),
                              trailing: Text(
                                'RM ${slip.netPay.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMonth() async {
    final parts = _month.split('-');
    final current = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      helpText: 'Choose any day in payroll month',
    );
    if (picked != null && mounted) {
      setState(() {
        _month = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
        _streamFuture = _service.watchMonth(_month);
      });
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  static String _friendly(Object error) => error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
}
