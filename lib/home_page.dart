// home_page.dart

import 'package:flutter/material.dart';
import 'package:operation_sunrise/change_notifier/level_controller.dart';
import 'package:operation_sunrise/game_screen.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
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

        return Consumer<LevelController>(
          builder: (context, controller, child) {
            if (controller.currentLevel == null) {
              return const Scaffold(
                backgroundColor: Colors.black,
                body: Center(child: Text('No levels found.', style: TextStyle(color: Colors.white))),
              );
            }
            // MODIFIED: Added a ValueKey.
            // This key tells Flutter that if the level ID changes, it should
            // create a brand new GameScreen widget with a fresh state,
            // completely eliminating any visual glitches from the previous level.
            return GameScreen(
              key: ValueKey(controller.currentLevel!.id),
              levelInfo: controller.currentLevel!,
            );
          },
        );
      },
    );
  }
}