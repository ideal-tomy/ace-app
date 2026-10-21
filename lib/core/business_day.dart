const businessDayCutoffHour = 6;
const _japanOffset = Duration(hours: 9);

/// Returns the UTC instant representing midnight in Japan for the business day.
/// Times before 06:00 JST belong to the previous business day.
DateTime businessDateFor(DateTime instant) {
  final japanTime = instant.toUtc().add(_japanOffset);
  final calendarDate = DateTime.utc(
    japanTime.year,
    japanTime.month,
    japanTime.day,
  );
  final businessCalendarDate = japanTime.hour < businessDayCutoffHour
      ? calendarDate.subtract(const Duration(days: 1))
      : calendarDate;
  return businessCalendarDate.subtract(_japanOffset);
}

String businessDateKey(DateTime businessDate) {
  final japanDate = businessDate.toUtc().add(_japanOffset);
  final month = japanDate.month.toString().padLeft(2, '0');
  final day = japanDate.day.toString().padLeft(2, '0');
  return '${japanDate.year}-$month-$day';
}

DateTime businessDateFromCalendarDate(DateTime selectedDate) {
  return DateTime.utc(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
  ).subtract(_japanOffset);
}
