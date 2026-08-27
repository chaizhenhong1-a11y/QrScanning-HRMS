import 'package:flutter/material.dart';
import 'history_screen.dart';
import 'face_attendance_screen.dart';
import 'leave_screen.dart';
import 'claims_screen.dart';
import 'payslip_screen.dart';
import 'income_tax_screen.dart';
import 'hr_memos_screen.dart';
import 'company_policy_screen.dart';
import 'meeting_room_screen.dart';
import 'flexible_work_screen.dart';
import 'training_feedback_screen.dart';
import 'rewards_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final List<Map<String, dynamic>> menuItems = const [
    {
      'title': 'Face Attendance',
      'icon': Icons.face_rounded,
      'color': Color(0xFF4FACFE),
    },
    {
      'title': 'Attendance',
      'icon': Icons.punch_clock_rounded,
      'color': Color(0xFF2575FC),
    },
    {
      'title': 'Leave',
      'icon': Icons.beach_access_rounded,
      'color': Color(0xFFFF416C),
    },
    {
      'title': 'Claims',
      'icon': Icons.receipt_long_rounded,
      'color': Color(0xFF11998E),
    },
    {
      'title': 'Payslip',
      'icon': Icons.description_rounded,
      'color': Color(0xFFF2994A),
    },
    {
      'title': 'Income Tax',
      'icon': Icons.account_balance_rounded,
      'color': Color(0xFF7F00FF),
    },
    {
      'title': 'HR Memos',
      'icon': Icons.campaign_rounded,
      'color': Color(0xFFFF4B2B),
    },
    {
      'title': 'Company Policy',
      'icon': Icons.policy_rounded,
      'color': Color(0xFF38EF7D),
    },
    {
      'title': 'Meeting Room',
      'icon': Icons.meeting_room_rounded,
      'color': Color(0xFF00C6FF),
    },
    {
      'title': 'Flexible Work',
      'icon': Icons.work_outline_rounded,
      'color': Color(0xFF56CCF2),
    },
    {
      'title': 'Training Feedback',
      'icon': Icons.school_rounded,
      'color': Color(0xFFB12A5B),
    },
    {
      'title': 'Rewards',
      'icon': Icons.card_giftcard_rounded,
      'color': Color(0xFFEA00D9),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3F6FA), Color(0xFFE3EDF7)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0072FF).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Employee Self Service',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Work smarter, starting today',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = menuItems[index];
                    return _buildModernCard(
                      context,
                      title: item['title'],
                      icon: item['icon'],
                      baseColor: item['color'],
                    );
                  }, childCount: menuItems.length),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color baseColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        // 将背景改为半透明白色，与背景融合
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        // 阴影改为更轻淡，或直接移除
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            switch (title) {
              case 'Attendance':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
                break;
              case 'Face Attendance':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FaceAttendanceScreen(),
                  ),
                );
                break;
              case 'Leave':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaveScreen()),
                );
                break;
              case 'Claims':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClaimsScreen()),
                );
                break;
              case 'Payslip':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PayslipScreen()),
                );
                break;
              case 'Income Tax':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IncomeTaxScreen()),
                );
                break;
              case 'HR Memos':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HrMemosScreen()),
                );
                break;
              case 'Company Policy':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CompanyPolicyScreen(),
                  ),
                );
                break;
              case 'Meeting Room':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MeetingRoomScreen()),
                );
                break;
              case 'Flexible Work':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FlexibleWorkScreen()),
                );
                break;
              case 'Training Feedback':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TrainingFeedbackScreen(),
                  ),
                );
                break;
              case 'Rewards':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RewardsScreen()),
                );
                break;
              default:
                Navigator.pushNamed(context, '/feature', arguments: title);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        baseColor.withValues(alpha: 0.12),
                        baseColor.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                  child: Icon(icon, size: 26, color: baseColor),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
