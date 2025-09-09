List<String> soundTypeToFilename(SfxType type) {
  switch (type) {
    case SfxType.letter:
      return const ['letter.wav'];
  }
}

enum SfxType {
  letter,
}
