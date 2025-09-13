// home_page.dart

import 'package:flutter/material.dart';
import 'package:operation_sunrise/change_notifier/level_controller.dart';
import 'package:operation_sunrise/game_screen.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // We use .read here because we only need the controller to get the future.
    // The Consumer below will handle rebuilding on updates.
    final levelController = context.read<LevelController>();

    return FutureBuilder(
      // Wait for the signal that the first SERVER sync is complete.
      future: levelController.initializationComplete,
      builder: (context, snapshot) {
        // While waiting for the signal, show a loading spinner.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If the initial load failed...
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

        // --- Initial load is complete! ---
        // Now we use a Consumer to listen for all subsequent updates,
        // such as changing levels from the menu.
        return Consumer<LevelController>(
          builder: (context, controller, child) {
            if (controller.currentLevel == null) {
              return const Scaffold(
                backgroundColor: Colors.black,
                body: Center(child: Text('No levels found.', style: TextStyle(color: Colors.white))),
              );
            }
            // This will build with the correct initial level from the notification,
            // and will also correctly update when you change levels from the drawer.
            return GameScreen(levelInfo: controller.currentLevel!);
          },
        );
      },
    );
  }
}