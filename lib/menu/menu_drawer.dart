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

    // Define a dark theme specifically for the drawer
    final drawerDarkTheme = ThemeData(
      fontFamily: "EpundaSlab",
      brightness: Brightness.dark,
      // A deep, dark background color for the drawer
      canvasColor: const Color(0xFF1F1F1F), 
      // An accent color for selected items, avatars, etc.
      primaryColor: Colors.tealAccent[400], 
      // Consistent styling for all ListTiles within the drawer
      listTileTheme: ListTileThemeData(
        iconColor: Colors.grey[400],
        selectedTileColor: Colors.grey[850],
        selectedColor: Colors.white,
      ),
      // Styling for dividers
      dividerTheme: DividerThemeData(
        color: Colors.grey[800],
        thickness: 1,
        space: 1,
      ),
      // Styling for circle avatars
      chipTheme: ChipThemeData(
        backgroundColor: Colors.tealAccent[400],
        labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: "EpundaSlab"),
      ),
    );

    return Theme(
      // Apply the custom dark theme to the Drawer and its children
      data: drawerDarkTheme,
      child: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                // A slightly different shade for the header background
                color: Colors.black.withOpacity(0.2),
                child: Text(
                  "Menu",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[200],
                  ),
                ),
              ),
              Consumer<MoneyController>(
                builder: (context, money, child) {
                  return ListTile(
                    leading: const Icon(Icons.diamond),
                    title: money.isSubscribed()
                        ? const Text("Premium Activated")
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
                    // Use a more vibrant color for the active switch
                    activeColor: Theme.of(context).primaryColor,
                  );
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Text(
                  "Levels",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
              for (final level in levelController.levels)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 15,
                    // Use the theme's primary color for the avatar background
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      level.levelNumber.toString(),
                      style: const TextStyle(
                        color: Colors.black, // Dark text on a bright background
                        fontWeight: FontWeight.bold,
                        fontFamily: "EpundaSlab"
                      ),
                    ),
                  ),
                  title: Text(level.characteristic),
                  selected: level.levelNumber == levelController.currentLevel?.levelNumber,
                  // The selectedTileColor is now handled by the ListTileTheme
                  onTap: () {
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
      ),
    );
  }
}