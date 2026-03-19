// ========== lib/domain/analysis_logic.dart ==========
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart'; // أضف هذا السطر

class AnalysisLogic {
  final Color colorPinkish = const Color(0xFFE7CCCC);
  final Color colorCream = const Color(0xFFEDE8DC);
  final Color colorGreenDark = const Color(0xff7f9461);
  final Color colorGreenLight = const Color(0xFFC1CFA1);

  String formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<DateTimeRange?> selectDateRange(
      BuildContext context,
      DateTime? startDate,
      DateTime? endDate,
      ) async {
    DateTime now = DateTime.now();
    return await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate, end: endDate)
          : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: colorGreenDark,
              onPrimary: Colors.white,
              surface: colorCream,
              onSurface: colorGreenDark,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  int getMaxY(Map<String, int> counts) {
    int max = 0;
    counts.forEach((key, value) {
      if (value > max) max = value;
    });
    return max + 1;
  }

  double getInterval(Map<String, int> counts) {
    int max = getMaxY(counts);
    if (max <= 5) return 1;
    if (max <= 10) return 2;
    if (max <= 20) return 5;
    return 10;
  }

  void showPDFOptions(BuildContext context, File file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colorCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorGreenDark.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Report Generated Successfully',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff7f9461),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.share, color: colorGreenDark),
                title: const Text('Share Report', style: TextStyle(color: Color(0xff7f9461))),
                onTap: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(file.path)], text: 'Mental Health Analytics Report');
                },
              ),
              ListTile(
                leading: Icon(Icons.picture_as_pdf, color: colorGreenDark),
                title: const Text('Open PDF', style: TextStyle(color: Color(0xff7f9461))),
                onTap: () {
                  Navigator.pop(context);
                  _openPDF(file);
                },
              ),
              ListTile(
                leading: Icon(Icons.close, color: Colors.red),
                title: const Text('Close', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPDF(File file) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => await file.readAsBytes(),
      );
    } catch (e) {
      print('Error opening PDF: $e');
    }
  }

  void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        title: const Text('Error', style: TextStyle(color: Color(0xff7f9461))),
        content: Text(message, style: const TextStyle(color: Color(0xff7f9461))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xff7f9461))),
          ),
        ],
      ),
    );
  }
}