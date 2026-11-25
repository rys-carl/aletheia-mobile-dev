import 'package:flutter/material.dart';

import 'package:aletheia_dev/features/entry/entry_form_page.dart';
import 'package:aletheia_dev/features/home/home_page.dart';
import 'package:aletheia_dev/features/map/map_page.dart';
import 'package:aletheia_dev/widgets/app_bottom_bar.dart';

/// The signed-in app frame: Home and Map tabs plus the "+" button.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Future<void> _addMemory() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const EntryFormPage()),
    );
    // Jump back to the list so the new memory is the first thing you see.
    if (created == true && mounted) setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomePage(),
          MapPage(),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        currentIndex: _index,
        onSelected: (i) => setState(() => _index = i),
        onAdd: _addMemory,
      ),
    );
  }
}
