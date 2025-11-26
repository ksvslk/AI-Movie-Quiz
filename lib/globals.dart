// lib/globals.dart
import 'package:flutter/material.dart';

/// A simple, global signal to notify widgets when a fullscreen ad is being shown.
final ValueNotifier<bool> isAdShowingNotifier = ValueNotifier(false);