import 'package:flutter/material.dart';

import '../app/theme/veyra_design.dart';
import '../core/storage/session_store.dart';
import '../features/identity/domain/hrms_role.dart';
import '../features/payroll/application/payroll_service.dart';
import '../features/payroll/domain/payroll_models.dart';
import '../features/payroll/presentation/pages/payroll_admin_page.dart';

class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  final _service = PayrollService();
  late Future<List<Payslip>> _future;
  late Future<HrmsRole> _roleFuture;

  @override
  void initState() {
    super.initState();
    _future = _service.loadMine();
    _roleFuture = SessionStore.getHrmsRole().then(HrmsRole.fromValue);
  }

  Future<void> _reload() async {
    setState(() => _future = _service.loadMine());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payslips'),
        actions: [
          FutureBuilder<HrmsRole>(
            future: _roleFuture,
            builder: (context, snapshot) {
              if (snapshot.data?.canManageCompany != true) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Payroll administration',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PayrollAdminPage(),
                  ),
                ),
                icon: const Icon(Icons.admin_panel_settings_rounded),
              );
            },
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: VeyraDesign.pageBackground,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<List<Payslip>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data ?? const <Payslip>[];
              if (items.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Icon(
                      Icons.description_outlined,
                      size: 54,
                      color: VeyraDesign.muted,
                    ),
                    SizedBox(height: 12),
                    Center(child: Text('No finalized payslips yet.')),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(18),
                itemCount: items.length,
                itemBuilder: (context, index) => _PayslipCard(items[index]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  const _PayslipCard(this.slip);
  final Payslip slip;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    slip.month,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Chip(label: Text(slip.status.toUpperCase())),
              ],
            ),
            const SizedBox(height: 12),
            _row('Basic salary', slip.basicSalary),
            _row('Fixed allowance', slip.allowance),
            _row('Claims reimbursement', slip.claimReimbursement),
            const Divider(height: 22),
            _row('EPF', -slip.epfEmployee),
            _row('SOCSO', -slip.socsoEmployee),
            _row('EIS', -slip.eisEmployee),
            _row('Unpaid leave', -slip.unpaidLeaveDeduction),
            _row('Other deductions', -slip.otherDeduction),
            const Divider(height: 22),
            _row('Net pay', slip.netPay, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double amount, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          '${amount < 0 ? '-' : ''}RM ${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
