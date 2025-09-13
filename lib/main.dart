import 'dart:io';
import 'dart:math' as _log;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';
import 'package:operation_sunrise/app/app_lifecycle.dart';
import 'package:operation_sunrise/audio/audio_controller.dart';
import 'package:operation_sunrise/change_notifier/ads_controller.dart';
import 'package:operation_sunrise/change_notifier/level_controller.dart';
import 'package:operation_sunrise/change_notifier/money_controller.dart';
import 'package:operation_sunrise/constants.dart';
import 'package:operation_sunrise/data/local_storage_settings_persistence.dart';
import 'package:operation_sunrise/data/settings_controller.dart';
import 'package:operation_sunrise/firebase_options.dart';
import 'package:operation_sunrise/home_page.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:developer' as dev;

Future<void> setUpRemoteConfig() async {
  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(
    RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(
        minutes: 1,
      ), //TODO: Change for production
    ),
  );
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

// This MUST remain a top-level function as required by the firebase_messaging plugin
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  // Ensure that all Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  //debugPaintSizeEnabled = true;
  // Subscribe to log messages.
  Logger.root.onRecord.listen((record) {
    if (record.level >= Level.INFO) {
      dev.log(
        record.message,
        time: record.time,
        level: record.level.value,
        name: record.loggerName,
        zone: record.zone,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    }
  });

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set the background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // Activate App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.appAttest,
  );

  await setUpRemoteConfig();

  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {}
  }

  await initPlatformState();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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

  final settingsController = SettingsController(
    persistence: LocalStorageSettingsPersistence(),
  );
  await settingsController.loadStateFromPersistence();
  final levelController = LevelController(
    settingsController: settingsController,
  );
  await levelController.setupFCMListeners();

  // FIXED: MultiProvider is now at the top level, wrapping the entire app.
  runApp(
    AppLifecycleObserver(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsController),
          ChangeNotifierProvider.value(value: levelController),
          ProxyProvider2<
            SettingsController,
            ValueNotifier<AppLifecycleState>,
            AudioController
          >(
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
          ChangeNotifierProxyProvider<
            ValueNotifier<AppLifecycleState>,
            AdsController?
          >(
            lazy: false,
            create: (context) => adsController,
            update: (context, lifecycleNotifier, ads) {
              if (ads != null) {
                ads.attachLifecycleNotifier(lifecycleNotifier);
              }
              return ads;
            },
          ),
          ChangeNotifierProvider(create: (context) => MoneyController()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // ADDED const

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Operation Sunrise',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
        fontFamily: "EpundaSlab",
      ),
      home: const HomePage(),
    );
  }
}
