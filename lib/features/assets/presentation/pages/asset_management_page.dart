import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../application/asset_service.dart';
import '../../domain/company_asset.dart';

class AssetManagementPage extends StatefulWidget {
  const AssetManagementPage({super.key});

  @override
  State<AssetManagementPage> createState() => _AssetManagementPageState();
}

class _AssetManagementPageState extends State<AssetManagementPage> {
  final _service = AssetService();
  late Future<_Overview> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Overview> _load() async {
    final data = await _service.overview();
    return _Overview(
      canManage: data.canManage,
      currentEmployeeId: data.currentEmployeeId,
      assets: data.assets,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asset Management')),
      floatingActionButton: FutureBuilder<_Overview>(
        future: _future,
        builder: (context, snapshot) => snapshot.data?.canManage == true
            ? FloatingActionButton.extended(
                onPressed: _createAsset,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Asset'),
              )
            : const SizedBox.shrink(),
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
            final available = data.assets
                .where((item) => item.status == 'available')
                .length;
            final assigned = data.assets
                .where((item) => item.status == 'assigned')
                .length;
            final attention = data.assets
                .where(
                  (item) => item.status == 'repair' || item.status == 'retired',
                )
                .length;

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
                children: [
                  _hero(data.assets.length, available, assigned, attention),
                  const SizedBox(height: 20),
                  Text(
                    data.canManage ? 'Company assets' : 'My assets',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (data.assets.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No assets found.'),
                      ),
                    )
                  else
                    ...data.assets.map(
                      (asset) => _assetCard(asset, canManage: data.canManage),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hero(int total, int available, int assigned, int attention) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: VeyraDesign.brandGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Company Assets',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat('Total', total),
              _stat('Available', available),
              _stat('Assigned', assigned),
              _stat('Attention', attention),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    ),
  );

  Widget _assetCard(CompanyAsset asset, {required bool canManage}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: VeyraDesign.primary.withValues(alpha: .12),
              child: Icon(_icon(asset.category), color: VeyraDesign.primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          asset.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Chip(label: Text(_label(asset.status))),
                    ],
                  ),
                  Text(
                    '${asset.assetTag} · ${asset.category}',
                    style: const TextStyle(color: VeyraDesign.muted),
                  ),
                  if (asset.serialNumber.isNotEmpty)
                    Text('S/N: ${asset.serialNumber}'),
                  if (asset.assignedEmployeeId != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Assigned to ${asset.assignedEmployeeName ?? asset.assignedEmployeeId}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  if (asset.warrantyExpiryDateKey != null)
                    Text('Warranty: ${asset.warrantyExpiryDateKey}'),
                  if (canManage) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (asset.status == 'available')
                          OutlinedButton(
                            onPressed: () => _assign(asset),
                            child: const Text('Assign'),
                          ),
                        if (asset.status == 'assigned')
                          FilledButton.tonal(
                            onPressed: () => _return(asset),
                            child: const Text('Return'),
                          ),
                        if (asset.status != 'assigned' &&
                            asset.status != 'retired')
                          OutlinedButton(
                            onPressed: () => _status(asset, 'repair'),
                            child: const Text('Repair'),
                          ),
                        if (asset.status == 'repair')
                          OutlinedButton(
                            onPressed: () => _status(asset, 'available'),
                            child: const Text('Back in service'),
                          ),
                        if (asset.status != 'assigned' &&
                            asset.status != 'retired')
                          TextButton(
                            onPressed: () => _status(asset, 'retired'),
                            child: const Text('Retire'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAsset() async {
    final tag = TextEditingController();
    final name = TextEditingController();
    final serial = TextEditingController();
    final notes = TextEditingController();
    var category = 'Laptop';
    DateTime? purchase;
    DateTime? warranty;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Register asset'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: tag,
                  decoration: const InputDecoration(
                    labelText: 'Asset ID / Tag',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Asset name'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items:
                      const [
                            'Laptop',
                            'Phone',
                            'Monitor',
                            'Access Card',
                            'Tablet',
                            'Other',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => category = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: serial,
                  decoration: const InputDecoration(labelText: 'Serial number'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: purchase ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (value != null) setDialogState(() => purchase = value);
                  },
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text(
                    purchase == null
                        ? 'Purchase date'
                        : 'Purchased ${_dateKey(purchase!)}',
                  ),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate:
                          warranty ??
                          DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 7300)),
                    );
                    if (value != null) setDialogState(() => warranty = value);
                  },
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(
                    warranty == null
                        ? 'Warranty expiry'
                        : 'Warranty ${_dateKey(warranty!)}',
                  ),
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
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (ok == true &&
        tag.text.trim().isNotEmpty &&
        name.text.trim().isNotEmpty) {
      try {
        await _service.createAsset(
          assetTag: tag.text.trim(),
          name: name.text.trim(),
          category: category,
          serialNumber: serial.text.trim(),
          purchaseDateKey: purchase == null ? null : _dateKey(purchase!),
          warrantyExpiryDateKey: warranty == null ? null : _dateKey(warranty!),
          notes: notes.text.trim(),
        );
        await _reload();
      } catch (error) {
        if (mounted) _notice(_friendly(error));
      }
    }

    tag.dispose();
    name.dispose();
    serial.dispose();
    notes.dispose();
  }

  Future<void> _assign(CompanyAsset asset) async {
    final employee = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Assign ${asset.name}'),
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
            child: const Text('Assign'),
          ),
        ],
      ),
    );
    if (ok == true && employee.text.trim().isNotEmpty) {
      try {
        await _service.assignAsset(
          assetId: asset.id,
          employeeId: employee.text.trim(),
        );
        await _reload();
      } catch (error) {
        if (mounted) _notice(_friendly(error));
      }
    }
    employee.dispose();
  }

  Future<void> _return(CompanyAsset asset) async {
    try {
      await _service.returnAsset(asset.id);
      await _reload();
    } catch (error) {
      if (mounted) _notice(_friendly(error));
    }
  }

  Future<void> _status(CompanyAsset asset, String status) async {
    try {
      await _service.updateStatus(assetId: asset.id, status: status);
      await _reload();
    } catch (error) {
      if (mounted) _notice(_friendly(error));
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  static String _friendly(Object error) => error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _label(String value) => switch (value) {
    'available' => 'Available',
    'assigned' => 'Assigned',
    'repair' => 'Repair',
    'retired' => 'Retired',
    _ => value,
  };

  static IconData _icon(String category) => switch (category) {
    'Laptop' => Icons.laptop_mac_rounded,
    'Phone' => Icons.smartphone_rounded,
    'Monitor' => Icons.monitor_rounded,
    'Access Card' => Icons.badge_rounded,
    'Tablet' => Icons.tablet_mac_rounded,
    _ => Icons.inventory_2_rounded,
  };
}

class _Overview {
  const _Overview({
    required this.canManage,
    required this.currentEmployeeId,
    required this.assets,
  });

  final bool canManage;
  final String currentEmployeeId;
  final List<CompanyAsset> assets;
}
