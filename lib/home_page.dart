// home_page.dart

import 'package:flutter/material.dart';
import 'package:operation_sunrise/change_notifier/level_controller.dart';
import 'package:operation_sunrise/data/level_info.dart';
import 'package:operation_sunrise/game_screen.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // We still use .read here because we only need the controller instance
    // to access its initialization future. We don't want the HomePage
    // itself to rebuild.
    final levelController = context.read<LevelController>();

    return FutureBuilder(
      future: levelController.initializationComplete,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'Error loading levels: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        // Use Selector instead of Consumer.
        // It listens to the LevelController, but only rebuilds when the
        // selected value (the Level object itself) changes.
        return Selector<LevelController, LevelInfo?>(
          // 1. SELECT the specific piece of state to watch.
          // The builder below will only run if controller.currentLevel changes.
          selector: (_, controller) => controller.currentLevel,

          // 2. BUILD the UI based on the selected value.
          // `currentLevel` here is the value returned from the selector.
          builder: (context, currentLevel, child) {
            if (currentLevel == null) {
              return const Scaffold(
                backgroundColor: Colors.black,
                body: Center(child: Text('No levels found.', style: TextStyle(color: Colors.white))),
              );
            }

            // The ValueKey is still crucial. Selector decides WHEN to rebuild,
            // and the ValueKey tells Flutter HOW to rebuild (by creating a
            // brand new widget with a fresh state). They work together perfectly.
            return GameScreen(
              key: ValueKey(currentLevel.id),
              levelInfo: currentLevel,
            );
          },
        );
      },
    );
  }
}