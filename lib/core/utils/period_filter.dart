import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum TimePeriod { day, week, month, quarter, semester, year }

extension TimePeriodExtension on TimePeriod {
  String get label {
    switch (this) {
      case TimePeriod.day:
        return 'Día';
      case TimePeriod.week:
        return 'Semana';
      case TimePeriod.month:
        return 'Mes';
      case TimePeriod.quarter:
        return 'Trimestre';
      case TimePeriod.semester:
        return 'Semestre';
      case TimePeriod.year:
        return 'Año';
    }
  }

  DateTimeRange calculateRange(DateTime date) {
    switch (this) {
      case TimePeriod.day:
        final start = DateTime(date.year, date.month, date.day);
        final end = DateTime(date.year, date.month, date.day, 23, 59, 59);
        return DateTimeRange(start: start, end: end);

      case TimePeriod.week:
        // Assuming week starts on Monday
        final daysToSubtract = date.weekday - 1;
        final start = DateTime(
          date.year,
          date.month,
          date.day - daysToSubtract,
        );
        final end = start.add(
          const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        );
        return DateTimeRange(start: start, end: end);

      case TimePeriod.month:
        final start = DateTime(date.year, date.month, 1);
        final end = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
        return DateTimeRange(start: start, end: end);

      case TimePeriod.quarter:
        final quarter = (date.month - 1) ~/ 3 + 1;
        final startMonth = (quarter - 1) * 3 + 1;
        final start = DateTime(date.year, startMonth, 1);
        final end = DateTime(date.year, startMonth + 3, 0, 23, 59, 59);
        return DateTimeRange(start: start, end: end);

      case TimePeriod.semester:
        final semester = (date.month - 1) ~/ 6 + 1;
        final startMonth = (semester - 1) * 6 + 1;
        final start = DateTime(date.year, startMonth, 1);
        final end = DateTime(date.year, startMonth + 6, 0, 23, 59, 59);
        return DateTimeRange(start: start, end: end);

      case TimePeriod.year:
        final start = DateTime(date.year, 1, 1);
        final end = DateTime(date.year, 12, 31, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
    }
  }

  String format(DateTime date) {
    const locale = 'es_PE'; // Or 'es'
    switch (this) {
      case TimePeriod.day:
        return DateFormat('dd/MM/yyyy', locale).format(date);
      case TimePeriod.week:
        final range = calculateRange(date);
        return '${DateFormat('dd/MM/yyyy', locale).format(range.start)} - ${DateFormat('dd/MM/yyyy', locale).format(range.end)}';
      case TimePeriod.month:
        final formatted = DateFormat('MMMM yyyy', locale).format(date);
        return formatted[0].toUpperCase() + formatted.substring(1);
      case TimePeriod.quarter:
        final quarter = (date.month - 1) ~/ 3 + 1;
        String suffix;
        if (quarter == 1 || quarter == 3) {
          suffix = 'er';
        } else if (quarter == 2) {
          suffix = 'do';
        } else {
          suffix = 'to';
        }
        return '$quarter$suffix Trimestre ${date.year}';
      case TimePeriod.semester:
        final semester = (date.month - 1) ~/ 6 + 1;
        final suffix = semester == 1 ? 'er' : 'do';
        return '$semester$suffix Semestre ${date.year}';
      case TimePeriod.year:
        return '${date.year}';
    }
  }
}
