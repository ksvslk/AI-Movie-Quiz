import 'package:flutter/material.dart';

class QuotePopup extends StatelessWidget {
  final String quote;
  final String title;
  const QuotePopup({super.key, required this.quote, required this.title});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      backgroundColor: Colors.transparent,
      child: Container(
        // Using ClipRRect to make sure the gradient respects the border radius
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          color: const Color(0xFF3a2020), // Fallback color
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            gradient: const LinearGradient(
              colors: [Color(0xFF4a2a2a), Color(0xFF2c1a1a)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.red.shade300.withOpacity(0.3), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: "EpundaSlab", // Font from your existing code
                  color: Colors.red.shade200,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: Colors.red.withOpacity(0.2)),
              const SizedBox(height: 16),
              Flexible( // Ensures the text wraps and the dialog doesn't overflow
                child: SingleChildScrollView( // For very long quotes
                  child: Text(
                    '"$quote"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      // For a more distinct look, consider adding a serif font like
                      // 'Lora' or 'Merriweather' to your project via Google Fonts.
                      fontFamily: 'serif', 
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 17,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(color: Colors.white.withOpacity(0.5))
                  )
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'CLOSE',
                    style: TextStyle(fontFamily: "EpundaSlab", letterSpacing: 1.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}