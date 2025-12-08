// menu/menu_drawer.dart

import 'package:flutter/material.dart';
import 'package:operation_sunrise/change_notifier/ads_controller.dart';
import 'package:operation_sunrise/change_notifier/level_controller.dart';
import 'package:operation_sunrise/change_notifier/money_controller.dart';
import 'package:operation_sunrise/data/settings_controller.dart';
import 'package:operation_sunrise/menu/info_display.dart';
import 'package:provider/provider.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

class MenuDrawer extends StatefulWidget {
  const MenuDrawer({super.key});

  @override
  State<MenuDrawer> createState() => _MenuDrawerState();
}

class _MenuDrawerState extends State<MenuDrawer> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Schedule the scroll to happen after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedLevel();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedLevel() {
    final levelController = context.read<LevelController>();
    if (levelController.currentLevel != null) {
      // Find the index of the current level
      final currentLevelIndex = levelController.levels.indexWhere(
        (level) => level.levelNumber == levelController.currentLevel!.levelNumber,
      );
      
      if (currentLevelIndex != -1 && _scrollController.hasClients) {
        // Calculate the position to scroll to
        // Assuming each ListTile has approximately 56 pixels height (default dense ListTile)
        const itemHeight = 56.0;
        final targetOffset = currentLevelIndex * itemHeight;
        
        // Get the viewport height to center the item
        final viewportHeight = _scrollController.position.viewportDimension;
        final centeredOffset = targetOffset - (viewportHeight / 2) + (itemHeight / 2);
        
        // Ensure we don't scroll beyond the bounds
        final maxScrollExtent = _scrollController.position.maxScrollExtent;
        final finalOffset = centeredOffset.clamp(0.0, maxScrollExtent);
        _scrollController.jumpTo(
          finalOffset,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final levelController = context.watch<LevelController>();

    // Define a dark theme specifically for the drawer
    final drawerDarkTheme = ThemeData(
      fontFamily: "EpundaSlab",
      brightness: Brightness.dark,
      // A deep, dark background color for the drawer
      canvasColor: const Color(0xFF1F1F1F),
      // An accent color for selected items, avatars, etc.
      primaryColor: const Color.fromARGB(255, 255, 200, 0),
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
        backgroundColor: const Color.fromARGB(255, 255, 200, 0),
        labelStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontFamily: "EpundaSlab",
        ),
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
                        : Text("Upgrade Now"),
                    subtitle: money.isSubscribed()
                        ? null
                        : Text("Hints. Skip. No Ads."),
                    onTap: money.isSubscribed()
                        ? null
                        : () {
                            RevenueCatUI.presentPaywall(displayCloseButton: true);
                            //money.purchaseSubscription();
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
                    activeThumbColor: Theme.of(context).primaryColor,
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: settings.autoplayOn,
                builder: (context, autoplayOn, child) {
                  return SwitchListTile(
                    title: const Text("Autoplay"),
                    value: autoplayOn,
                    onChanged: (bool value) {
                      settings.toggleAutoplayOn();
                    },
                    secondary: const Icon(Icons.auto_mode),
                    // Use a more vibrant color for the active switch
                    activeThumbColor: Theme.of(context).primaryColor,
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: settings.loopingOn,
                builder: (context, loopingOn, child) {
                  return SwitchListTile(
                    title: const Text("Looping"),
                    value: loopingOn,
                    onChanged: (bool value) {
                      settings.toggleLoopingOn();
                    },
                    secondary: const Icon(Icons.loop),
                    // Use a more vibrant color for the active switch
                    activeThumbColor: Theme.of(context).primaryColor,
                  );
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Text(
                  "Levels",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(
                height: 300, // Example fixed height
                child: ListView.builder(
                  controller: _scrollController, // Add the scroll controller here
                  shrinkWrap: true,
                  itemCount: levelController.levels.length,
                  itemBuilder: (context, index) {
                    final level = levelController.levels[index];
                    final isCompleted = settings.isLevelCompleted(
                      level.levelNumber,
                    );
                    return ListTile(
                      dense: true,
                      leading: Stack(
                        clipBehavior: Clip
                            .none, // Allows the icon to render outside the stack's bounds
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Text(
                              level.levelNumber.toString(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontFamily: "EpundaSlab",
                              ),
                            ),
                          ),
                          if (isCompleted)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(
                                  2,
                                ), // Optional space around the icon
                                decoration: const BoxDecoration(
                                  color: Colors.green, // Your background color
                                  shape:
                                      BoxShape.circle, // This makes it a circle
                                ),
                                child: const Icon(
                                  Icons
                                      .check, // Using a simple check as the circle is now the background
                                  color:
                                      Colors.white, // Color for the icon itself
                                  size: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(level.characteristic),
                      selected:
                          level.levelNumber ==
                          levelController.currentLevel?.levelNumber,
                      onTap: () async {
                        Navigator.of(context).pop();
                        settings.setLastPlayedLevel(level.levelNumber);
                        levelController.selectLevelByNumber(level.levelNumber);
                        final moneyController = context.read<MoneyController>();
                        final adsController = context.read<AdsController>();
                        final settingsController = context
                            .read<SettingsController>();
                        if (await settingsController
                                .shouldShowInterstitialAd() &&
                            !moneyController.isSubscribed() &&
                            adsController.isInterstitialAvailable()) {
                          adsController.showInterstitialAd();
                        }
                      },
                    );
                  },
                ),
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