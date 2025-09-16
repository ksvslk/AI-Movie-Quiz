// lib/app/auth_gate.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:operation_sunrise/home_page.dart';
import 'connection_error_screen.dart';

/// A gatekeeper widget that listens to Firebase auth state changes and shows
/// the appropriate screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Listen to the authentication state stream
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Show a loading indicator while waiting for the first auth event
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        // 2. If the snapshot has data, the user is signed in
        if (snapshot.hasData) {
          // User is signed in, show the main application
          return MaterialApp(
            title: 'Operation Sunrise',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
              useMaterial3: true,
              fontFamily: "EpundaSlab",
            ),
            home: const HomePage(),
          );
        }

        // 3. If there's no data, sign-in failed in main.dart
        // Show the connection error screen
        return ConnectionErrorScreen(
          // The retry function now simply triggers another sign-in attempt
          onRetry: () => FirebaseAuth.instance.signInAnonymously(),
        );
      },
    );
  }
}