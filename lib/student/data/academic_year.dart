/// Stable label shared by the profile, schedule and store year filter.
String academicYearLabel(String? value) {
  final raw = (value ?? '').trim().replaceFirst(RegExp(r'^السنة\s+'), '');
  const aliases = [
    ['الأولى', 'الاولى', 'first', '1', '١'],
    ['الثانية', 'second', '2', '٢'],
    ['الثالثة', 'third', '3', '٣'],
    ['الرابعة', 'fourth', '4', '٤'],
    ['الخامسة', 'fifth', '5', '٥'],
    ['السادسة', 'sixth', '6', '٦'],
  ];
  for (final names in aliases) {
    if (names.contains(raw.toLowerCase())) return names.first;
  }
  return raw;
}
