import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';

final masterKey = masterKeyFromPassword("leadcapture-crm");
final crypto = DeterministicCrypto(masterKey);

extension StringExtensions on String {
  String get capitalizeFirst =>
      isEmpty ? this : this[0].toUpperCase() + substring(1).toLowerCase();
  String get replaceSlashes => replaceAll('/', '_');
  String get first {
    if (isEmpty) return '';
    return substring(0, 1);
  }

  String get encrypt => crypto.encrypt(this);
  String get decrypt => crypto.tryDecrypt(this);
}

extension DateExtensions on DateTime {
  String get chatFormat => DateFormat('MMM d, h:mm a').format(this);
  String get monthYearFormat => DateFormat('MMM yyyy').format(this);
  String get formatDate => DateFormat('dd-MM-yyyy').format(this);
  String get formatDateTime => DateFormat('dd-MM-yyyy hh:mm a').format(this);
  String get listingDateTime => DateFormat('dd MMM yy hh:mm a').format(this);
  String get formatDateMonthTime =>
      DateFormat('dd MMM yy hh:mm a').format(this);
  String get formatDateTime24Hrs =>
      DateFormat('dd-MM-yyyy HH:mm:ss').format(this);
  String get formatTime => DateFormat('hh:mm a').format(this);
  String get formatDateMonth => DateFormat('dd MMM yyyy').format(this);
  String get showDate {
    final now = DateTime.now();
    if (day == now.day && month == now.month && year == now.year) {
      return "Today";
    } else if (day == now.subtract(const Duration(days: 1)).day &&
        month == now.month &&
        year == now.year) {
      return "Yesterday";
    }
    return DateFormat('dd-MMM-yyyy').format(this);
  }
}

extension ColorExtensions on String {
  Color get getColorForFile {
    switch (toLowerCase()) {
      case 'xls':
      case 'xlsx':
        return AppColors.success;
      case 'pdf':
        return AppColors.danger;
      case 'doc':
      case 'docx':
        return AppColors.blue;
      case 'ppt':
      case 'pptx':
        return AppColors.orange;
      default:
        return AppColors.black;
    }
  }
}
