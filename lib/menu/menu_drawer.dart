// menu/menu_drawer.dart

import 'package:flutter/material.dart';
import 'package:operation_sunrise/change_notifier/level_controller.dart';
import 'package:operation_sunrise/change_notifier/money_controller.dart';
import 'package:operation_sunrise/data/settings_controller.dart';
import 'package:operation_sunrise/menu/info_display.dart';
import 'package:provider/provider.dart';

class MenuDrawer extends StatelessWidget {
  const MenuDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsController>();
    final levelController = context.watch<LevelController>();

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: const Text(
                "Menu",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Consumer<MoneyController>(
              builder: (context, money, child) {
                return ListTile(
                  leading: const Icon(Icons.diamond),
                  title: money.isSubscribed()
                      ? const Text("You own Premium")
                      : Text(money.getProductFriendlyInfo() ?? "..."),
                  subtitle: money.isSubscribed()
                      ? null
                      : Text(money.getDescriptionOfProduct()),
                  onTap: money.isSubscribed()
                      ? null
                      : () {
                          money.purchaseSubscription();
                        },
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: settings.soundsOn,
              builder: (context, soundsOn, child) {
                return SwitchListTile(
                  title: const Text("Sound"),
                  value: soundsOn,
                  onChanged: (bool value) {
                    settings.toggleSoundsOn();
                  },
                  secondary: const Icon(Icons.volume_up),
                );
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text("Levels", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final level in levelController.levels)
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 15,
                  child: Text(level.levelNumber.toString()),
                ),
                title: Text(level.name),
                selected: level.levelNumber == levelController.currentLevel?.levelNumber,
                selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.2),
                onTap: () {
                  // This logic correctly updates the state.
                  // The fix in GameScreen will now allow it to react properly.
                  Navigator.of(context).pop();
                  settings.setLastPlayedLevel(level.levelNumber);
                  levelController.selectLevelByNumber(level.levelNumber);
                },
              ),
            const Divider(),
            const InfoDisplay(),
          ],
        ),
      ),
    );
  }
}