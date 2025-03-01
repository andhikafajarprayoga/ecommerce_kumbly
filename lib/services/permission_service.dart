import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';

class PermissionService {
  static Future<void> showPermissionDialog() async {
    await Get.dialog(
      AlertDialog(
        title: Text('Izin Aplikasi'),
        content: Text(
          'Aplikasi ini membutuhkan beberapa izin untuk berfungsi dengan baik:\n\n'
          '• Notifikasi - untuk menerima pemberitahuan\n'
          '• Penyimpanan - untuk menyimpan file\n'
          '• Kamera - untuk mengambil foto\n'
          '• Lokasi - untuk fitur pengiriman',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              openAppSettings();
            },
            child: Text('Buka Pengaturan'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              requestPermissions();
            },
            child: Text('Izinkan'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  static Future<void> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.notification,
      Permission.storage,
      Permission.camera,
      Permission.location,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);
    
    if (!allGranted) {
      Get.snackbar(
        'Izin Diperlukan',
        'Beberapa izin diperlukan untuk aplikasi berfungsi dengan baik',
        duration: Duration(seconds: 5),
        mainButton: TextButton(
          onPressed: () => openAppSettings(),
          child: Text('Buka Pengaturan'),
        ),
      );
    }
  }
}