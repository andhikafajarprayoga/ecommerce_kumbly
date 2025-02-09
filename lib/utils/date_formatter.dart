import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDate(String date) {
    // Parse UTC date dari Supabase
    final DateTime utcDate = DateTime.parse(date);
    // Konversi ke zona waktu lokal perangkat
    final DateTime localTime = utcDate.toLocal();
    return DateFormat('dd MMM yyyy, HH:mm').format(localTime);
  }

  // Bisa ditambahkan format lain sesuai kebutuhan
  static String formatShortDate(String date) {
    final DateTime utcDate = DateTime.parse(date);
    final DateTime localTime = utcDate.toLocal();
    return DateFormat('dd MMM yyyy').format(localTime);
  }

  static String formatChatTime(String? timestamp) {
    if (timestamp == null) return '';

    final DateTime utcDate = DateTime.parse(timestamp);
    final DateTime localTime = utcDate.toLocal();
    final DateTime now = DateTime.now();
    final difference = now.difference(localTime);

    if (localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day) {
      return DateFormat('HH:mm').format(localTime);
    }

    if (difference.inDays == 1) {
      return 'Kemarin';
    }

    if (difference.inDays < 7) {
      final List<String> days = [
        'Sen',
        'Sel',
        'Rab',
        'Kam',
        'Jum',
        'Sab',
        'Min'
      ];
      return days[localTime.weekday - 1];
    }

    return DateFormat('dd/MM').format(localTime);
  }
}
