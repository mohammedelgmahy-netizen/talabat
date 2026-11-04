import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// شريط التنقل السفلي لكل دور
class RoleShell extends StatelessWidget {
  const RoleShell({super.key, required this.shell, required this.destinations});

  final StatefulNavigationShell shell;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: destinations,
      ),
    );
  }
}
