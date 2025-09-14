import 'package:flutter/material.dart';

class ConnectionErrorScreen extends StatelessWidget {
  /// A callback function that is triggered when the user presses the 'Try Again' button.
  final VoidCallback onRetry;

  const ConnectionErrorScreen({
    super.key,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Using a MaterialApp here ensures that the screen has the proper theme
    // and directionality, even when shown before the main app is built.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 72,
                  color: Colors.grey,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Connection Failed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: "EpundaSlab", // Assuming this font is in your project
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please check your network connection.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontFamily: "EpundaSlab",
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontFamily: "EpundaSlab",
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}