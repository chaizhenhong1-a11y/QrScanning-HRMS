import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../../../core/storage/session_store.dart';
import '../../../identity/domain/hrms_role.dart';
import '../../application/employee_document_service.dart';
import '../../domain/employee_document.dart';

class EmployeeDocumentsPage extends StatefulWidget {
  const EmployeeDocumentsPage({super.key});

  @override
  State<EmployeeDocumentsPage> createState() => _EmployeeDocumentsPageState();
}

class _EmployeeDocumentsPageState extends State<EmployeeDocumentsPage> {
  final _service = EmployeeDocumentService();
  late Future<List<EmployeeDocument>> _future;
  HrmsRole _role = HrmsRole.employee;
  String _employeeId = '';

  @override
  void initState() {
    super.initState();
    _future = _service.load();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final role = HrmsRole.fromValue(await SessionStore.getHrmsRole());
    final employeeId = await SessionStore.getUserId() ?? '';
    if (mounted) {
      setState(() {
        _role = role;
        _employeeId = employeeId;
      });
    }
  }

  Future<void> _reload() async {
    setState(() => _future = _service.load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Documents')),
      body: DecoratedBox(
        decoration: VeyraDesign.pageBackground,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<List<EmployeeDocument>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  children: [
                    const SizedBox(height: 180),
                    const Center(child: Text('Unable to load documents.')),
                  ],
                );
              }

              final items = snapshot.data ?? const <EmployeeDocument>[];
              if (items.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Icon(
                      Icons.folder_copy_outlined,
                      size: 54,
                      color: VeyraDesign.muted,
                    ),
                    SizedBox(height: 12),
                    Center(child: Text('No employee documents yet.')),
                  ],
                );
              }

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final document = items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: VeyraDesign.primary.withValues(
                          alpha: .12,
                        ),
                        child: Icon(
                          document.contentType == 'application/pdf'
                              ? Icons.picture_as_pdf_rounded
                              : Icons.image_rounded,
                          color: VeyraDesign.primary,
                        ),
                      ),
                      title: Text(
                        document.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${document.employeeName} · ${document.category}'
                        '${document.expiryDateKey == null ? '' : '\nExpires ${document.expiryDateKey}'}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'link') _copyLink(document);
                          if (value == 'delete') _delete(document);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'link',
                            child: Text('Copy secure link'),
                          ),
                          if (_role.canManageCompany ||
                              document.employeeId == _employeeId)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDocument,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Upload'),
      ),
    );
  }

  Future<void> _addDocument() async {
    final file = await _service.pickDocument();
    if (file == null || !mounted) return;

    final employee = TextEditingController(text: _employeeId);
    String category = 'Contract';
    DateTime? expiry;
    final notes = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Upload employee document'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_role.canManageCompany)
                  TextField(
                    controller: employee,
                    decoration: const InputDecoration(labelText: 'Employee ID'),
                  ),
                if (_role.canManageCompany) const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items:
                      const [
                            'IC / Passport',
                            'Offer Letter',
                            'Contract',
                            'Certificate',
                            'Medical',
                            'Other',
                          ]
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => category = value);
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: expiry ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(DateTime.now().year + 20),
                    );
                    if (picked != null) {
                      setDialogState(() => expiry = picked);
                    }
                  },
                  icon: const Icon(Icons.event_rounded),
                  label: Text(
                    expiry == null ? 'Expiry date (optional)' : _key(expiry!),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 10),
                Text(
                  file.name,
                  style: const TextStyle(color: VeyraDesign.muted),
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
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || employee.text.trim().isEmpty) {
      employee.dispose();
      notes.dispose();
      return;
    }

    try {
      await _service.uploadAndRegister(
        file: file,
        targetEmployeeId: employee.text.trim(),
        category: category,
        expiryDateKey: expiry == null ? null : _key(expiry!),
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      );
      await _reload();
      if (mounted) _notice('Document uploaded.');
    } catch (error) {
      if (mounted) _notice(_friendly(error));
    } finally {
      employee.dispose();
      notes.dispose();
    }
  }

  Future<void> _copyLink(EmployeeDocument document) async {
    try {
      final url = await _service.downloadUrl(document);
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) _notice('Secure document link copied.');
    } catch (error) {
      if (mounted) _notice(_friendly(error));
    }
  }

  Future<void> _delete(EmployeeDocument document) async {
    try {
      await _service.delete(document);
      await _reload();
      if (mounted) _notice('Document removed.');
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

  static String _key(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
