// game_screen.dart
import 'package:flutter/material.dart';
import 'package:operation_sunrise/concentric_letter_circle.dart';
import 'package:operation_sunrise/letter_circle.dart';
import 'dart:math'; // We need this for the circle calculation
import 'level_video_player.dart'; // Our existing video player

class GameScreen extends StatefulWidget {
  final String videoPath;
  final String levelName;

  const GameScreen({
    super.key,
    required this.videoPath,
    required this.levelName,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

// In game_screen.dart

class _GameScreenState extends State<GameScreen> {
  // We no longer need the hardcoded _letters list.
  // final List<String> _letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
  String _tappedLetter = '?';

  void _onLetterTapped(String letter) {
    setState(() {
      _tappedLetter = letter;
      print('User tapped: $letter');
    });
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      title: Text(widget.levelName),
    ),
     backgroundColor: Colors.black,
    // --- CHANGE IS HERE ---
    // We wrap the main content widget with SafeArea.
    body: SafeArea(
      child: Column(
        children: [
          // TOP HALF: The Video Player
          Expanded(
            flex: 2,
            child: LevelVideoPlayer(videoPath: widget.videoPath),
          ),
          
          // BOTTOM HALF: The Letter Circle
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(2.0),
              child: Center(
                child: ConcentricLetterCircle(
  onLetterTapped: _onLetterTapped,
  letterButtonSize: 41.0, 
),
              ),
            ),
          ),
        ],
      ),
    ),
    // --- END OF CHANGE ---
  );
}
}