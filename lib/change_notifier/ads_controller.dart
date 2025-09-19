// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async'; // Import the async library for Timer
import 'dart:io';
import 'dart:math';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';

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

  /*

final rewardedAdUnitId = defaultTargetPlatform == TargetPlatform.android

? 'ca-app-pub-5386053272091445/4314292015'

// iOS

: 'ca-app-pub-5386053272091445/9726346893';



final intersitialAdUnitId = defaultTargetPlatform == TargetPlatform.android

? 'ca-app-pub-5386053272091445/7323544832'

// iOS

: 'ca-app-pub-5386053272091445/4869644026';

*/

  // --- Ad Unit IDs ---
  // Use test IDs for development to avoid policy violations.
  // Replace with your real IDs before publishing.
  final rewardedAdUnitId = defaultTargetPlatform == TargetPlatform.android
      ? 'ca-app-pub-3940256099942544/5224354917' // Android Test ID
      : 'ca-app-pub-3940256099942544/1712485313'; // iOS Test ID

  final intersitialAdUnitId = defaultTargetPlatform == TargetPlatform.android
      ? 'ca-app-pub-3940256099942544/1033173712' // Android Test ID
      : 'ca-app-pub-3940256099942544/4411468910'; // iOS Test ID

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
          _log.info('Rewarded ad loaded.');
          _rewardedRetryCount = 0; // Reset retry count on success

          // Start a 1-hour timer to reload the ad before it expires
          _rewardedAdTimer?.cancel();
          _rewardedAdTimer = Timer(const Duration(hours: 1), () {
            _log.info('Rewarded ad expired, reloading.');
            reloadRewardedAd();
          });

          notifyListeners();
        },
        onAdFailedToLoad: ((error) async {
          _log.warning('Rewarded ad failed to load: $error');
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
          _log.info('Interstitial ad loaded.');
          _intersitialRetryCount = 0; // Reset retry count on success

          // Start a 1-hour timer to reload the ad before it expires
          _interstitialAdTimer?.cancel();
          _interstitialAdTimer = Timer(const Duration(hours: 1), () {
            _log.info('Interstitial ad expired, reloading.');
            reloadInterstitialAd();
          });
        },
        onAdFailedToLoad: ((error) async {
          _log.warning('Interstitial ad failed to load: $error');
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
      _log.warning('Attempted to show interstitial ad before it was loaded.');
      loadInterstitialAd(); // Try to load one for next time
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _log.info('$ad onAdDismissedFullScreenContent.');
        reloadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        _log.severe('$ad failed to show full screen content: $err');
        reloadInterstitialAd();
      },
    );

    if (Platform.isAndroid) _interstitialAd!.setImmersiveMode(true);
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  /// Shows a rewarded ad if it's loaded.
  ///
  /// The [onReward] callback is executed if the user earns the reward.
  void showRewardedAd(VoidCallback onReward) {
    if (_rewardedAd == null) {
      _log.warning('Attempted to show rewarded ad before it was loaded.');
      return;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _log.info('$ad onAdDismissedFullScreenContent.');
        reloadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _log.severe('$ad onAdFailedToShowFullScreenContent: $error');
        reloadRewardedAd();
      },
    );

    if (Platform.isAndroid) _rewardedAd!.setImmersiveMode(true);
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        _log.info(
          '$ad with reward $RewardItem(${reward.amount}, ${reward.type})',
        );
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
        _log.severe('Consent info update failed: $error');
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
            _log.warning('Consent form dismissed, reloading. $formError');
            loadConsentForm(); // Handle dismissal by reloading the form
          });
        } else {
          initialize();
        }
      },
      (formError) async {
        _log.severe('Failed to load consent form: $formError');
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
      _log.info(
        'Retrying $logContext in ${delay.inSeconds} seconds... (Attempt $newCount/$_maxRetryCount)',
      );
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
