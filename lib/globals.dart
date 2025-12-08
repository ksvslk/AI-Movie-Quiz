// lib/globals.dart
import 'package:flutter/material.dart';

/// A simple, global signal to notify widgets when a fullscreen ad is being shown.
final ValueNotifier<bool> isAdShowingNotifier = ValueNotifier(false);

/// Global notifier to track if paywall should be shown before ads
/// This is controlled by Firebase Remote Config
final ValueNotifier<bool> showPaywallBeforeAdsNotifier = ValueNotifier<bool>(false);