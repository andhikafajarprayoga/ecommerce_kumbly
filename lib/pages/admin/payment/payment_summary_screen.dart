import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';

class PaymentSummaryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> payments;

  const PaymentSummaryScreen({Key? key, required this.payments})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Kalkulasi total
    double totalProducts = 0;
    double totalShipping = 0;
    double totalAdmin = 0;
    int totalCOD = 0;
    int totalTransfer = 0;
    double totalCODAmount = 0;
    double totalTransferAmount = 0;

    for (var payment in payments) {
      final double amount = (payment['total_amount'] ?? 0).toDouble();
      final double shipping = (payment['total_shipping_cost'] ?? 0).toDouble();
      final double admin = (payment['admin_fee'] ?? 0).toDouble();
      final double total = amount + shipping + admin;

      totalProducts += amount;
      totalShipping += shipping;
      totalAdmin += admin;

      if (payment['payment_proof'] == 'COD') {
        totalCOD++;
        totalCODAmount += total;
      } else {
        totalTransfer++;
        totalTransferAmount += total;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Ringkasan Pembayaran'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Transaksi',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 16),
                    _buildSummaryTile(
                      'Total Produk',
                      'Rp ${NumberFormat('#,###').format(totalProducts)}',
                      Icons.shopping_cart,
                      Colors.blue,
                    ),
                    _buildSummaryTile(
                      'Total Ongkir',
                      'Rp ${NumberFormat('#,###').format(totalShipping)}',
                      Icons.local_shipping,
                      Colors.green,
                    ),
                    _buildSummaryTile(
                      'Total Admin',
                      'Rp ${NumberFormat('#,###').format(totalAdmin)}',
                      Icons.admin_panel_settings,
                      Colors.orange,
                    ),
                    Divider(height: 32),
                    _buildSummaryTile(
                      'Total Keseluruhan',
                      'Rp ${NumberFormat('#,###').format(totalProducts + totalShipping + totalAdmin)}',
                      Icons.account_balance_wallet,
                      Colors.pink,
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Metode Pembayaran',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 16),
                    _buildSummaryTile(
                      'COD',
                      '$totalCOD transaksi',
                      Icons.local_shipping,
                      Colors.orange,
                      subtitle:
                          'Rp ${NumberFormat('#,###').format(totalCODAmount)}',
                    ),
                    _buildSummaryTile(
                      'Transfer',
                      '$totalTransfer transaksi',
                      Icons.account_balance,
                      Colors.green,
                      subtitle:
                          'Rp ${NumberFormat('#,###').format(totalTransferAmount)}',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTile(
      String title, String value, IconData icon, Color color,
      {bool isTotal = false, String? subtitle}) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: color))
          : null,
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: isTotal ? 18 : 16,
          fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
          color: isTotal ? Colors.pink : null,
        ),
      ),
    );
  }
}
