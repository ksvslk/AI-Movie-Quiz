import 'dart:io';

import 'package:flutter/material.dart';
import 'package:operation_sunrise/change_notifier/money_controller.dart';
import 'package:operation_sunrise/constants.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoDisplay extends StatefulWidget {
  const InfoDisplay({super.key});

  @override
  State<InfoDisplay> createState() => _InfoDisplayState();
}

class _InfoDisplayState extends State<InfoDisplay> {
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _getVersionInfo();
  }

  Future<void> _getVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version =
            'Version: ${packageInfo.version} (${packageInfo.buildNumber})';
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final moneyController = context.read<MoneyController>();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _version,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'EpundaSlab',
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          // Legal links
          Row(
            children: [
              if ((Platform.isIOS || Platform.isMacOS)) ...[
                InkWell(
                  onTap: () => _launchUrl(C.eulaAppleLink),
                  child: Text(
                    'Terms of Use',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'EpundaSlab',
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  ' • ',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'EpundaSlab',
                    color: Colors.grey[600],
                  ),
                ),
              ],
          
         
            ],
          ),
                        InkWell(
                onTap: () => _launchUrl(C.privacyLink),
                child: Text(
                  textAlign: TextAlign.start,
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'EpundaSlab',
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _launchUrl(C.contactUs),
                child: Text(
                  textAlign: TextAlign.start,
                  'Contact Us',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'EpundaSlab',
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          if ((Platform.isIOS || Platform.isMacOS)) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () => moneyController.restorePurchases(context),
              child: Text(
                'Restore Purchases',
                style: TextStyle(fontSize: 12, fontFamily: 'EpundaSlab'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
