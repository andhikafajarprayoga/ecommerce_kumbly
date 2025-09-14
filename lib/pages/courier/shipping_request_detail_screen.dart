import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

class ShippingRequestDetailScreen extends StatelessWidget {
  final Map<String, dynamic> request;
  const ShippingRequestDetailScreen({Key? key, required this.request}) : super(key: key);

  String formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  String parseAddress(String? addressJson) {
    if (addressJson == null) return '-';
    try {
      final Map<String, dynamic> addr = json.decode(addressJson);
      List<String> parts = [];
      if (addr['street'] != null) parts.add(addr['street']);
      if (addr['village'] != null) parts.add(addr['village']);
      if (addr['district'] != null) parts.add(addr['district']);
      if (addr['city'] != null) parts.add(addr['city']);
      return parts.isEmpty ? addressJson : parts.join(', ');
    } catch (_) {
      return addressJson;
    }
  }

  Map<String, dynamic>? parseAddressMap(String? addressJson) {
    if (addressJson == null) return null;
    try {
      return json.decode(addressJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void openMap(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final senderAddr = parseAddressMap(request['sender_address']);
    final receiverAddr = parseAddressMap(request['receiver_address']);
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Pesanan Tersedia', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SR#${request['id'].toString().padLeft(6, '0')}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.primary,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 18, color: Colors.grey[700]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          request['item_name'] ?? '-',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ),
                      Text(
                        '${request['weight']} kg',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Jenis: ${request['item_type'] ?? '-'}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 18, color: Colors.grey[700]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Dari: ${parseAddress(request['sender_address'])}',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                if (senderAddr != null &&
                                    senderAddr['latitude'] != null &&
                                    senderAddr['longitude'] != null)
                                  IconButton(
                                    icon: Icon(Icons.map, color: Colors.blue, size: 20),
                                    tooltip: 'Buka di Maps',
                                    onPressed: () => openMap(
                                      double.tryParse(senderAddr['latitude'].toString()) ?? 0.0,
                                      double.tryParse(senderAddr['longitude'].toString()) ?? 0.0,
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 2),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Ke: ${parseAddress(request['receiver_address'])}',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                if (receiverAddr != null &&
                                    receiverAddr['latitude'] != null &&
                                    receiverAddr['longitude'] != null)
                                  IconButton(
                                    icon: Icon(Icons.map, color: Colors.blue, size: 20),
                                    tooltip: 'Buka di Maps',
                                    onPressed: () => openMap(
                                      double.tryParse(receiverAddr['latitude'].toString()) ?? 0.0,
                                      double.tryParse(receiverAddr['longitude'].toString()) ?? 0.0,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 18, color: Colors.grey[700]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pengirim: ${request['sender_name'] ?? '-'}',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person, size: 18, color: Colors.grey[700]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Penerima: ${request['receiver_name'] ?? '-'}',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.attach_money, size: 18, color: Colors.grey[700]),
                      SizedBox(width: 8),
                      Text(
                        'Estimasi Biaya: ',
                        style: TextStyle(fontSize: 13),
                      ),
                      Text(
                        formatCurrency(request['estimated_cost']),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Colors.grey[700]),
                      SizedBox(width: 8),
                      Text(
                        'Dibuat: ',
                        style: TextStyle(fontSize: 13),
                      ),
                      Text(
                        request['created_at'] != null
                            ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(request['created_at']))
                            : '-',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

