import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../identity/domain/hrms_role.dart';
import '../../../organization/application/organization_service.dart';
import '../../../organization/domain/branch.dart';
import '../../../organization/domain/department.dart';
import '../../application/employee_service.dart';
import '../../application/invitation_service.dart';
import '../../domain/employee_invitation.dart';
import '../../domain/employee_profile.dart';

class EmployeeDirectoryPage extends StatefulWidget {
  const EmployeeDirectoryPage({super.key});

  @override
  State<EmployeeDirectoryPage> createState() => _EmployeeDirectoryPageState();
}

class _EmployeeDirectoryPageState extends State<EmployeeDirectoryPage> {
  final _service = EmployeeService();
  final _invitationService = InvitationService();
  late Future<Stream<List<EmployeeProfile>>> _employeesFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _employeesFuture = _service.employees();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employees')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEmployee,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add employee'),
      ),
      body: FutureBuilder<Stream<List<EmployeeProfile>>>(
        future: _employeesFuture,
        builder: (context, streamSnapshot) {
          if (!streamSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<List<EmployeeProfile>>(
            stream: streamSnapshot.data,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snapshot.data!;
              final needle = _query.trim().toLowerCase();
              final employees = all
                  .where((employee) {
                    if (needle.isEmpty) {
                      return true;
                    }
                    return employee.displayName.toLowerCase().contains(
                          needle,
                        ) ||
                        employee.employeeId.toLowerCase().contains(needle) ||
                        employee.email.toLowerCase().contains(needle) ||
                        employee.departmentName.toLowerCase().contains(needle);
                  })
                  .toList(growable: false);

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                children: [
                  _DirectorySummary(employees: all),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search employee, ID, email or department',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (employees.isEmpty)
                    const _EmptyEmployees()
                  else
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < employees.length;
                            index++
                          ) ...[
                            _EmployeeTile(
                              employee: employees[index],
                              onToggle: (active) =>
                                  _toggle(employees[index], active),
                              onInvite: () => _invite(employees[index]),
                            ),
                            if (index != employees.length - 1)
                              const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _toggle(EmployeeProfile employee, bool active) async {
    try {
      await _service.setEmploymentStatus(employee, active);
    } catch (error) {
      if (!mounted) return;
      _notice(_friendlyError(error));
    }
  }

  Future<void> _showAddEmployee() async {
    final organization = OrganizationService();
    final branchesStream = await organization.branches();
    final departmentsStream = await organization.departments();
    final branches = await branchesStream.first;
    final departments = await departmentsStream.first;
    if (!mounted) return;

    final result = await showModalBottomSheet<_EmployeeDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _AddEmployeeSheet(branches: branches, departments: departments),
    );
    if (result == null) return;

    try {
      final employee = await _service.createPendingEmployee(
        employeeId: result.employeeId,
        displayName: result.displayName,
        email: result.email,
        role: result.role,
        jobTitle: result.jobTitle,
        departmentId: result.department?.id ?? '',
        departmentName: result.department?.name ?? '',
        branchId: result.branch?.id ?? '',
        branchName: result.branch?.name ?? '',
      );
      final invitation = await _invitationService.issue(employee);
      if (!mounted) return;
      await _showInvitation(invitation);
    } catch (error) {
      if (!mounted) return;
      _notice(_friendlyError(error));
    }
  }

  Future<void> _invite(EmployeeProfile employee) async {
    try {
      final invitation = await _invitationService.issue(employee);
      if (!mounted) return;
      await _showInvitation(invitation);
    } catch (error) {
      if (!mounted) return;
      _notice(_friendlyError(error));
    }
  }

  Future<void> _showInvitation(EmployeeInvitation invitation) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Employee invitation ready'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invitation email queued for ${invitation.displayName}. '
              'Keep this activation code as a fallback.',
            ),
            const SizedBox(height: 16),
            SelectableText(
              invitation.id,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Work email: ${invitation.email}\n'
              'Valid for 7 days. A new invitation revokes the previous code.\n'
              'Email delivery requires the Firebase Trigger Email extension.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: invitation.id));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invitation code copied.')),
              );
            },
            child: const Text('Copy code'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? 'Invitation service is unavailable.';
    }
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
  }

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DirectorySummary extends StatelessWidget {
  const _DirectorySummary({required this.employees});
  final List<EmployeeProfile> employees;

  @override
  Widget build(BuildContext context) {
    final active = employees.where((e) => e.isActive).length;
    final pending = employees.where((e) => !e.hasAccount).length;
    return Row(
      children: [
        Expanded(
          child: _Stat(label: 'Employees', value: '${employees.length}'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(label: 'Active', value: '$active'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(label: 'Pending invite', value: '$pending'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({
    required this.employee,
    required this.onToggle,
    required this.onInvite,
  });

  final EmployeeProfile employee;
  final ValueChanged<bool> onToggle;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        child: Text(
          employee.displayName.isEmpty
              ? '?'
              : employee.displayName[0].toUpperCase(),
        ),
      ),
      title: Text(
        employee.displayName,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              employee.employeeId,
              employee.jobTitle,
              employee.departmentName,
            ].where((value) => value.isNotEmpty).join(' · '),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _Badge(employee.role.value),
              _Badge(
                employee.hasAccount
                    ? 'Account active'
                    : employee.hasPendingInvitation
                    ? 'Invited'
                    : 'Pending invite',
              ),
              if (!employee.isActive) const _Badge('Inactive'),
            ],
          ),
        ],
      ),
      trailing: employee.role == HrmsRole.companyOwner
          ? const Icon(Icons.workspace_premium_rounded)
          : employee.hasAccount
          ? Switch(value: employee.isActive, onChanged: onToggle)
          : OutlinedButton.icon(
              onPressed: employee.isActive ? onInvite : null,
              icon: Icon(
                employee.hasPendingInvitation
                    ? Icons.refresh_rounded
                    : Icons.send_rounded,
                size: 18,
              ),
              label: Text(
                employee.hasPendingInvitation ? 'Re-invite' : 'Invite',
              ),
            ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyEmployees extends StatelessWidget {
  const _EmptyEmployees();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(Icons.groups_2_outlined, size: 58),
          SizedBox(height: 14),
          Text(
            'No employees found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text('Add an employee profile to begin onboarding.'),
        ],
      ),
    );
  }
}

class _EmployeeDraft {
  const _EmployeeDraft({
    required this.employeeId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.jobTitle,
    required this.department,
    required this.branch,
  });

  final String employeeId;
  final String displayName;
  final String email;
  final HrmsRole role;
  final String jobTitle;
  final CompanyDepartment? department;
  final CompanyBranch? branch;
}

class _AddEmployeeSheet extends StatefulWidget {
  const _AddEmployeeSheet({required this.branches, required this.departments});
  final List<CompanyBranch> branches;
  final List<CompanyDepartment> departments;

  @override
  State<_AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends State<_AddEmployeeSheet> {
  final _employeeId = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _jobTitle = TextEditingController();
  HrmsRole _role = HrmsRole.employee;
  CompanyDepartment? _department;
  CompanyBranch? _branch;
  String? _error;

  @override
  void dispose() {
    _employeeId.dispose();
    _name.dispose();
    _email.dispose();
    _jobTitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add employee',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create the employee directory record now. Secure account invitation comes next.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _employeeId,
              decoration: const InputDecoration(labelText: 'Employee ID'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Work email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _jobTitle,
              decoration: const InputDecoration(labelText: 'Job title'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<HrmsRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(
                  value: HrmsRole.employee,
                  child: Text('Employee'),
                ),
                DropdownMenuItem(
                  value: HrmsRole.manager,
                  child: Text('Manager'),
                ),
                DropdownMenuItem(
                  value: HrmsRole.hrAdmin,
                  child: Text('HR admin'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _role = value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CompanyDepartment?>(
              initialValue: _department,
              decoration: const InputDecoration(labelText: 'Department'),
              items: [
                const DropdownMenuItem<CompanyDepartment?>(
                  value: null,
                  child: Text('Not assigned'),
                ),
                ...widget.departments
                    .where((d) => d.isActive)
                    .map(
                      (department) => DropdownMenuItem<CompanyDepartment?>(
                        value: department,
                        child: Text(department.name),
                      ),
                    ),
              ],
              onChanged: (value) => setState(() => _department = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CompanyBranch?>(
              initialValue: _branch,
              decoration: const InputDecoration(labelText: 'Branch'),
              items: [
                const DropdownMenuItem<CompanyBranch?>(
                  value: null,
                  child: Text('Not assigned'),
                ),
                ...widget.branches
                    .where((b) => b.isActive)
                    .map(
                      (branch) => DropdownMenuItem<CompanyBranch?>(
                        value: branch,
                        child: Text(branch.name),
                      ),
                    ),
              ],
              onChanged: (value) => setState(() => _branch = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (_employeeId.text.trim().isEmpty ||
                    _name.text.trim().isEmpty ||
                    _email.text.trim().isEmpty) {
                  setState(
                    () => _error =
                        'Employee ID, name and work email are required.',
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  _EmployeeDraft(
                    employeeId: _employeeId.text,
                    displayName: _name.text,
                    email: _email.text,
                    role: _role,
                    jobTitle: _jobTitle.text,
                    department: _department,
                    branch: _branch,
                  ),
                );
              },
              child: const Text('Add employee'),
            ),
          ],
        ),
      ),
    );
  }
}
