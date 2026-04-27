/// Текст активности по последнему heartbeat в приложении.
String formatLastSeenRu(int lastSeenMs, {required int nowMs}) {
  if (lastSeenMs <= 0) return 'ещё не заходил(-а)';
  final diff = nowMs - lastSeenMs;
  if (diff < 120000) {
    return 'в сети';
  }
  final minutes = diff ~/ 60000;
  if (minutes < 1) {
    return 'только что';
  }
  if (minutes < 60) {
    return 'был(-а) $minutes ${_minuteWord(minutes)} назад';
  }
  final hours = minutes ~/ 60;
  if (hours < 24) {
    return 'был(-а) $hours ${_hourWord(hours)} назад';
  }
  final days = hours ~/ 24;
  return 'был(-а) $days ${_dayWord(days)} назад';
}

String _minuteWord(int n) {
  final m = n % 10;
  final m100 = n % 100;
  if (m100 >= 11 && m100 <= 14) return 'минут';
  if (m == 1) return 'минуту';
  if (m >= 2 && m <= 4) return 'минуты';
  return 'минут';
}

String _hourWord(int n) {
  final m = n % 10;
  final m100 = n % 100;
  if (m100 >= 11 && m100 <= 14) return 'часов';
  if (m == 1) return 'час';
  if (m >= 2 && m <= 4) return 'часа';
  return 'часов';
}

String _dayWord(int n) {
  final m = n % 10;
  final m100 = n % 100;
  if (m100 >= 11 && m100 <= 14) return 'дней';
  if (m == 1) return 'день';
  if (m >= 2 && m <= 4) return 'дня';
  return 'дней';
}
