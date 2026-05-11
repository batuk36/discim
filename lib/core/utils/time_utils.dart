bool isClinicOpenNow(Map<String, String> workingHours) {
  final now = DateTime.now();
  const enKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  const trKeys = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
  final idx = now.weekday - 1;
  final hours = workingHours[enKeys[idx]] ?? workingHours[trKeys[idx]] ?? '';
  if (hours.isEmpty || hours == 'Kapalı') return false;
  final parts = hours.split(' - ');
  if (parts.length != 2) return false;
  try {
    final op = parts[0].trim().split(':');
    final cl = parts[1].trim().split(':');
    final open  = DateTime(now.year, now.month, now.day, int.parse(op[0]), int.parse(op[1]));
    final close = DateTime(now.year, now.month, now.day, int.parse(cl[0]), int.parse(cl[1]));
    return now.isAfter(open) && now.isBefore(close);
  } catch (_) {
    return false;
  }
}
