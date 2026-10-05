import 'package:cloud_firestore/cloud_firestore.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'June',
  'July',
  'Aug',
  'Sept',
  'Oct',
  'Nov',
  'Dec',
];

/// formatDate(ts)                 -> Sept 9, 2026
/// formatDate(ts, withTime: true) -> Sept 9, 2026, 3:45 PM
String formatDate(dynamic ts, {bool withTime = false}) {
  if (ts is! Timestamp) return 'Just now';
  final d = ts.toDate();
  final date = '${_months[d.month - 1]} ${d.day}, ${d.year}';
  if (!withTime) return date;
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  return '$date, $h:$m $ap';
}
