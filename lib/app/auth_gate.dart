import 'dart:developer' as dev;
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:operation_sunrise/home_page.dart'; // Make sure this path is correct
import 'connection_error_screen.dart';

/// An enum to represent the different states of the authentication process.
enum AuthState {
  checking,
  signedIn,
  error,
}

/// A gatekeeper widget that handles the app's initial authentication flow.
/// It shows a loading indicator, the main app, or an error screen.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthState _authState = AuthState.checking;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Tries to sign in the user anonymously with an exponential backoff retry strategy.
  Future<void> _signInAnonymouslyWithRetry() async {
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
        dev.log('Failed to sign in (Attempt ${attempt + 1}/$maxRetries): ${e.code}', level: Level.WARNING.value, error: e);
        if (attempt == maxRetries - 1) {
          dev.log('Max sign-in retries reached. Failing permanently.', level: Level.SEVERE.value);
          rethrow; // Re-throw the last exception to be caught by the caller.
        }
        final backoffTime = initialDelay * pow(2, attempt);
        final jitter = Duration(milliseconds: random.nextInt(maxJitter.inMilliseconds));
        final totalDelay = backoffTime + jitter;
        dev.log('Waiting for ${totalDelay.inMilliseconds}ms before next retry.');
        await Future.delayed(totalDelay);
      }
    }
  }

  /// The main initialization logic.
  Future<void> _initializeApp() async {
    // Set state to checking to show a loading indicator, especially for retries.
    if (mounted) setState(() => _authState = AuthState.checking);

    // If already signed in, go straight to the app.
    if (FirebaseAuth.instance.currentUser != null) {
      if (mounted) setState(() => _authState = AuthState.signedIn);
      return;
    }

    // Try to sign in.
    try {
      await _signInAnonymouslyWithRetry();
      if (mounted) setState(() => _authState = AuthState.signedIn);
    } catch (e) {
      if (mounted) setState(() => _authState = AuthState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_authState) {
      case AuthState.checking:
        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      case AuthState.signedIn:
        // When successful, build the main app UI.
        // This replaces the old `MyApp` widget.
        return MaterialApp(
          title: 'Operation Sunrise',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.yellowAccent),
            useMaterial3: true,
            fontFamily: "EpundaSlab",
          ),
          home: const HomePage(),
        );
      case AuthState.error:
        return ConnectionErrorScreen(
          onRetry: _initializeApp, // Pass the retry function to the error screen.
        );
    }
  }
}