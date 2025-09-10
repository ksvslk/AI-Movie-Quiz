List<String> soundTypeToFilename(SfxType type) {
  switch (type) {
    case SfxType.letter:
      return const ['letter.wav'];
    case SfxType.select:
      return const ['select.wav'];
    case SfxType.erase:
      return const ['erase.wav'];
    case SfxType.eraseAll:
      return const ['erase_all.wav'];
  }
}

enum SfxType {
  letter,
  select,
  erase,
  eraseAll
}
