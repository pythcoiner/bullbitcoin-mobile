/// One labelled stop on the scan-start ruler.
typedef ScanStartTick = ({String label, int height});

/// Builds the ruler stops for the first-scan start chooser, ordered leftmost
/// (oldest) to rightmost (newest): the earliest scannable height, then 1 year,
/// 6 down to 1 months, then 3 down to 1 weeks ago. Each time offset is mapped
/// to a height with `tip - days * blocksPerDay`. Stops that fall at or below
/// `minBirthday` (other than the earliest stop) or above `tip` are dropped, and
/// duplicate heights are removed, so on a short chain only the meaningful stops
/// remain.
List<ScanStartTick> scanStartTicks({
  required int tip,
  required int minBirthday,
  required int blocksPerDay,
}) {
  const offsets = <({String label, int days})>[
    (label: '1 year', days: 365),
    (label: '6 months', days: 180),
    (label: '5 months', days: 150),
    (label: '4 months', days: 120),
    (label: '3 months', days: 90),
    (label: '2 months', days: 60),
    (label: '1 month', days: 30),
    (label: '3 weeks', days: 21),
    (label: '2 weeks', days: 14),
    (label: '1 week', days: 7),
  ];

  final ticks = <ScanStartTick>[(label: 'Earliest', height: minBirthday)];
  final seen = <int>{minBirthday};
  for (final o in offsets) {
    final height = tip - o.days * blocksPerDay;
    if (height <= minBirthday || height > tip || seen.contains(height)) continue;
    seen.add(height);
    ticks.add((label: o.label, height: height));
  }
  return ticks;
}

/// Approximate a block count as a human-readable duration, e.g. "1 year
/// 10 months", "2 days 4 hours", "3 hours". Shows the two most-significant
/// non-zero units (years/months/days/hours); under an hour returns "less than
/// an hour". Approximate (30-day months, 365-day years) and only indicative on
/// test networks where blocks are mined on demand.
String blocksToApproxDuration(int blocks, {required int blocksPerDay}) {
  var hours = blocks * 24 ~/ blocksPerDay;
  final years = hours ~/ 8760;
  hours %= 8760;
  final months = hours ~/ 720;
  hours %= 720;
  final days = hours ~/ 24;
  hours %= 24;

  final units = <String>[
    if (years > 0) '$years year${years == 1 ? '' : 's'}',
    if (months > 0) '$months month${months == 1 ? '' : 's'}',
    if (days > 0) '$days day${days == 1 ? '' : 's'}',
    if (hours > 0) '$hours hour${hours == 1 ? '' : 's'}',
  ];
  if (units.isEmpty) return 'less than an hour';
  return units.take(2).join(' ');
}
