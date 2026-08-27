import 'package:flutter/material.dart';

import '../theme/veyra_design.dart';

import '../../features/attendance/presentation/pages/attendance_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/identity/domain/hrms_role.dart';
import '../../screens/company_code_screen.dart';
import '../../screens/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.role, required this.hrmsRole});

  final String role;
  final HrmsRole hrmsRole;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _dashboardRefreshToken = 0;

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0) {
        _dashboardRefreshToken++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canShowCompanyCode = widget.hrmsRole.canApprove;

    final pages = <Widget>[
      DashboardPage(
        role: widget.role,
        hrmsRole: widget.hrmsRole,
        refreshToken: _dashboardRefreshToken,
        onAttendanceAction: () => _selectTab(1),
      ),
      canShowCompanyCode ? const CompanyCodeScreen() : const AttendancePage(),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: DecoratedBox(
        decoration: VeyraDesign.pageBackground,
        child: IndexedStack(index: _currentIndex, children: pages),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _selectTab,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(
                canShowCompanyCode
                    ? Icons.qr_code_2_outlined
                    : Icons.schedule_outlined,
              ),
              selectedIcon: Icon(
                canShowCompanyCode
                    ? Icons.qr_code_2_rounded
                    : Icons.schedule_rounded,
              ),
              label: canShowCompanyCode ? 'Code' : 'Attendance',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
