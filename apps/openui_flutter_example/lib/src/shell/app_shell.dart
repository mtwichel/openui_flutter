import 'package:flutter/material.dart';

import 'package:openui_flutter_example/src/llm_chat/llm_chat_screen.dart';
import 'package:openui_flutter_example/src/scripts_chat/chat_screen.dart';

/// Responsive two-destination shell for the example app.
///
/// On viewports ≥ 900 px wide, destinations are switched via a permanent
/// [NavigationRail]. On narrower viewports, a [Drawer] is used instead and
/// each destination receives an `onMenuTap` callback that opens the drawer.
class AppShell extends StatefulWidget {
  /// Creates an [AppShell].
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const double _wideBreakpoint = 900;

  int _index = 0;
  final GlobalKey<ScaffoldState> _narrowScaffoldKey =
      GlobalKey<ScaffoldState>();

  static const List<_Destination> _destinations = <_Destination>[
    _Destination(label: 'Scripts', icon: Icons.list_alt_outlined),
    _Destination(label: 'Live', icon: Icons.chat_bubble_outline),
  ];

  Widget _screenFor(int i, VoidCallback? onMenuTap) {
    switch (i) {
      case 0:
        return ScriptsChatScreen(onMenuTap: onMenuTap);
      case 1:
        return LlmChatScreen(onMenuTap: onMenuTap);
      default:
        throw StateError('Unknown destination index: $i');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        label: Text(d.label),
                      ),
                  ],
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _screenFor(_index, null)),
              ],
            ),
          );
        }
        return Scaffold(
          key: _narrowScaffoldKey,
          drawer: Drawer(
            child: SafeArea(
              child: ListView(
                children: [
                  for (var i = 0; i < _destinations.length; i++)
                    ListTile(
                      leading: Icon(_destinations[i].icon),
                      title: Text(_destinations[i].label),
                      selected: _index == i,
                      onTap: () {
                        setState(() => _index = i);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
          ),
          body: _screenFor(
            _index,
            () => _narrowScaffoldKey.currentState?.openDrawer(),
          ),
        );
      },
    );
  }
}

class _Destination {
  const _Destination({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
