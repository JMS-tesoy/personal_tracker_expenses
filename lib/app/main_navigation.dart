import 'package:flutter/material.dart';
import '../features/activity/presentation/screens/activity_timeline_screen.dart';
import '../features/bills/presentation/screens/bills_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/loans/presentation/screens/loans_screen.dart';
import '../features/people/presentation/screens/people_screen.dart';
import '../features/reminders/presentation/screens/reminders_screen.dart';
import '../features/transactions/presentation/screens/transactions_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _showActivity = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = <Widget>[
      DashboardScreen(onOpenActivity: _openActivity),
      const TransactionsScreen(),
      const BillsScreen(),
      const LoansScreen(),
      const PeopleScreen(),
      const RemindersScreen(),
    ];
  }

  void _openActivity() {
    setState(() => _showActivity = true);
  }

  void _closeActivity() {
    setState(() => _showActivity = false);
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _showActivity = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _showActivity
          ? ActivityTimelineScreen(onBack: _closeActivity)
          : _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant.withValues(
          alpha: 0.62,
        ),
        backgroundColor: const Color(0xFF252A31).withValues(alpha: 0.96),
        elevation: 0,
        onTap: _selectTab,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Bills',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_outlined),
            activeIcon: Icon(Icons.account_balance),
            label: 'Loans',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'People',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Reminders',
          ),
        ],
      ),
    );
  }
}
