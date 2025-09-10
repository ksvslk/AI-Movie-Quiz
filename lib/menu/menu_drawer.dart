import 'package:flutter/material.dart';
import 'package:operation_sunrise/change_notifier/money_controller.dart';
import 'package:operation_sunrise/database/settings_controller.dart';
import 'package:operation_sunrise/menu/info_display.dart';
import 'package:provider/provider.dart';

// Re-using your existing enums
enum ThemeSubMenuItem { red, yellow, green, blue, purple }

class MenuDrawer extends StatelessWidget {
  final GlobalKey<NavigatorState> parentNavigatorKey;

  const MenuDrawer({super.key, required this.parentNavigatorKey});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsController>(context, listen: false);

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Drawer header
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Text(
                "Menu",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            Consumer<MoneyController>(
              builder: (context, money, child) {
                return ListTile(
                  leading: Icon(
                    money.isSubscribed() ? Icons.diamond : Icons.diamond,
                  ),
                  title: money.isSubscribed()
                      ? Text("You own Premium")
                      : Text(money.getProductFriendlyInfo() ?? "..."),
                     subtitle: money.isSubscribed() 
                  ? null 
                  : Text("Remove ads/popups"),
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
                  title: Text("Sound"),
                  value: soundsOn,
                  onChanged: (bool value) {
                    settings.toggleSoundsOn();
                  },
                  secondary: const Icon(Icons.volume_up),
                );
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
