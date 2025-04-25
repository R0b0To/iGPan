String abbreviateNumber(String input) {
  final n = double.tryParse(input);
  if (n == null || n == 0) return '0';

  final suffixes = ['', 'K', 'M', 'B', 'T', 'P', 'E', 'Z', 'Y'];
  int magnitude = 0;
  double value = n;

  while (value.abs() >= 1000 && magnitude < suffixes.length - 1) {
    magnitude++;
    value /= 1000.0;
  }

  return '${value.toStringAsFixed(1)}${suffixes[magnitude]}';
}