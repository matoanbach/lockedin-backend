String formatMinuteCount(int minutes) {
  return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
}

String formatMinutesRemaining(int minutes) {
  final verb = minutes == 1 ? 'remains' : 'remain';
  return '${formatMinuteCount(minutes)} $verb';
}

String formatElapsedMilliseconds(int milliseconds) {
  if (milliseconds > 0 && milliseconds < 60000) {
    return 'less than 1 minute';
  }
  final safeMilliseconds = milliseconds < 0 ? 0 : milliseconds;
  return formatMinuteCount(safeMilliseconds ~/ 60000);
}

String formatRemainingMilliseconds(int milliseconds) {
  final duration = formatElapsedMilliseconds(milliseconds);
  final verb = duration == '1 minute' || duration == 'less than 1 minute'
      ? 'remains'
      : 'remain';
  return '$duration $verb';
}
