import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/recipe_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import 'create_recipe/ingredients_screen.dart';
import 'explore/explore_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'saved/saved_screen.dart';

/// Hosts the five bottom-nav destinations.
///
/// The Create tab owns a nested Navigator so the ingredients → preferences →
/// results flow can push without losing the nav bar, which every one of those
/// screens shows in the designs.
class MainShell extends StatefulWidget {
  final NavTab initialTab;

  const MainShell({super.key, this.initialTab = NavTab.home});

  @override
  State<MainShell> createState() => MainShellState();

  /// Lets a descendant switch tabs — the home screen's "Create Recipe" button
  /// needs to land on the Create tab.
  static MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();
}

class MainShellState extends State<MainShell> {
  late NavTab _current = widget.initialTab;

  final _createNavigatorKey = GlobalKey<NavigatorState>();

  void goToTab(NavTab tab) {
    if (tab == _current) return;
    setState(() => _current = tab);
  }

  /// Starts the create flow from scratch on the Create tab.
  void startCreateFlow() {
    context.read<RecipeProvider>().reset();
    _createNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    goToTab(NavTab.create);
  }

  void _onNavTap(NavTab tab) {
    // Tapping the active Create tab resets the flow, which is the behaviour
    // people expect from a "start over" affordance.
    if (tab == NavTab.create && _current == NavTab.create) {
      _createNavigatorKey.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    goToTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back inside the create flow should unwind that flow, not leave the app.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nested = _createNavigatorKey.currentState;
        if (_current == NavTab.create && (nested?.canPop() ?? false)) {
          nested!.pop();
        } else if (_current != NavTab.home) {
          goToTab(NavTab.home);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: NavTab.values.indexOf(_current),
          // Order must match NavTab.values, which is what indexes this stack.
          children: [
            const HomeScreen(),
            const ExploreScreen(),
            Navigator(
              key: _createNavigatorKey,
              onGenerateRoute: (settings) => MaterialPageRoute(
                settings: settings,
                builder: (_) => const IngredientsScreen(),
              ),
            ),
            const SavedScreen(),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavBar(
          current: _current,
          onTap: _onNavTap,
        ),
      ),
    );
  }
}
