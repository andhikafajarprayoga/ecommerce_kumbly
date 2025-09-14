import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class CourierPackageDetailScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const CourierPackageDetailScreen({
    Key? key,
    required this.request,
  }) : super(key: key);

  @override
  State<CourierPackageDetailScreen> createState() => _CourierPackageDetailScreenState();
}

class _CourierPackageDetailScreenState extends State<CourierPackageDetailScreen> {
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
      Map<String, dynamic> address = json.decode(addressJson);
      List<String> parts = [];
      
      if (address['street'] != null && address['street'].isNotEmpty) 
        parts.add(address['street']);
      if (address['village'] != null && address['village'].isNotEmpty) 
        parts.add('Desa ${address['village']}');
      if (address['district'] != null && address['district'].isNotEmpty) 
        parts.add('Kec. ${address['district']}');
      if (address['city'] != null && address['city'].isNotEmpty) 
        parts.add(address['city']);
      if (address['province'] != null && address['province'].isNotEmpty) 
        parts.add(address['province']);
      if (address['postal_code'] != null && address['postal_code'].isNotEmpty) 
        parts.add(address['postal_code']);
      
      return parts.join(', ');
    } catch (e) {
      return addressJson;
    }
  }

  Future<void> openMaps(double? latitude, double? longitude, String title) async {
    if (latitude == null || longitude == null) {
      Get.snackbar(
        'Error',
        'Koordinat lokasi tidak tersedia',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      // URL untuk Google Maps
      final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
      
      // URL untuk aplikasi Maps default
      final mapsUrl = 'geo:$latitude,$longitude?q=$latitude,$longitude($title)';
      
      // Coba buka aplikasi Maps terlebih dahulu
      if (await canLaunchUrl(Uri.parse(mapsUrl))) {
        await launchUrl(
          Uri.parse(mapsUrl),
          mode: LaunchMode.externalApplication,
        );
      } else if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        // Fallback ke Google Maps web
        await launchUrl(
          Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch maps';
      }
    } catch (e) {
      print('Error opening maps: $e');
      Get.snackbar(
        'Error',
        'Tidak dapat membuka aplikasi maps',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'taken':
        return Colors.blue;
      case 'picked_up':
        return Colors.purple;
      case 'in_transit':
        return Colors.indigo;
      case 'out_for_delivery':
        return Colors.teal;
      case 'delivered':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'taken':
        return 'DIKONFIRMASI';
      case 'picked_up':
        return 'SUDAH DIAMBIL';
      case 'in_transit':
        return 'DALAM PERJALANAN';
      case 'out_for_delivery':
        return 'SEDANG DIKIRIM';
      case 'delivered':
        return 'TERKIRIM';
      case 'cancelled':
        return 'DIBATALKAN';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      title: Text(
        'Detail Paket SR#${widget.request['id'].toString().padLeft(6, '0')}',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      backgroundColor: Colors.blue,
      iconTheme: IconThemeData(color: Colors.white),
      elevation: 0,
      toolbarHeight: 44,
      ),
      body: SingleChildScrollView(
      padding: EdgeInsets.all(10),
      child: Column(
        children: [
        // Status Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
          color: getStatusColor(widget.request['status']).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: getStatusColor(widget.request['status']).withOpacity(0.2),
            width: 1,
          ),
          ),
          child: Column(
          children: [
            Icon(
            Icons.local_shipping,
            size: 32,
            color: getStatusColor(widget.request['status']),
            ),
            SizedBox(height: 6),
            Text(
            getStatusText(widget.request['status']),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: getStatusColor(widget.request['status']),
            ),
            textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
            'Kurir: ${widget.request['courier_name'] ?? 'Tidak diketahui'}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            ),
          ],
          ),
        ),
        SizedBox(height: 10),
        _buildPackageInfoCard(),
        SizedBox(height: 10),
        _buildSenderInfoCard(),
        SizedBox(height: 10),
        _buildReceiverInfoCard(),
        SizedBox(height: 10),
        _buildPaymentInfoCard(),
        SizedBox(height: 16),
        ],
      ),
      ),
    );
  }

  Widget _buildPackageInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.blue, size: 24),
                SizedBox(width: 12),
                Text(
                  'Informasi Paket',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildDetailRow('Nama Barang', widget.request['item_name'] ?? '-'),
            _buildDetailRow('Jenis Barang', widget.request['item_type'] ?? '-'),
            _buildDetailRow('Berat', '${widget.request['weight']} kg'),
            if (widget.request['description'] != null && widget.request['description'].toString().isNotEmpty)
              _buildDetailRow('Deskripsi', widget.request['description']),
            _buildDetailRow('Asuransi', widget.request['insurance'] == true ? 'Ya' : 'Tidak'),
            _buildDetailRow('Estimasi Biaya', formatCurrency(widget.request['estimated_cost']), isHighlighted: true),
            _buildDetailRow('Tanggal Dibuat', DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(widget.request['created_at']))),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderInfoCard() {
    final senderLat = widget.request['sender_latitude']?.toDouble();
    final senderLng = widget.request['sender_longitude']?.toDouble();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_pin_circle, color: Colors.orange, size: 24),
                SizedBox(width: 12),
                Text(
                  'Data Pengirim',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildDetailRow('Nama', widget.request['sender_name'] ?? '-'),
            GestureDetector(
              onTap: () {
              final phone = widget.request['sender_phone'];
              if (phone != null && phone.toString().isNotEmpty) {
                final waUrl = 'https://wa.me/${phone.toString().replaceAll(RegExp(r'[^0-9]'), '')}';
                launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
              }
              },
              child: _buildDetailRow(
              'No. Telepon',
              widget.request['sender_phone'] ?? '-',
              isHighlighted: true,
              ),
            ),
            
            // Alamat dengan tombol maps
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    'Alamat',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(': ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parseAddress(widget.request['sender_address']),
                        style: TextStyle(fontSize: 14),
                      ),
                      if (senderLat != null && senderLng != null) ...[
                        SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => openMaps(senderLat, senderLng, 'Alamat Pengirim'),
                          icon: Icon(Icons.location_on, size: 18),
                          label: Text('Buka di Maps'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            if (senderLat != null && senderLng != null)
              _buildDetailRow('Koordinat', '$senderLat, $senderLng'),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiverInfoCard() {
    final receiverLat = widget.request['receiver_latitude']?.toDouble();
    final receiverLng = widget.request['receiver_longitude']?.toDouble();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.green, size: 24),
                SizedBox(width: 12),
                Text(
                  'Data Penerima',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildDetailRow('Nama', widget.request['receiver_name'] ?? '-'),
            GestureDetector(
              onTap: () {
              final phone = widget.request['receiver_phone'];
              if (phone != null && phone.toString().isNotEmpty) {
                final waUrl = 'https://wa.me/${phone.toString().replaceAll(RegExp(r'[^0-9]'), '')}';
                launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
              }
              },
              child: _buildDetailRow(
              'No. Telepon',
              widget.request['receiver_phone'] ?? '-',
              isHighlighted: true,
              ),
            ),
            
            // Alamat dengan tombol maps
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    'Alamat',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(': ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parseAddress(widget.request['receiver_address']),
                        style: TextStyle(fontSize: 14),
                      ),
                      if (receiverLat != null && receiverLng != null) ...[
                        SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => openMaps(receiverLat, receiverLng, 'Alamat Penerima'),
                          icon: Icon(Icons.location_on, size: 18),
                          label: Text('Buka di Maps'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            if (receiverLat != null && receiverLng != null)
              _buildDetailRow('Koordinat', '$receiverLat, $receiverLng'),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: Colors.purple, size: 24),
                SizedBox(width: 12),
                Text(
                  'Informasi Pembayaran',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildDetailRow('Pembayaran', widget.request['payment_methods']?['name'] ?? 'N/A'),
            _buildDetailRow('Layanan', widget.request['pengiriman']?['nama_pengiriman'] ?? 'N/A'),
            if (widget.request['admin_fee'] != null && widget.request['admin_fee'] > 0)
            _buildDetailRow('Total Estimasi', formatCurrency(widget.request['estimated_cost']), isHighlighted: true),
            
            // Payment Proof Status
            if (widget.request['payment_proof'] != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      widget.request['payment_proof'] == 'COD' 
                          ? 'Pembayaran: Cash on Delivery (COD)'
                          : 'Pembayaran: Sudah Dikonfirmasi',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(': ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                color: isHighlighted ? Colors.blue : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}