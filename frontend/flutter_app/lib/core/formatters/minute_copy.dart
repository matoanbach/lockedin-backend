String formatMinuteCount(int minutes) {
  return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
}

String formatMinutesRemaining(int minutes) {
  final verb = minutes == 1 ? 'remains' : 'remain';
  return '${formatMinuteCount(minutes)} $verb';
}
