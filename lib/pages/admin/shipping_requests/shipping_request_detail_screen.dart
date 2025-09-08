import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import 'dart:convert';

class ShippingRequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  ShippingRequestDetailScreen({required this.request});

  @override
  _ShippingRequestDetailScreenState createState() => _ShippingRequestDetailScreenState();
}

class _ShippingRequestDetailScreenState extends State<ShippingRequestDetailScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic> request = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    request = Map.from(widget.request);
    fetchDetailedRequest();
  }

  Future<void> fetchDetailedRequest() async {
    try {
      final response = await supabase
          .from('shipping_requests')
          .select('''
            *,
            users(full_name, phone, email),
            pengiriman(nama_pengiriman, harga_per_kg, harga_per_km),
            payment_methods(name, account_number, account_name)
          ''')
          .eq('id', request['id'])
          .single();

      setState(() {
        request = response;
      });
    } catch (e) {
      print('Error fetching detailed request: $e');
    }
  }

  Future<void> updateStatus(String newStatus) async {
    setState(() => isLoading = true);
    try {
      await supabase
          .from('shipping_requests')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', request['id']);

      setState(() {
        request['status'] = newStatus;
      });

      Get.snackbar('Berhasil', 'Status berhasil diperbarui');
    } catch (e) {
      print('Error updating status: $e');
      Get.snackbar('Error', 'Gagal memperbarui status');
    } finally {
      setState(() => isLoading = false);
    }
  }

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
      
      if (address['street'] != null) parts.add(address['street']);
      if (address['village'] != null) parts.add('Desa ${address['village']}');
      if (address['district'] != null) parts.add('Kec. ${address['district']}');
      if (address['city'] != null) parts.add(address['city']);
      if (address['province'] != null) parts.add(address['province']);
      if (address['postal_code'] != null) parts.add(address['postal_code']);
      
      return parts.join(', ');
    } catch (e) {
      return addressJson;
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'waiting_verification':
        return Colors.blue;
      case 'confirmed':
        return Colors.green;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Permintaan SR#${request['id'].toString().padLeft(6, '0')}', 
                   style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'update_status') {
                _showStatusUpdateDialog();
              } else if (value == 'delete') {
                _showDeleteDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'update_status',
                child: Row(
                  children: [
                    Icon(Icons.update),
                    SizedBox(width: 8),
                    Text('Update Status'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Hapus', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(),
            SizedBox(height: 16),
            
            // Basic Info Card
            _buildBasicInfoCard(),
            SizedBox(height: 16),
            
            // Sender Info Card
            _buildSenderInfoCard(),
            SizedBox(height: 16),
            
            // Receiver Info Card
            _buildReceiverInfoCard(),
            SizedBox(height: 16),
            
            // Shipping Info Card
            _buildShippingInfoCard(),
            SizedBox(height: 16),
            
            // Payment Info Card
            _buildPaymentInfoCard(),
            SizedBox(height: 16),
            
            // User Info Card
            _buildUserInfoCard(),
            SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionButtons(),
    );
  }

  Widget _buildStatusCard() {
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
                Icon(Icons.info_outline, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Status Pengiriman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: getStatusColor(request['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: getStatusColor(request['status'])),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.local_shipping,
                    size: 48,
                    color: getStatusColor(request['status']),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _getStatusText(request['status']),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: getStatusColor(request['status']),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Dibuat: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(request['created_at']))}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (request['updated_at'] != null)
                    Text(
                      'Diperbarui: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(request['updated_at']))}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
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
                Icon(Icons.inventory_2_outlined, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Informasi Barang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            SizedBox(height: 16),
            _buildDetailRow('Nama Barang', request['item_name']),
            _buildDetailRow('Jenis Barang', request['item_type']),
            _buildDetailRow('Berat', '${request['weight']} kg'),
            if (request['description'] != null && request['description'].toString().isNotEmpty)
              _buildDetailRow('Deskripsi', request['description']),
            _buildDetailRow('Asuransi', request['insurance'] == true ? 'Ya' : 'Tidak'),
            _buildDetailRow('Estimasi Biaya', formatCurrency(request['estimated_cost']), isHighlighted: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderInfoCard() {
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
                Icon(Icons.person_outline, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Data Pengirim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            SizedBox(height: 16),
            _buildDetailRow('Nama', request['sender_name']),
            _buildDetailRow('No. Telepon', request['sender_phone']),
            _buildDetailRow('Alamat', parseAddress(request['sender_address'])),
            if (request['sender_latitude'] != null && request['sender_longitude'] != null)
              _buildDetailRow('Koordinat', '${request['sender_latitude']}, ${request['sender_longitude']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiverInfoCard() {
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
                Icon(Icons.location_on_outlined, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Data Penerima', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            SizedBox(height: 16),
            _buildDetailRow('Nama', request['receiver_name']),
            _buildDetailRow('No. Telepon', request['receiver_phone']),
            _buildDetailRow('Alamat', parseAddress(request['receiver_address'])),
            if (request['receiver_latitude'] != null && request['receiver_longitude'] != null)
              _buildDetailRow('Koordinat', '${request['receiver_latitude']}, ${request['receiver_longitude']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingInfoCard() {
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
                Icon(Icons.local_shipping_outlined, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Informasi Pengiriman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            SizedBox(height: 16),
            _buildDetailRow('Layanan Pengiriman', request['pengiriman']?['nama_pengiriman'] ?? 'N/A'),
            if (request['pengiriman'] != null) ...[
              _buildDetailRow('Tarif per KG', formatCurrency(request['pengiriman']['harga_per_kg'])),
              _buildDetailRow('Tarif per KM', formatCurrency(request['pengiriman']['harga_per_km'])),
            ],
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
                Icon(Icons.payment, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Informasi Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            SizedBox(height: 16),
            _buildDetailRow('Metode Pembayaran', request['payment_methods']?['name'] ?? 'N/A'),
            if (request['payment_methods'] != null) ...[
              if (request['payment_methods']['account_number'] != null)
                _buildDetailRow('No. Rekening', request['payment_methods']['account_number']),
              if (request['payment_methods']['account_name'] != null)
                _buildDetailRow('Atas Nama', request['payment_methods']['account_name']),
            ],
            if (request['admin_fee'] != null && request['admin_fee'] > 0)
              _buildDetailRow('Biaya Admin', formatCurrency(request['admin_fee'])),
            _buildDetailRow('Total Estimasi', formatCurrency(request['estimated_cost']), isHighlighted: true),
            
            // Payment Proof
            if (request['payment_proof'] != null) ...[
              SizedBox(height: 16),
              Text('Bukti Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              if (request['payment_proof'] == 'COD')
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.handshake, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Cash on Delivery (COD)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    request['payment_proof'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, color: Colors.grey[400]),
                              Text('Gagal memuat gambar', style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
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
                Icon(Icons.account_circle_outlined, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Informasi Pengguna', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            SizedBox(height: 16),
            _buildDetailRow('Nama Lengkap', request['users']?['full_name'] ?? 'N/A'),
            _buildDetailRow('No. Telepon', request['users']?['phone'] ?? 'N/A'),
            _buildDetailRow('Email', request['users']?['email'] ?? 'N/A'),
            _buildDetailRow('User ID', request['user_id']),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Text(': ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                color: isHighlighted ? AppTheme.primary : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showStatusUpdateDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Update Status', style: TextStyle(color: Colors.white)),
            ),
          ),
          SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _showDeleteDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            child: Icon(Icons.delete, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showStatusUpdateDialog() {
    final statusOptions = [
      'pending',
      'waiting_verification',
      'confirmed',
      'picked_up',
      'in_transit',
      'out_for_delivery',
      'delivered',
      'cancelled'
    ];

    Get.dialog(
      AlertDialog(
        title: Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statusOptions.map((status) => ListTile(
            title: Text(_getStatusText(status)),
            trailing: request['status'] == status ? Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () {
              Get.back();
              if (request['status'] != status) {
                updateStatus(status);
              }
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Hapus Permintaan'),
        content: Text('Apakah Anda yakin ingin menghapus permintaan pengiriman ini?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              try {
                await supabase
                    .from('shipping_requests')
                    .delete()
                    .eq('id', request['id']);
                
                Get.back(); // Kembali ke list
                Get.snackbar('Berhasil', 'Permintaan berhasil dihapus');
              } catch (e) {
                Get.snackbar('Error', 'Gagal menghapus permintaan');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu';
      case 'waiting_verification':
        return 'Menunggu Verifikasi';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'picked_up':
        return 'Diambil';
      case 'in_transit':
        return 'Dalam Perjalanan';
      case 'out_for_delivery':
        return 'Sedang Dikirim';
      case 'delivered':
        return 'Terkirim';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }
}
