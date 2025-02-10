import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';

class PaymentManagementScreen extends StatefulWidget {
  @override
  _PaymentManagementScreenState createState() =>
      _PaymentManagementScreenState();
}

class _PaymentManagementScreenState extends State<PaymentManagementScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> payments = [];
  List<Map<String, dynamic>> filteredPayments = [];
  bool isLoading = true;
  String selectedStatus = 'pending';
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchPayments();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void searchPayments(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredPayments = List.from(payments);
      });
      return;
    }

    setState(() {
      filteredPayments = payments.where((payment) {
        final id = payment['id'].toString().toLowerCase();
        final buyerId = payment['buyer_id'].toString().toLowerCase();
        final searchLower = query.toLowerCase();

        return id.contains(searchLower) || buyerId.contains(searchLower);
      }).toList();
    });
  }

  Future<void> fetchPayments() async {
    try {
      setState(() => isLoading = true);

      // Ambil dulu data payment_groups
      final response = await supabase
          .from('payment_groups')
          .select('*')
          .eq('payment_status', selectedStatus)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> paymentsData =
          List<Map<String, dynamic>>.from(response);

      // Ambil data payment_methods secara terpisah
      final methodsResponse =
          await supabase.from('payment_methods').select('*');

      final List<Map<String, dynamic>> methodsData =
          List<Map<String, dynamic>>.from(methodsResponse);

      // Gabungkan data secara manual
      final enrichedPayments = paymentsData.map((payment) {
        final method = methodsData.firstWhere(
          (m) => m['id'] == payment['payment_method_id'],
          orElse: () => {'name': 'Unknown', 'admin': 0},
        );

        return {
          ...payment,
          'payment_method': method,
        };
      }).toList();

      setState(() {
        payments = enrichedPayments;
        filteredPayments = List.from(payments);
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching payments: $e');
      setState(() => isLoading = false);
      Get.snackbar(
        'Error',
        'Gagal mengambil data pembayaran: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> updatePaymentStatus(String paymentId, String newStatus) async {
    try {
      await supabase
          .from('payment_groups')
          .update({'payment_status': newStatus}).eq('id', paymentId);

      Get.snackbar(
        'Sukses',
        'Status pembayaran berhasil diperbarui',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      fetchPayments();
    } catch (e) {
      print('Error updating payment status: $e');
      Get.snackbar(
        'Error',
        'Gagal memperbarui status pembayaran',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Pembayaran', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Cari ID Pembayaran atau ID Pembeli...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              onChanged: searchPayments,
            ),
          ),
          _buildStatusFilter(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hasil: ${filteredPayments.length} pembayaran',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                if (searchController.text.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      searchController.clear();
                      searchPayments('');
                    },
                    icon: Icon(Icons.clear),
                    label: Text('Hapus Filter'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : filteredPayments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              searchController.text.isEmpty
                                  ? 'Tidak ada pembayaran ${selectedStatus}'
                                  : 'Tidak ada hasil pencarian',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredPayments.length,
                        padding: EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          return _buildPaymentCard(filteredPayments[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('pending', 'Menunggu'),
            SizedBox(width: 8),
            _buildFilterChip('confirmed', 'Dikonfirmasi'),
            SizedBox(width: 8),
            _buildFilterChip('rejected', 'Ditolak'),
            SizedBox(width: 8),
            _buildFilterChip('completed', 'Selesai'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String status, String label) {
    return FilterChip(
      selected: selectedStatus == status,
      label: Text(label),
      onSelected: (bool selected) {
        setState(() {
          selectedStatus = status;
        });
        fetchPayments();
      },
      backgroundColor: Colors.grey[200],
      selectedColor: AppTheme.primary.withOpacity(0.2),
      checkmarkColor: AppTheme.primary,
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final paymentMethod = payment['payment_method'];

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ExpansionTile(
        title: Text(
          'ID: ${payment['id'].toString().substring(0, 8)}...',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buyer ID: ${payment['buyer_id'] ?? 'Unknown'}'),
            Text(
                'Total: Rp ${NumberFormat('#,###').format(payment['total_amount'] ?? 0)}'),
            Text('Status: ${payment['payment_status'] ?? 'Unknown'}'),
            if (paymentMethod != null)
              Text('Metode: ${paymentMethod['name']}',
                  style: TextStyle(color: Colors.blue)),
            if (payment['payment_proof'] != null &&
                payment['payment_proof'] != 'COD')
              Text('✓ Bukti Transfer', style: TextStyle(color: Colors.green))
            else if (payment['payment_proof'] == 'COD')
              Text('COD', style: TextStyle(color: Colors.orange)),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Payment Method Details
                if (paymentMethod != null) ...[
                  Text('Detail Metode Pembayaran:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 8),
                  _buildDetailRow('Metode', paymentMethod['name']),
                  if (paymentMethod['account_number'] != null)
                    _buildDetailRow(
                        'Nomor Rekening', paymentMethod['account_number']),
                  if (paymentMethod['account_name'] != null)
                    _buildDetailRow(
                        'Nama Rekening', paymentMethod['account_name']),
                  if (paymentMethod['description'] != null)
                    _buildDetailRow('Keterangan', paymentMethod['description']),
                  _buildDetailRow('Biaya Admin',
                      'Rp ${NumberFormat('#,###').format(paymentMethod['admin'] ?? 0)}'),
                  Divider(height: 24),
                ],

                // Payment Details
                Text('Detail Pembayaran:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                _buildDetailRow('Admin Fee',
                    'Rp ${NumberFormat('#,###').format(payment['admin_fee'] ?? 0)}'),
                _buildDetailRow('Ongkos Kirim',
                    'Rp ${NumberFormat('#,###').format(payment['total_shipping_cost'] ?? 0)}'),
                _buildDetailRow('Total Pembayaran',
                    'Rp ${NumberFormat('#,###').format(payment['total_amount'] ?? 0)}',
                    valueColor: AppTheme.primary),
                _buildDetailRow(
                    'Tanggal',
                    DateFormat('dd MMM yyyy HH:mm')
                        .format(DateTime.parse(payment['created_at']))),

                // Bukti Transfer
                if (payment['payment_proof'] != null &&
                    payment['payment_proof'] != 'COD') ...[
                  SizedBox(height: 16),
                  Text('Bukti Transfer:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: InkWell(
                      onTap: () {
                        // Tampilkan gambar dalam dialog untuk melihat lebih detail
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppBar(
                                  title: Text('Bukti Transfer'),
                                  leading: IconButton(
                                    icon: Icon(Icons.close),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ),
                                InteractiveViewer(
                                  panEnabled: true,
                                  boundaryMargin: EdgeInsets.all(20),
                                  minScale: 0.5,
                                  maxScale: 4,
                                  child: Image.network(
                                    payment['payment_proof'],
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          children: [
                                            Icon(Icons.broken_image,
                                                size: 64, color: Colors.grey),
                                            SizedBox(height: 8),
                                            Text('Gagal memuat gambar'),
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
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          payment['payment_proof'],
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.grey[200],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image,
                                      size: 64, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Gagal memuat gambar'),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],

                // Action Buttons
                SizedBox(height: 16),
                if (selectedStatus == 'pending')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () =>
                            updatePaymentStatus(payment['id'], 'confirmed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: Text('Konfirmasi',
                            style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            updatePaymentStatus(payment['id'], 'rejected'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: Text('Tolak',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
