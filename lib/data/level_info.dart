import 'package:cloud_firestore/cloud_firestore.dart';

class LevelInfo {
  final String id;
  final int levelNumber;
  final String name;
  final String path;
  final String characteristic;
  final Map<String, dynamic> hints;

  LevelInfo({
    required this.id,
    required this.levelNumber,
    required this.name,
    required this.path,
    required this.hints,
    required this.characteristic
  });

  // A factory constructor to create a Level from a Firestore document
  factory LevelInfo.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return LevelInfo(
      id: doc.id,
      levelNumber: data['levelNumber'] ?? 0,
      name: data['name'] ?? 'Unnamed Level',
      path: data['path'] ?? '',
      characteristic: data['characteristic'],
      hints: data['hints']
    );
  }
}