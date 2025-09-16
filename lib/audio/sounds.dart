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
    case SfxType.reveal:
      return const ['reveal.wav'];
    case SfxType.action:
      return const ['action.wav'];
    case SfxType.adventure:
      return const ['adventure.wav'];
    case SfxType.comedy:
      return const ['comedy.wav'];
    case SfxType.drama:
      return const ['drama.wav'];
    case SfxType.fantasy:
      return const ['fantasy.wav'];
    case SfxType.horror:
      return const ['horror.wav'];
    case SfxType.mystery:
      return const ['mystery.wav'];
    case SfxType.romance:
      return const ['romance.wav'];
    case SfxType.scifi:
      return const ['scifi.wav'];
    case SfxType.thriller:
      return const ['thriller.wav'];
    case SfxType.war:
      return const ['war.wav'];
    case SfxType.snapclick:
      return const ['snapclick.wav'];
    case SfxType.impact:
      return const ['impact.wav'];
  }
}

enum SfxType {
  letter,
  select,
  erase,
  eraseAll,
  reveal,
  snapclick,
  impact,
  action,
  adventure,
  comedy,
  drama,
  fantasy,
  horror,
  mystery,
  romance,
  scifi,
  thriller,
  war
}
