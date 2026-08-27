// lib/main.dart

import 'dart:io';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as dev;

// Firebase and other services
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:operation_sunrise/app/auth_gate.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

// --- NEW: Moved from AuthGate ---
/// Tries to sign in the user anonymously with an exponential backoff retry strategy.
/// Tier-1 identity link: tag analytics with our own pseudonymous id (the
/// Firebase anonymous-auth uid — no PII) and register this install's push
/// token keyed by that uid, so personal code delivery can reach it.
Future<void> _linkIdentity() async {
  if (kIsWeb) return;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    await FirebaseAnalytics.instance.setUserId(id: user.uid);
  } catch (e) {
    dev.log('setUserId failed: $e');
  }
  final info = await PackageInfo.fromPlatform();
  Future<void> save(String? token) async {
    if (token == null) return;
    final col = Platform.isIOS ? 'fcmTokensIos' : 'fcmTokensAndroid';
    try {
      await FirebaseFirestore.instance.collection(col).doc(user.uid).set({
        'token': token,
        'appVersion': info.version,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      dev.log('push token registration failed: $e');
    }
  }

  FirebaseMessaging.instance.getToken().then(save);
  FirebaseMessaging.instance.onTokenRefresh.listen(save);

  // Keep "last seen" honest for long-lived processes: a player who never
  // cold-starts would otherwise look stale. Throttled to once per hour.
  DateTime? lastTouch;
  WidgetsBinding.instance.addObserver(
    _OnResume(() {
      final now = DateTime.now();
      if (lastTouch != null &&
          now.difference(lastTouch!) < const Duration(hours: 1)) {
        return;
      }
      lastTouch = now;
      FirebaseMessaging.instance.getToken().then(save);
    }),
  );
}

class _OnResume extends WidgetsBindingObserver {
  _OnResume(this.onResume);
  final void Function() onResume;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

Future<void> signInAnonymouslyWithRetry() async {
  if (FirebaseAuth.instance.currentUser != null) {
    dev.log('User already signed in.');
    return;
  }

  const maxRetries = 5;
  const initialDelay = Duration(seconds: 1);
  const maxJitter = Duration(milliseconds: 500);
  final random = Random();

  for (int attempt = 0; attempt < maxRetries; attempt++) {
    try {
      dev.log('Attempting to sign in anonymously (Attempt ${attempt + 1})...');
      await FirebaseAuth.instance.signInAnonymously();
      dev.log('Successfully signed in anonymously.');
      return; // Success
    } on FirebaseAuthException catch (e) {
      dev.log(
        'Failed to sign in (Attempt ${attempt + 1}/$maxRetries): ${e.code}',
        level: Level.WARNING.value,
        error: e,
      );
      if (attempt == maxRetries - 1) {
        dev.log(
          'Max sign-in retries reached. Failing permanently.',
          level: Level.SEVERE.value,
        );
        rethrow; // Re-throw the last exception
      }
      final backoffTime = initialDelay * pow(2, attempt);
      final jitter = Duration(
        milliseconds: random.nextInt(maxJitter.inMilliseconds),
      );
      final totalDelay = backoffTime + jitter;
      dev.log('Waiting for ${totalDelay.inMilliseconds}ms before next retry.');
      await Future.delayed(totalDelay);
    }
  }
}
// --- END NEW SECTION ---

Future<void> setUpRemoteConfig() async {
  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(
    RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(hours: 6),
    ),
  );
  await remoteConfig.setDefaults(const {
    C.dayBeforeFasterAds: 1,
    C.dayBeforeReviewTag: 1,
    C.minutesBeforeFirstAd: 5,
    C.minutesBeforeReviewTag: 15,
    C.testAdsTag: false,
    C.premiumInfoText: "All hints + no ads",
    C.showPaywallBeforeAdsTag: true,
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
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Stagenator code-drop pushes carry a claimUrl in their data payload.
/// Open it when the user taps the notification — whether the tap cold-starts
/// the app or brings it back from the background. Without this the tap just
/// opens the app and the claim link is silently dropped.
void _handleClaimUrlTaps() {
  // Both tap hooks can deliver the SAME message on a cold start (verified on
  // device: two browser launches). Dedupe by URL within a short window.
  String? lastUrl;
  DateTime? lastAt;
  // Replay guard: reopening the app re-delivers the tap intent (task root)
  // and the plugin re-fires from its cache. Native keeps a persisted set of
  // consumed message ids (survives engine restarts); the session set covers
  // iOS, where the native channel does not exist.
  const nativeGuard = MethodChannel('stagenator/claim');
  final sessionIds = <String>{};
  Future<void> open(RemoteMessage? message) async {
    final id = message?.messageId;
    if (kDebugMode && message != null) {
      debugPrint('sgclaim open: id=$id data=${message.data}');
    }
    if (id != null) {
      if (!sessionIds.add(id)) return; // duplicate within this session
      bool fresh = true;
      try {
        fresh = await nativeGuard.invokeMethod<bool>('consume', id) ?? true;
      } catch (_) {
        // iOS / channel unavailable: session set + URL window suffice
      }
      if (!fresh) return; // already handled in an earlier session
    }
    final url = message?.data['claimUrl'];
    if (url is String && url.startsWith('https://')) {
      final now = DateTime.now();
      if (url == lastUrl &&
          lastAt != null &&
          now.difference(lastAt!) < const Duration(seconds: 15)) {
        return; // same tap delivered twice
      }
      lastUrl = url;
      lastAt = now;
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (e) {
        dev.log('claimUrl launch failed: $e', level: Level.WARNING.value);
      }
    }
  }

  FirebaseMessaging.instance.getInitialMessage().then(open);
  FirebaseMessaging.onMessageOpenedApp.listen(open);

  // Native fallback: MainActivity captures claimUrl from the launch intent on
  // every entry path, closing the plugin's lost-event race (process alive,
  // activity destroyed, engine still booting). The dedupe guard above makes
  // this safe to run alongside the plugin paths.
  const nativeChannel = MethodChannel('stagenator/claim');
  Future<void> openRaw(dynamic url) async {
    if (kDebugMode) debugPrint('sgclaim native: $url');
    if (url is String) {
      await open(RemoteMessage(data: {'claimUrl': url}));
    }
  }

  nativeChannel.setMethodCallHandler((call) async {
    if (call.method == 'claimUrl') await openRaw(call.arguments);
  });
  nativeChannel
      .invokeMethod<String>('getPendingClaimUrl')
      .then(openRaw)
      .catchError((_) => null); // channel absent on iOS — plugin paths suffice
}


// --- Main App Entry Point ---

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  Logger.root.onRecord.listen((record) {
    if (record.level >= Level.INFO) {
      dev.log(
        record.message,
        time: record.time,
        level: record.level.value,
        name: record.loggerName,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    }
  });

  // Initialize core services
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode
        ? AppleProvider.debug
        : AppleProvider.appAttestWithDeviceCheckFallback,
  );

  // --- NEW: Perform anonymous sign-in right after App Check ---
  try {
    await signInAnonymouslyWithRetry();
  } catch (e) {
    dev.log(
      'Anonymous sign-in failed after all retries. The app will show an error screen.',
      error: e,
      level: Level.SEVERE.value,
    );
    // We will let the app continue to run. The AuthGate will see
    // that `currentUser` is null and show the error screen.
  }
  await _linkIdentity();
  // --- END NEW SECTION ---

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  _handleClaimUrlTaps();
  if (kDebugMode) {
    // test aid only: surface this install's FCM token for console test pushes
    FirebaseMessaging.instance.getToken().then((t) => debugPrint('FCM token: $t'));
  }
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

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

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    AppLifecycleObserver(
      child: MultiProvider(
        providers: [
          // 1. CREATE SettingsController HERE using a ProxyProvider.
          // This allows it to depend on the lifecycle notifier.
          ChangeNotifierProxyProvider<
            ValueNotifier<AppLifecycleState>,
            SettingsController
          >(
            create: (context) => SettingsController(
              persistence: LocalStorageSettingsPersistence(),
            )..loadStateFromPersistence(), // Load state upon creation
            update: (context, lifecycleNotifier, settings) {
              if (settings == null) throw ArgumentError.notNull();
              settings.attachLifecycleNotifier(
                lifecycleNotifier,
              ); // Attach here
              return settings;
            },
          ),

          // 2. CREATE LevelController HERE. It now depends on the
          // SettingsController created just above.
          ChangeNotifierProxyProvider<SettingsController, LevelController>(
            create: (context) => LevelController(
              // Read the controller from the context
              settingsController: context.read<SettingsController>(),
            )..setupFCMListeners(),
            update: (context, settings, level) {
              if (level == null) throw ArgumentError.notNull();
              // No update logic needed, but the pattern requires it.
              return level;
            },
          ),
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
