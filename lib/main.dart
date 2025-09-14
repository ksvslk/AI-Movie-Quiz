// lib/main.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as dev;

// Firebase and other services
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:operation_sunrise/app/auth_gate.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

// Your App's specific imports
import 'package:operation_sunrise/firebase_options.dart';
import 'package:operation_sunrise/constants.dart';
import 'package:operation_sunrise/app/app_lifecycle.dart';
import 'package:operation_sunrise/change_notifier/ads_controller.dart';
import 'package:operation_sunrise/change_notifier/level_controller.dart';
import 'package:operation_sunrise/change_notifier/money_controller.dart';
import 'package:operation_sunrise/data/local_storage_settings_persistence.dart';
import 'package:operation_sunrise/data/settings_controller.dart';
import 'package:operation_sunrise/audio/audio_controller.dart';

Future<void> setUpRemoteConfig() async {
  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(minutes: 1),
    minimumFetchInterval: const Duration(minutes: 1),
  ));
  await remoteConfig.setDefaults(const {
    C.minutesBeforeFirstAd: 5,
    C.dayBeforeReviewTag: 1,
    C.minutesBeforeReviewTag: 15,
    C.premiumInfoText: "All hints + no ads",
  });
  remoteConfig.onConfigUpdated.listen((event) async {
    await remoteConfig.activate();
  });
  await remoteConfig.fetchAndActivate();
}

Future<void> initPlatformState() async {
  await Purchases.setLogLevel(LogLevel.verbose);
  PurchasesConfiguration configuration;
  if (Platform.isAndroid) {
    configuration = PurchasesConfiguration("goog_YvhiqISylTQpNNSPJLYaRQEWkME");
  } else {
    configuration = PurchasesConfiguration("appl_GbYuccaEqksdlTnhHOmmGULUqiX");
  }
  await Purchases.configure(configuration);
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

// --- Main App Entry Point ---

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  Logger.root.onRecord.listen((record) {
    if (record.level >= Level.INFO) {
      dev.log(record.message, time: record.time, level: record.level.value, name: record.loggerName, error: record.error, stackTrace: record.stackTrace);
    }
  });

  // Initialize core services
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.appAttest,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  // NOTE: The sign-in logic has been moved to AuthGate.

  await setUpRemoteConfig();
  await initPlatformState();

  // Prepare controllers
  AdsController? adsController;
  if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
    adsController = AdsController(MobileAds.instance);
  }

  if (Platform.isIOS || Platform.isMacOS) {
    final status = await AppTrackingTransparency.requestTrackingAuthorization();
    if (status == TrackingStatus.authorized && adsController != null) {
      adsController.requestTheLatestConsentInformation();
    }
  } else {
    if (adsController != null) {
      adsController.requestTheLatestConsentInformation();
    }
  }

  final settingsController = SettingsController(persistence: LocalStorageSettingsPersistence());
  await settingsController.loadStateFromPersistence();
  final levelController = LevelController(settingsController: settingsController);
  await levelController.setupFCMListeners();

  runApp(
    AppLifecycleObserver(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsController),
          ChangeNotifierProvider.value(value: levelController),
          ProxyProvider2<SettingsController, ValueNotifier<AppLifecycleState>, AudioController>(
            lazy: false,
            create: (context) => AudioController()..initialize(),
            update: (context, settings, lifecycleNotifier, audio) {
              if (audio == null) throw ArgumentError.notNull();
              audio.attachSettings(settings);
              audio.attachLifecycleNotifier(lifecycleNotifier);
              return audio;
            },
            dispose: (context, audio) => audio.dispose(),
          ),
          ChangeNotifierProxyProvider<ValueNotifier<AppLifecycleState>, AdsController?>(
            lazy: false,
            create: (context) => adsController,
            update: (context, lifecycleNotifier, ads) {
              if (ads != null) ads.attachLifecycleNotifier(lifecycleNotifier);
              return ads;
            },
          ),
          ChangeNotifierProvider(create: (context) => MoneyController()),
        ],
        // The AuthGate now manages the initial UI and authentication flow.
        child: const AuthGate(),
      ),
    ),
  );
}