import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/firebase_error_message.dart';
import '../features/assets/presentation/pages/asset_management_page.dart';
import '../features/audit/presentation/pages/audit_log_page.dart';
import '../features/employee_documents/presentation/pages/employee_documents_page.dart';
import '../features/identity/application/identity_service.dart';
import '../features/identity/domain/hrms_role.dart';
import '../features/identity/domain/tenant_identity.dart';
import '../features/lifecycle/presentation/pages/employee_lifecycle_page.dart';
import '../features/notifications/presentation/pages/notification_center_page.dart';
import '../features/performance/presentation/pages/performance_page.dart';
import '../features/reports/presentation/pages/reports_page.dart';
import '../features/workforce_time/presentation/pages/workforce_time_page.dart';
import 'edit_profile_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'work_time_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final IdentityService _identityService = IdentityService();

  TenantIdentity? _identity;
  bool _loading = true;
  bool _changingAvatar = false;
  Uint8List? _avatarBytes;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final avatarBase64 = prefs.getString('avatarBase64');
      Uint8List? avatarBytes;

      if (avatarBase64 != null && avatarBase64.isNotEmpty) {
        try {
          avatarBytes = base64Decode(avatarBase64);
        } catch (_) {
          await prefs.remove('avatarBase64');
        }
      }

      final identity = await _identityService.restoreIdentity();
      if (!mounted) return;

      if (identity == null) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }

      setState(() {
        _identity = identity;
        _avatarBytes = avatarBytes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = firebaseErrorMessage(error);
      });
    }
  }

  Future<void> _changeAvatar() async {
    if (_changingAvatar) return;

    setState(() => _changingAvatar = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose an image smaller than 5 MB.')),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatarBase64', base64Encode(bytes));
      if (!mounted) return;
      setState(() => _avatarBytes = bytes);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _changingAvatar = false);
      }
    }
  }

  void _onLogoutPressed() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await _identityService.signOut();
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(firebaseErrorMessage(error))),
                );
                return;
              }

              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _loadAllData,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final identity = _identity;
    if (identity == null) {
      return const SizedBox.shrink();
    }

    final role = identity.role;
    final isCompanyAdmin =
        role == HrmsRole.companyOwner || role == HrmsRole.hrAdmin;
    final isManagement = role.canApprove;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4FACFE).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _changingAvatar ? null : _changeAvatar,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.white30,
                            backgroundImage: _avatarBytes != null
                                ? MemoryImage(_avatarBytes!)
                                : null,
                            child: _avatarBytes == null
                                ? const Icon(
                                    Icons.person,
                                    size: 45,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: _changingAvatar
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Color(0xFF4FACFE),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            identity.displayName.isEmpty
                                ? identity.employeeId
                                : identity.displayName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${identity.employeeId}  ·  ${identity.department}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _roleLabel(role),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit profile',
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(
                              currentName: identity.displayName,
                              currentDepartment: identity.department,
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadAllData();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildMenuItem(
                    icon: Icons.checklist_rounded,
                    title: 'Attendance Statistics',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistoryScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    icon: Icons.inventory_2_rounded,
                    title: isCompanyAdmin ? 'Asset Management' : 'My Assets',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AssetManagementPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    icon: Icons.route_rounded,
                    title: 'Onboarding & Offboarding',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmployeeLifecyclePage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    icon: Icons.insights_rounded,
                    title: 'Performance & KPI',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PerformancePage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    icon: Icons.folder_copy_rounded,
                    title: 'Employee Documents',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmployeeDocumentsPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    icon: Icons.more_time_rounded,
                    title: 'Holiday, Shift & Overtime',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WorkforceTimePage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (isManagement) ...[
                    _buildMenuItem(
                      icon: Icons.analytics_rounded,
                      title: 'Reports & Analytics',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReportsPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (isCompanyAdmin) ...[
                    _buildMenuItem(
                      icon: Icons.history_rounded,
                      title: 'Audit Log',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AuditLogPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      icon: Icons.schedule_rounded,
                      title: 'Work Time Settings',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WorkTimeSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildMenuItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationCenterPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    icon: Icons.info_outline_rounded,
                    title: 'About',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Veyra HRMS',
                        applicationVersion: '3.1.7',
                        children: const [
                          Text(
                            'Secure multi-tenant workforce operations and HR management.',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _onLogoutPressed,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.paddingOf(context).bottom + 104,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(HrmsRole role) {
    return switch (role) {
      HrmsRole.superAdmin => 'Super Admin',
      HrmsRole.companyOwner => 'Company Owner',
      HrmsRole.hrAdmin => 'HR Admin',
      HrmsRole.manager => 'Manager',
      HrmsRole.employee => 'Employee',
    };
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.03),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4FACFE)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
