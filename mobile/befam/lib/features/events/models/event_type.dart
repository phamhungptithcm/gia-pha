enum EventType {
  clanGathering('clan_gathering'),
  meeting('meeting'),
  birthday('birthday'),
  deathAnniversary('death_anniversary'),
  other('other');

  const EventType(this.wireName);

  final String wireName;

  bool get isMemorial => this == EventType.deathAnniversary;

  static EventType fromWireName(String? wireName) {
    final normalized = wireName?.trim().toLowerCase();
    for (final value in EventType.values) {
      if (value.wireName == normalized) {
        return value;
      }
    }

    return EventType.other;
  }
}
