// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async'; // Import the async library for Timer
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';
import 'package:operation_sunrise/constants.dart';
import 'package:operation_sunrise/globals.dart'; // >>> ADDED: Import your global notifier

/// Allows showing ads. A facade for `package:google_mobile_ads`.
class AdsController extends ChangeNotifier {
  static final _log = Logger('AdsController');

  final MobileAds _instance;
  final int _maxRetryCount = 25; // Maximum number of retries

  int _rewardedRetryCount = 0;
  int _intersitialRetryCount = 0;
  int _consentRetryCount = 0;
  final Duration _initialDelay = const Duration(seconds: 1); // Initial delay

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  ValueNotifier<AppLifecycleState>? _lifecycleNotifier;
  TrackingStatus? _lastTrackingStatus;

  // Timers to handle ad expiration
  Timer? _rewardedAdTimer;
  Timer? _interstitialAdTimer;

  final rewardedAdUnitId = FirebaseRemoteConfig.instance.getBool(C.testAdsTag)
      ? (defaultTargetPlatform == TargetPlatform.android
            // Android
            ? 'ca-app-pub-3940256099942544/5224354917'
            // iOS
            : 'ca-app-pub-3940256099942544/1712485313')
      : (defaultTargetPlatform == TargetPlatform.android
            // Android
            ? ('ca-app-pub-5386053272091445/4314292015')
            // iOS
            : 'ca-app-pub-5386053272091445/9726346893');

  final intersitialAdUnitId =
      FirebaseRemoteConfig.instance.getBool(C.testAdsTag)
      ? (defaultTargetPlatform == TargetPlatform.android
            // Android
            ? 'ca-app-pub-3940256099942544/1033173712'
            // iOS
            : 'ca-app-pub-3940256099942544/4411468910')
      : (defaultTargetPlatform == TargetPlatform.android
            // Android
            ? ('ca-app-pub-5386053272091445/7323544832')
            // iOS
            : 'ca-app-pub-5386053272091445/4869644026');

  /// Creates an [AdsController] that wraps around a [MobileAds] [instance].
  AdsController(MobileAds instance) : _instance = instance;

  @override
  void dispose() {
    super.dispose();
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAdTimer?.cancel();
    _interstitialAdTimer?.cancel();
    _lifecycleNotifier?.removeListener(_handleAppLifecycle);
  }

  /// Initializes the Mobile Ads SDK and preloads ads.
  Future<void> initialize() async {
    await _instance.initialize();
    // Preload ads after a short delay to not interfere with app startup.
    Future<void>.delayed(const Duration(seconds: 1)).then((_) {
      loadRewardedAd();
      loadInterstitialAd();
    });
  }

  /// Returns true if a rewarded ad is loaded and ready to be shown.
  bool isAdAvailable() {
    return _rewardedAd != null;
  }

  bool isInterstitialAvailable() {
    return _interstitialAd != null;
  }

  /// Loads a new rewarded ad.
  void loadRewardedAd({AdRequest? adRequest}) {
    assert(
      Platform.isAndroid || Platform.isIOS,
      'AdMob currently does not support ${Platform.operatingSystem}',
    );
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: adRequest ?? const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedRetryCount = 0; // Reset retry count on success

          // Start a 1-hour timer to reload the ad before it expires
          _rewardedAdTimer?.cancel();
          _rewardedAdTimer = Timer(const Duration(hours: 1), () {
            reloadRewardedAd();
          });

          notifyListeners();
        },
        onAdFailedToLoad: ((error) async {
          _retryWithExponentialBackoff(
            () async => loadRewardedAd(adRequest: adRequest),
            _rewardedRetryCount,
            (count) => _rewardedRetryCount = count,
            'rewarded ad load',
          );
        }),
      ),
    );
  }

  /// Loads a new interstitial ad.
  void loadInterstitialAd({AdRequest? adRequest}) {
    assert(
      Platform.isAndroid || Platform.isIOS,
      'AdMob currently does not support ${Platform.operatingSystem}',
    );
    InterstitialAd.load(
      adUnitId: intersitialAdUnitId,
      request: adRequest ?? const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _intersitialRetryCount = 0; // Reset retry count on success

          // Start a 1-hour timer to reload the ad before it expires
          _interstitialAdTimer?.cancel();
          _interstitialAdTimer = Timer(const Duration(hours: 1), () {
            reloadInterstitialAd();
          });
        },
        onAdFailedToLoad: ((error) async {
          _retryWithExponentialBackoff(
            () async => loadInterstitialAd(adRequest: adRequest),
            _intersitialRetryCount,
            (count) => _intersitialRetryCount = count,
            'interstitial ad load',
          );
        }),
      ),
    );
  }

  /// Disposes the current interstitial ad and loads a new one.
  void reloadInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    loadInterstitialAd();
  }

  /// Disposes the current rewarded ad and loads a new one.
  void reloadRewardedAd() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    loadRewardedAd();
    notifyListeners();
  }

  /// Shows an interstitial ad if it's loaded.
  void showInterstitialAd() {
    if (_interstitialAd == null) {
      loadInterstitialAd(); // Try to load one for next time
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        isAdShowingNotifier.value = false; // <<< ADDED: Signal that ad has closed
        reloadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        isAdShowingNotifier.value = false; // <<< ADDED: Signal that ad has closed
        reloadInterstitialAd();
      },
    );

    if (Platform.isAndroid) _interstitialAd!.setImmersiveMode(true);
    isAdShowingNotifier.value = true; // >>> ADDED: Signal that ad is about to show
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  /// Shows a rewarded ad if it's loaded.
  ///
  /// The [onReward] callback is executed if the user earns the reward.
  void showRewardedAd(VoidCallback onReward) {
    if (_rewardedAd == null) {
      return;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        isAdShowingNotifier.value = false; // <<< ADDED: Signal that ad has closed
        reloadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        isAdShowingNotifier.value = false; // <<< ADDED: Signal that ad has closed
        reloadRewardedAd();
      },
    );

    if (Platform.isAndroid) _rewardedAd!.setImmersiveMode(true);
    isAdShowingNotifier.value = true; // >>> ADDED: Signal that ad is about to show
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        onReward();
      },
    );
    _rewardedAd = null;
  }

  /// Requests the latest consent information from the User Messaging Platform.
  Future<void> requestTheLatestConsentInformation() async {
    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        _consentRetryCount = 0; // Reset on success
        var status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.obtained ||
            status == ConsentStatus.notRequired) {
          initialize();
          return;
        }
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          loadConsentForm();
        }
      },
      (FormError error) async {
        _retryWithExponentialBackoff(
          requestTheLatestConsentInformation,
          _consentRetryCount,
          (count) => _consentRetryCount = count,
          'consent info update',
        );
      },
    );
  }

  /// Loads and shows the consent form if required.
  Future<void> loadConsentForm() async {
    ConsentForm.loadConsentForm(
      (ConsentForm consentForm) async {
        _consentRetryCount = 0; // Reset on success
        var status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          consentForm.show((FormError? formError) {
            loadConsentForm(); // Handle dismissal by reloading the form
          });
        } else {
          initialize();
        }
      },
      (formError) async {
        _retryWithExponentialBackoff(
          loadConsentForm,
          _consentRetryCount,
          (count) => _consentRetryCount = count,
          'consent form load',
        );
      },
    );
  }

  

  /// Attaches a listener to the app's lifecycle to check for ATT changes on iOS.
  void attachLifecycleNotifier(
    ValueNotifier<AppLifecycleState> lifecycleNotifier,
  ) {
    _lifecycleNotifier?.removeListener(_handleAppLifecycle);
    lifecycleNotifier.addListener(_handleAppLifecycle);
    _lifecycleNotifier = lifecycleNotifier;
  }

  /// Centralized retry logic with exponential backoff.
  Future<void> _retryWithExponentialBackoff(
    Future<void> Function() action,
    int currentRetryCount,
    void Function(int) updateRetryCount,
    String logContext,
  ) async {
    if (currentRetryCount < _maxRetryCount) {
      final newCount = currentRetryCount + 1;
      updateRetryCount(newCount);
      final delay = _initialDelay * pow(2, newCount - 1);
      await Future.delayed(delay);
      await action();
    } else {
      _log.severe('Max retries reached for $logContext. Not retrying.');
    }
  }

  void _handleAppLifecycle() {
    if (_lifecycleNotifier?.value == AppLifecycleState.resumed) {
      if (Platform.isIOS || Platform.isMacOS) {
        _checkTrackingAuthorizationChanges();
      }
    }
  }

  Future<void> _checkTrackingAuthorizationChanges() async {
    try {
      final currentStatus =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (_lastTrackingStatus != TrackingStatus.authorized &&
          currentStatus == TrackingStatus.authorized) {
        // If the user just granted permission, re-request consent info.
        await requestTheLatestConsentInformation();
      }
      _lastTrackingStatus = currentStatus;
    } catch (e) {
      _log.warning('Could not check tracking authorization changes: $e');
    }
  }
}