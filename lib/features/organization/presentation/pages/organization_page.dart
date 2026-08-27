import 'package:flutter/material.dart';

import '../../application/organization_service.dart';
import '../../domain/branch.dart';
import '../../domain/company_profile.dart';
import '../../domain/department.dart';

class OrganizationPage extends StatefulWidget {
  const OrganizationPage({super.key});

  @override
  State<OrganizationPage> createState() => _OrganizationPageState();
}

class _OrganizationPageState extends State<OrganizationPage>
    with SingleTickerProviderStateMixin {
  final _service = OrganizationService();
  late final TabController _tabController;
  late Future<CompanyProfile> _companyFuture;
  late Future<Stream<List<CompanyBranch>>> _branchesFuture;
  late Future<Stream<List<CompanyDepartment>>> _departmentsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _reload();
  }

  void _reload() {
    _companyFuture = _service.getCompany();
    _branchesFuture = _service.branches();
    _departmentsFuture = _service.departments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company structure'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Company'),
            Tab(text: 'Branches'),
            Tab(text: 'Departments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CompanyTab(companyFuture: _companyFuture, onSave: _saveCompany),
          _BranchesTab(
            branchesFuture: _branchesFuture,
            onAdd: _showAddBranch,
            onToggle: _toggleBranch,
          ),
          _DepartmentsTab(
            departmentsFuture: _departmentsFuture,
            onAdd: _showAddDepartment,
            onToggle: _toggleDepartment,
          ),
        ],
      ),
    );
  }

  Future<void> _saveCompany(
    String name,
    String registrationNumber,
    String timeZone,
  ) async {
    await _service.updateCompany(
      name: name,
      registrationNumber: registrationNumber,
      timeZone: timeZone,
    );
    if (!mounted) return;
    setState(_reload);
    _notice('Company profile updated');
  }

  Future<void> _showAddBranch() async {
    final name = TextEditingController();
    final code = TextEditingController();
    final address = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add branch'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Branch name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Branch code'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add branch'),
          ),
        ],
      ),
    );
    if (created != true) return;
    if (name.text.trim().isEmpty || code.text.trim().isEmpty) {
      _notice('Branch name and code are required');
      return;
    }
    await _service.createBranch(
      name: name.text,
      code: code.text,
      address: address.text,
    );
    if (!mounted) return;
    _notice('Branch added');
  }

  Future<void> _showAddDepartment() async {
    final name = TextEditingController();
    final code = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add department'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Department name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Department code'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add department'),
          ),
        ],
      ),
    );
    if (created != true) return;
    if (name.text.trim().isEmpty || code.text.trim().isEmpty) {
      _notice('Department name and code are required');
      return;
    }
    await _service.createDepartment(name: name.text, code: code.text);
    if (!mounted) return;
    _notice('Department added');
  }

  Future<void> _toggleBranch(CompanyBranch branch, bool active) async {
    await _service.setBranchActive(branch.id, active);
  }

  Future<void> _toggleDepartment(
    CompanyDepartment department,
    bool active,
  ) async {
    await _service.setDepartmentActive(department.id, active);
  }

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CompanyTab extends StatelessWidget {
  const _CompanyTab({required this.companyFuture, required this.onSave});

  final Future<CompanyProfile> companyFuture;
  final Future<void> Function(String, String, String) onSave;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CompanyProfile>(
      future: companyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('Unable to load company profile'));
        }
        return _CompanyForm(company: snapshot.data!, onSave: onSave);
      },
    );
  }
}

class _CompanyForm extends StatefulWidget {
  const _CompanyForm({required this.company, required this.onSave});

  final CompanyProfile company;
  final Future<void> Function(String, String, String) onSave;

  @override
  State<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends State<_CompanyForm> {
  late final TextEditingController _name;
  late final TextEditingController _registration;
  late String _timeZone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.company.name);
    _registration = TextEditingController(
      text: widget.company.registrationNumber,
    );
    _timeZone = widget.company.timeZone;
  }

  @override
  void dispose() {
    _name.dispose();
    _registration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Workspace profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Company name'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _registration,
                  decoration: const InputDecoration(
                    labelText: 'Registration number',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _timeZone,
                  decoration: const InputDecoration(labelText: 'Time zone'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Asia/Kuala_Lumpur',
                      child: Text('Malaysia · Kuala Lumpur'),
                    ),
                    DropdownMenuItem(
                      value: 'Asia/Singapore',
                      child: Text('Singapore'),
                    ),
                    DropdownMenuItem(
                      value: 'Asia/Bangkok',
                      child: Text('Thailand · Bangkok'),
                    ),
                    DropdownMenuItem(
                      value: 'Asia/Ho_Chi_Minh',
                      child: Text('Vietnam · Ho Chi Minh City'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _timeZone = value);
                    }
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (_name.text.trim().isEmpty) {
                            return;
                          }
                          setState(() => _saving = true);
                          try {
                            await widget.onSave(
                              _name.text,
                              _registration.text,
                              _timeZone,
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _saving = false);
                            }
                          }
                        },
                  child: Text(_saving ? 'Saving…' : 'Save company profile'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BranchesTab extends StatelessWidget {
  const _BranchesTab({
    required this.branchesFuture,
    required this.onAdd,
    required this.onToggle,
  });

  final Future<Stream<List<CompanyBranch>>> branchesFuture;
  final VoidCallback onAdd;
  final Future<void> Function(CompanyBranch, bool) onToggle;

  @override
  Widget build(BuildContext context) {
    return _AsyncStreamList<CompanyBranch>(
      streamFuture: branchesFuture,
      emptyTitle: 'No branches yet',
      emptySubtitle: 'Add your head office, outlet, or work location.',
      addLabel: 'Add branch',
      onAdd: onAdd,
      itemBuilder: (branch) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.location_city_rounded)),
        title: Text(
          branch.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [branch.code, branch.address].where((e) => e.isNotEmpty).join(' · '),
        ),
        trailing: Switch(
          value: branch.isActive,
          onChanged: (value) {
            onToggle(branch, value);
          },
        ),
      ),
    );
  }
}

class _DepartmentsTab extends StatelessWidget {
  const _DepartmentsTab({
    required this.departmentsFuture,
    required this.onAdd,
    required this.onToggle,
  });

  final Future<Stream<List<CompanyDepartment>>> departmentsFuture;
  final VoidCallback onAdd;
  final Future<void> Function(CompanyDepartment, bool) onToggle;

  @override
  Widget build(BuildContext context) {
    return _AsyncStreamList<CompanyDepartment>(
      streamFuture: departmentsFuture,
      emptyTitle: 'No departments yet',
      emptySubtitle: 'Create departments before assigning employees.',
      addLabel: 'Add department',
      onAdd: onAdd,
      itemBuilder: (department) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.account_tree_outlined)),
        title: Text(
          department.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(department.code),
        trailing: Switch(
          value: department.isActive,
          onChanged: (value) {
            onToggle(department, value);
          },
        ),
      ),
    );
  }
}

class _AsyncStreamList<T> extends StatelessWidget {
  const _AsyncStreamList({
    required this.streamFuture,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.addLabel,
    required this.onAdd,
    required this.itemBuilder,
  });

  final Future<Stream<List<T>>> streamFuture;
  final String emptyTitle;
  final String emptySubtitle;
  final String addLabel;
  final VoidCallback onAdd;
  final Widget Function(T) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<List<T>>>(
      future: streamFuture,
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<List<T>>(
          stream: streamSnapshot.data,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(addLabel),
                  ),
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  _EmptyState(title: emptyTitle, subtitle: emptySubtitle)
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var index = 0; index < items.length; index++) ...[
                          itemBuilder(items[index]),
                          if (index != items.length - 1)
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Column(
        children: [
          const Icon(Icons.domain_add_outlined, size: 52),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
