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
      // Set the theme to dark for all widgets in the app.
      theme: ThemeData.dark(),
      home: Scaffold(
        // The scaffold's background color is now handled by ThemeData.dark().
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 72,
                  // A lighter grey color is more visible on a dark background.
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Something went wrong',
                  // The text color will default to white from ThemeData.dark().
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: "EpundaSlab",
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Make sure you are an authentic user.',
                  // Use a slightly transparent white for subtitles.
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
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
                    // A slightly brighter red looks better on a dark theme.
                    backgroundColor: Colors.redAccent,
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