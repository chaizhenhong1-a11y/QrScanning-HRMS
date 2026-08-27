import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../application/claim_service.dart';
import '../../domain/claim_request.dart';

class ClaimsPage extends StatefulWidget {
  const ClaimsPage({super.key});

  @override
  State<ClaimsPage> createState() => _ClaimsPageState();
}

class _ClaimsPageState extends State<ClaimsPage> {
  final _service = ClaimService();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late Future<List<ClaimRequest>> _future;
  DateTime? _expenseDate;
  XFile? _receipt;
  String _category = 'Travel';
  bool _submitting = false;

  static const _categories = [
    'Travel',
    'Transport',
    'Meal',
    'Medical',
    'Office',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _future = _service.loadMine();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _service.loadMine();
    });
    await _future;
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (_titleController.text.trim().isEmpty ||
        amount == null ||
        amount <= 0 ||
        _expenseDate == null) {
      _notice('Enter a title, valid amount, and expense date.');
      return;
    }

    setState(() => _submitting = true);
    String? receiptPath;

    try {
      if (_receipt != null) {
        receiptPath = await _service.uploadReceipt(_receipt!);
      }

      await _service.submit(
        title: _titleController.text,
        amount: amount,
        category: _category,
        expenseDate: _expenseDate!,
        description: _descriptionController.text,
        receiptPath: receiptPath,
      );

      if (!mounted) return;
      _titleController.clear();
      _amountController.clear();
      _descriptionController.clear();
      setState(() {
        _expenseDate = null;
        _receipt = null;
      });
      await _reload();
      if (mounted) _notice('Expense claim submitted for approval.');
    } catch (error) {
      if (receiptPath != null) {
        await _service.deleteReceipt(receiptPath);
      }
      if (mounted) _notice(_friendly(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel(ClaimRequest request) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel expense claim?'),
        content: const Text(
          'Only pending claims can be cancelled. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep claim'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel claim'),
          ),
        ],
      ),
    );
    if (yes != true) return;

    try {
      await _service.cancel(request);
      await _reload();
      if (mounted) _notice('Claim cancelled.');
    } catch (error) {
      if (mounted) _notice(_friendly(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Claims')),
      body: DecoratedBox(
        decoration: VeyraDesign.pageBackground,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            children: [
              _summary(),
              const SizedBox(height: 22),
              Text(
                'New claim',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: 'Expense title',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountController,
                        enabled: !_submitting,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount (RM)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: _categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _submitting
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _category = value);
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickExpenseDate,
                        icon: const Icon(Icons.event_rounded),
                        label: Text(
                          _expenseDate == null
                              ? 'Expense date'
                              : _date(_expenseDate!),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descriptionController,
                        enabled: !_submitting,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickReceipt,
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: Text(_receipt?.name ?? 'Attach receipt image'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: Text(
                            _submitting ? 'Submitting…' : 'Submit claim',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                'My claims',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<ClaimRequest>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data ?? const <ClaimRequest>[];
                  if (items.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No expense claims yet.'),
                      ),
                    );
                  }

                  return Column(
                    children: items
                        .map(
                          (request) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          request.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      Chip(
                                        label: Text(request.status.label),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${request.category} · '
                                    '${_date(request.expenseDate)}',
                                    style: const TextStyle(
                                      color: VeyraDesign.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'RM ${request.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (request.description.isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(request.description),
                                  ],
                                  if (request.receiptPath?.isNotEmpty == true)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.attachment_rounded,
                                            size: 17,
                                          ),
                                          SizedBox(width: 5),
                                          Text('Receipt uploaded'),
                                        ],
                                      ),
                                    ),
                                  if (request.reviewNote?.isNotEmpty ==
                                      true) ...[
                                    const Divider(height: 22),
                                    Text('Review note: ${request.reviewNote}'),
                                  ],
                                  if (request.paymentReference?.isNotEmpty ==
                                      true)
                                    Text(
                                      'Payment ref: '
                                      '${request.paymentReference}',
                                    ),
                                  if (request.status == ClaimStatus.pending)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => _cancel(request),
                                        child: const Text('Cancel claim'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary() {
    return FutureBuilder<List<ClaimRequest>>(
      future: _future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <ClaimRequest>[];
        final pending = items
            .where((claim) => claim.status == ClaimStatus.pending)
            .fold<double>(0, (sum, claim) => sum + claim.amount);
        final approved = items
            .where(
              (claim) =>
                  claim.status == ClaimStatus.approved ||
                  claim.status == ClaimStatus.paid,
            )
            .fold<double>(0, (sum, claim) => sum + claim.amount);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: VeyraDesign.brandGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(child: _metric('Pending', pending)),
              Expanded(child: _metric('Approved', approved)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${items.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Claims',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metric(String label, double amount) => Column(
    children: [
      Text(
        'RM ${amount.toStringAsFixed(0)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ],
  );

  Future<void> _pickExpenseDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _expenseDate = picked);
    }
  }

  Future<void> _pickReceipt() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (file != null && mounted) {
      setState(() => _receipt = file);
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _friendly(Object error) => error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
