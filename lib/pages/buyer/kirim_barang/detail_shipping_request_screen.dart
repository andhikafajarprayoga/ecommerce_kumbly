import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/date_formatter.dart';
import 'dart:convert';

class DetailShippingRequestScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const DetailShippingRequestScreen({
    Key? key,
    required this.request,
  }) : super(key: key);

  @override
  State<DetailShippingRequestScreen> createState() => _DetailShippingRequestScreenState();
}

class _DetailShippingRequestScreenState extends State<DetailShippingRequestScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = false;

  String formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    try {
      return NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amount);
    } catch (e) {
      return 'Rp 0';
    }
  }

  Color _getShippingStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'waiting_verification':
        return Colors.orange;
      case 'confirmed':
      case 'picked_up':
        return Colors.blue;
      case 'in_transit':
      case 'out_for_delivery':
        return Colors.green;
      case 'delivered':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getShippingStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'MENUNGGU KONFIRMASI';
      case 'waiting_verification':
        return 'MENUNGGU VERIFIKASI PEMBAYARAN';
      case 'confirmed':
        return 'DIKONFIRMASI';
      case 'picked_up':
        return 'BARANG TELAH DIAMBIL';
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

  String parseAddress(String? addressJson) {
    if (addressJson == null || addressJson.isEmpty) return '-';
    
    try {
      Map<String, dynamic> address = json.decode(addressJson);
      List<String> addressParts = [];
      
      if (address['street']?.isNotEmpty == true)
        addressParts.add(address['street']);
      if (address['village']?.isNotEmpty == true)
        addressParts.add("Desa ${address['village']}");
      if (address['district']?.isNotEmpty == true)
        addressParts.add("Kec. ${address['district']}");
      if (address['city']?.isNotEmpty == true)
        addressParts.add(address['city']);
      if (address['province']?.isNotEmpty == true)
        addressParts.add(address['province']);
      if (address['postal_code']?.isNotEmpty == true)
        addressParts.add(address['postal_code']);
        
      return addressParts.where((part) => part.isNotEmpty).join(', ');
    } catch (e) {
      return addressJson;
    }
  }

  bool _showStatusTimeline = true;

  Widget _buildStatusTimeline() {
    List<Map<String, dynamic>> statusList = [
      {'status': 'pending', 'title': 'Permintaan Dibuat', 'description': 'Permintaan pengiriman telah dibuat'},
      {'status': 'waiting_verification', 'title': 'Menunggu Verifikasi', 'description': 'Menunggu verifikasi pembayaran'},
      {'status': 'confirmed', 'title': 'Dikonfirmasi', 'description': 'Permintaan telah dikonfirmasi'},
      {'status': 'picked_up', 'title': 'Barang Diambil', 'description': 'Kurir telah mengambil barang'},
      {'status': 'in_transit', 'title': 'Dalam Perjalanan', 'description': 'Barang sedang dalam perjalanan'},
      {'status': 'delivered', 'title': 'Terkirim', 'description': 'Barang telah sampai di tujuan'},
    ];

    String currentStatus = widget.request['status'];
    int currentIndex = statusList.indexWhere((item) => item['status'] == currentStatus);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Status Pengiriman',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(
                    _showStatusTimeline ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _showStatusTimeline = !_showStatusTimeline;
                    });
                  },
                  tooltip: _showStatusTimeline ? 'Sembunyikan' : 'Tampilkan',
                ),
              ],
            ),
            SizedBox(height: 16),
            AnimatedCrossFade(
              duration: Duration(milliseconds: 200),
              crossFadeState: _showStatusTimeline
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: statusList.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> statusItem = entry.value;
                  bool isActive = index <= currentIndex;
                  bool isCurrent = index == currentIndex;
                  bool isLast = index == statusList.length - 1;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? (isCurrent ? AppTheme.primary : Colors.green)
                                  : Colors.grey.shade300,
                              border: Border.all(
                                color: isActive
                                    ? (isCurrent ? AppTheme.primary : Colors.green)
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              isActive ? Icons.check : Icons.circle,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 40,
                              color: isActive ? Colors.green : Colors.grey.shade300,
                            ),
                        ],
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusItem['title'],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isActive ? Colors.black87 : Colors.grey,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                statusItem['description'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isActive ? Colors.grey[600] : Colors.grey[400],
                                ),
                              ),
                              if (isCurrent)
                                Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    DateFormatter.formatShortDate(widget.request['updated_at'] ?? widget.request['created_at']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              secondChild: SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  bool _showDetailCard = false;

  Widget _buildDetailCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with show/hide button
            Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primary, size: 22),
                SizedBox(width: 8),
                Text(
                  'Detail Pengiriman',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(
                    _showDetailCard ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _showDetailCard = !_showDetailCard;
                    });
                  },
                  tooltip: _showDetailCard ? 'Sembunyikan' : 'Tampilkan',
                ),
              ],
            ),
            SizedBox(height: 8),
            AnimatedCrossFade(
              duration: Duration(milliseconds: 200),
              crossFadeState: _showDetailCard
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  SizedBox(height: 10),
                  // Shopee-style info rows
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildShopeeRow('ID Permintaan', '#${widget.request['id'].toString().length >= 8 
                            ? widget.request['id'].toString().substring(widget.request['id'].toString().length - 8)
                            : widget.request['id'].toString()}'),
                        _buildShopeeRow('Nama Barang', widget.request['item_name'] ?? '-'),
                        _buildShopeeRow('Jenis Barang', widget.request['item_type'] ?? '-'),
                        _buildShopeeRow('Berat', '${widget.request['weight']} kg'),
                        if (widget.request['description'] != null && widget.request['description'].toString().isNotEmpty)
                          _buildShopeeRow('Deskripsi', widget.request['description']),
                        _buildShopeeRow('Layanan Pengiriman', widget.request['pengiriman']?['nama_pengiriman'] ?? '-'),
                        _buildShopeeRow('Metode Pembayaran', widget.request['payment_methods']?['name'] ?? '-'),
                        _buildShopeeRow('Asuransi', widget.request['insurance'] == true ? 'Ya (+Rp 2.000)' : 'Tidak'),
                        _buildShopeeRow('Estimasi Biaya', formatCurrency(widget.request['estimated_cost']), highlight: true),
                        if (widget.request['admin_fee'] != null && widget.request['admin_fee'] > 0)
                          _buildShopeeRow('Biaya Admin', formatCurrency(widget.request['admin_fee'])),
                        _buildShopeeRow('Tanggal Permintaan', DateFormatter.formatShortDate(widget.request['created_at'])),
                      ],
                    ),
                  ),
                ],
              ),
              secondChild: SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // Shopee-style row with divider and highlight
  Widget _buildShopeeRow(String label, String value, {bool highlight = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(': ', style: TextStyle(fontSize: 13.5, color: Colors.grey[700])),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                    color: highlight ? Colors.deepOrange : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.7,
          color: Colors.grey[200],
        ),
      ],
    );
  }

  bool _showContactCard = false;

  Widget _buildContactCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with show/hide button
            Row(
              children: [
                Icon(Icons.contacts, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Data Kontak',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(
                    _showContactCard ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _showContactCard = !_showContactCard;
                    });
                  },
                  tooltip: _showContactCard ? 'Sembunyikan' : 'Tampilkan',
                ),
              ],
            ),
            SizedBox(height: 8),
            AnimatedCrossFade(
              duration: Duration(milliseconds: 200),
              crossFadeState: _showContactCard
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  // Data Pengirim
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: Colors.blue.shade700, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Pengirim',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        _buildDetailRow('Nama', widget.request['sender_name'] ?? '-'),
                        _buildDetailRow('No. Telepon', widget.request['sender_phone'] ?? '-'),
                        _buildDetailRow('Alamat', parseAddress(widget.request['sender_address'])),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  // Data Penerima
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_pin_circle, color: Colors.green.shade700, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Penerima',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        _buildDetailRow('Nama', widget.request['receiver_name'] ?? '-'),
                        _buildDetailRow('No. Telepon', widget.request['receiver_phone'] ?? '-'),
                        _buildDetailRow('Alamat', parseAddress(widget.request['receiver_address'])),
                      ],
                    ),
                  ),
                ],
              ),
              secondChild: SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentProofCard() {
    if (widget.request['payment_proof'] == null) return SizedBox.shrink();
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Bukti Pembayaran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (widget.request['payment_proof'] == 'COD')
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.handshake, color: Colors.orange, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash on Delivery (COD)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          Text(
                            'Pembayaran akan dilakukan saat barang sampai',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.request['payment_proof'],
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.grey[400], size: 48),
                          SizedBox(height: 8),
                          Text(
                            'Gagal memuat gambar',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final status = widget.request['status'].toString().toLowerCase();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Tombol Batalkan (hanya untuk status pending)
            if (status == 'pending') ...[
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showCancelDialog(),
                  icon: Icon(Icons.cancel),
                  label: Text('Batalkan Permintaan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],

            // Tombol Konfirmasi Terima (untuk status delivered)
            if (status == 'delivered') ...[
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showConfirmDeliveryDialog(),
                  icon: Icon(Icons.check_circle),
                  label: Text('Konfirmasi Terima'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCancelDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Batalkan Permintaan'),
        content: Text('Apakah Anda yakin ingin membatalkan permintaan pengiriman ini?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => _cancelRequest(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showConfirmDeliveryDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Konfirmasi Penerimaan'),
        content: Text('Apakah Anda sudah menerima barang dengan baik?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Belum'),
          ),
          ElevatedButton(
            onPressed: () => _confirmDelivery(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Ya, Sudah Terima', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRequest() async {
    setState(() => isLoading = true);
    try {
      await supabase
          .from('shipping_requests')
          .update({'status': 'cancelled'})
          .eq('id', widget.request['id']);

      Get.back(); // Close dialog
      Get.back(); // Back to previous screen
      Get.snackbar(
        'Berhasil',
        'Permintaan pengiriman berhasil dibatalkan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error cancelling request: $e');
      Get.snackbar(
        'Error',
        'Gagal membatalkan permintaan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    setState(() => isLoading = false);
  }

  Future<void> _confirmDelivery() async {
    setState(() => isLoading = true);
    try {
      await supabase
          .from('shipping_requests')
          .update({'status': 'completed'})
          .eq('id', widget.request['id']);

      Get.back(); // Close dialog
      Get.back(); // Back to previous screen
      Get.snackbar(
        'Berhasil',
        'Penerimaan barang berhasil dikonfirmasi',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error confirming delivery: $e');
      Get.snackbar(
        'Error',
        'Gagal mengkonfirmasi penerimaan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    setState(() => isLoading = false);
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Kirim Barang', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Header (ukuran diperkecil)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
              color: _getShippingStatusColor(widget.request['status']).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _getShippingStatusColor(widget.request['status']).withOpacity(0.22),
                width: 1,
              ),
              ),
              child: Column(
              children: [
                Icon(
                Icons.local_shipping,
                size: 32,
                color: _getShippingStatusColor(widget.request['status']),
                ),
                SizedBox(height: 4),
                Text(
                _getShippingStatusText(widget.request['status']),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _getShippingStatusColor(widget.request['status']),
                ),
                textAlign: TextAlign.center,
                ),
                SizedBox(height: 2),
                Text(
                'ID: #${widget.request['id'].toString().length >= 8 
                  ? widget.request['id'].toString().substring(widget.request['id'].toString().length - 8)
                  : widget.request['id'].toString()}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey[600],
                ),
                ),
              ],
              ),
            ),
            
            SizedBox(height: 16),
            
            // Status Timeline
            _buildStatusTimeline(),
            
            SizedBox(height: 16),
            
            // Detail Pengiriman
            _buildDetailCard(),
            
            SizedBox(height: 16),
            
            // Data Kontak
            _buildContactCard(),
            
            SizedBox(height: 16),
            
            // Bukti Pembayaran
            _buildPaymentProofCard(),
            
            SizedBox(height: 16),
            
            // Action Buttons
            _buildActionButtons(),
            
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
