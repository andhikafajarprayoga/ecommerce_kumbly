import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primary,
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Pengaturan Notifikasi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            _buildNotificationOption(
              'Notifikasi Pesanan',
              'Dapatkan update tentang status pesanan Anda',
              true,
            ),
            _buildNotificationOption(
              'Promo dan Penawaran',
              'Informasi tentang promo dan penawaran khusus',
              false,
            ),
            _buildNotificationOption(
              'Chat',
              'Pesan masuk dari penjual',
              true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationOption(
      String title, String subtitle, bool initialValue) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: initialValue,
                onChanged: (value) {
                  setState(() {
                    initialValue = value;
                  });
                },
                activeColor: AppTheme.primary,
              ),
            ],
          ),
        );
      },
    );
  }
}
