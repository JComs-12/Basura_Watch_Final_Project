import 'package:flutter/material.dart';

enum ReportStatus {
  pending('Pending', Colors.grey, Icons.hourglass_empty),
  inProgress('In Progress', Colors.orange, Icons.autorenew),
  resolved('Resolved', Colors.green, Icons.check_circle);

  final String label;
  final Color color;
  final IconData icon;
  const ReportStatus(this.label, this.color, this.icon);

  static ReportStatus fromString(String? value) => ReportStatus.values
      .firstWhere((s) => s.label == value, orElse: () => ReportStatus.pending);
}

enum ReportCategory {
  scattered('Scattered Garbage', Icons.delete_sweep),
  overflowing('Overflowing Bin', Icons.delete),
  illegalDumping('Illegal Dumping', Icons.report_problem),
  cloggedDrainage('Clogged Drainage', Icons.water_damage);

  final String label;
  final IconData icon;
  const ReportCategory(this.label, this.icon);
}
