import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import 'payment_summary_screen.dart';

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
      if (!mounted) return;
      setState(() => isLoading = true);

      // 1. Ambil data payment groups dengan join ke orders
      final response = await supabase
          .from('payment_groups')
          .select('''
            *,
            orders!orders_payment_group_id_fkey (
              id,
              total_amount,
              shipping_cost,
              status,
              merchant_id,
              shipping_address,
              created_at
            )
          ''')
          .eq('payment_status', selectedStatus)
          .order('payment_method_id', ascending: true)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> paymentsData =
          List<Map<String, dynamic>>.from(response);

      // 2. Ambil semua payment methods
      final methodsResponse = await supabase.from('payment_methods').select();
      final methodsData = Map<int, dynamic>.fromEntries(
          (methodsResponse as List)
              .map((method) => MapEntry(method['id'], method)));

      // 3. Ambil data buyer dan merchant untuk setiap payment group
      for (var payment in paymentsData) {
        // Tambahkan payment method info
        if (payment['payment_method_id'] != null) {
          payment['payment_method'] = methodsData[payment['payment_method_id']];
        }

        // Tambahkan buyer info
        if (payment['buyer_id'] != null) {
          final buyerResponse = await supabase
              .from('users')
              .select('email, full_name, phone')
              .eq('id', payment['buyer_id'])
              .single();
          payment['buyer'] = buyerResponse;
        }

        // Tambahkan merchant info untuk setiap order
        if (payment['orders'] != null) {
          for (var order in payment['orders']) {
            if (order['merchant_id'] != null) {
              final merchantResponse = await supabase
                  .from('merchants')
                  .select('store_name')
                  .eq('id', order['merchant_id'])
                  .single();
              order['merchant'] = merchantResponse;
            }
          }
        }
      }

      // 4. Urutkan berdasarkan payment_method_id dan created_at
      paymentsData.sort((a, b) {
        int methodIdA = a['payment_method_id'] ?? 0;
        int methodIdB = b['payment_method_id'] ?? 0;
        if (methodIdA != methodIdB) {
          return methodIdA.compareTo(methodIdB);
        }
        // Jika payment_method_id sama, urutkan berdasarkan created_at
        DateTime dateA = DateTime.parse(a['created_at']);
        DateTime dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA); // descending
      });

      if (!mounted) return;
      setState(() {
        payments = paymentsData;
        filteredPayments = List.from(payments);
        isLoading = false;
      });

      print('Debug: Fetched ${payments.length} payment groups');
      print('Debug: First payment group: ${payments.firstOrNull}');
    } catch (e) {
      print('Error fetching payments: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
      Get.snackbar(
        'Error',
        'Gagal mengambil data pembayaran: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: Duration(seconds: 3),
        margin: EdgeInsets.all(10),
        borderRadius: 8,
        icon: Icon(Icons.error, color: Colors.white),
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
        title: Text('Kelola Pembayaran'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.analytics),
            onPressed: () {
              Get.to(() => PaymentSummaryScreen(payments: filteredPayments));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Cari ID Pembayaran atau ID Pembeli...',
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              onChanged: searchPayments,
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
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

          // Results Count and Loading Indicator
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Hasil: ${filteredPayments.length} pembayaran',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (isLoading) ...[
                  SizedBox(width: 8),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),

          // Payment List Grouped by Payment Method
          Expanded(
            child: ListView.builder(
              itemCount: _getUniquePaymentMethods().length,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final methodId = _getUniquePaymentMethods()[index];
                final methodPayments = filteredPayments
                    .where((p) => p['payment_method_id'] == methodId)
                    .toList();

                if (methodPayments.isEmpty) return SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment Method Header
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.pink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getPaymentMethodIcon(methodId),
                            color: Colors.pink,
                          ),
                          SizedBox(width: 8),
                          Text(
                            methodPayments.first['payment_method']?['name'] ??
                                'Unknown Method',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.pink,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.pink,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${methodPayments.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Payment Items
                    ...methodPayments
                        .map((payment) => _buildPaymentListItem(payment)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<int> _getUniquePaymentMethods() {
    return filteredPayments
        .map((p) => p['payment_method_id'] as int?)
        .where((id) => id != null)
        .toSet()
        .toList()
        .cast<int>()
      ..sort();
  }

  IconData _getPaymentMethodIcon(int? methodId) {
    switch (methodId) {
      case 1:
        return Icons.account_balance; // Transfer Bank
      case 2:
        return Icons.local_shipping; // COD
      case 3:
        return Icons.payment; // E-Wallet
      default:
        return Icons.payment;
    }
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

  Widget _buildPaymentListItem(Map<String, dynamic> payment) {
    final paymentMethod = payment['payment_method'];
    final buyer = payment['buyer'];
    final paymentProof = payment['payment_proof'];

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          'ID: ${payment['id'].toString().substring(0, 8)}...',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pembeli: ${payment['buyer']?['full_name'] ?? 'Unknown'}'),
            Text('Email: ${payment['buyer']?['email'] ?? 'Unknown'}'),
            Text('Telp: ${payment['buyer']?['phone'] ?? '-'}'),
            Text(
                'Total Produk: Rp ${NumberFormat('#,###').format(payment['total_amount'] ?? 0)}'),
            if (payment['payment_proof'] == 'COD')
              Text('COD',
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rincian Pembayaran:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                _buildDetailRow('Total Produk',
                    'Rp ${NumberFormat('#,###').format(payment['total_amount'] ?? 0)}'),
                _buildDetailRow('Ongkos Kirim',
                    'Rp ${NumberFormat('#,###').format(payment['total_shipping_cost'] ?? 0)}'),
                _buildDetailRow('Biaya Admin',
                    'Rp ${NumberFormat('#,###').format(payment['admin_fee'] ?? 0)}'),
                Divider(),
                _buildDetailRow('Total Pembayaran',
                    'Rp ${NumberFormat('#,###').format((payment['total_amount'] ?? 0) + (payment['total_shipping_cost'] ?? 0) + (payment['admin_fee'] ?? 0))}',
                    valueColor: Colors.pink, isBold: true),
                if (payment['payment_proof'] == 'COD') ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.local_shipping, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pembayaran COD',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (paymentMethod != null) ...[
                  SizedBox(height: 16),
                  Text('Metode Pembayaran:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(paymentMethod['name'] ?? 'Unknown'),
                ],
                if (buyer != null) ...[
                  SizedBox(height: 16),
                  Text('Informasi Pembeli:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Nama: ${buyer['full_name'] ?? 'Unknown'}'),
                  Text('Email: ${buyer['email'] ?? 'Unknown'}'),
                  Text('Telepon: ${buyer['phone'] ?? '-'}'),
                ],
                SizedBox(height: 16),
                Text('Bukti Pembayaran:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                if (paymentProof == 'COD')
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.local_shipping, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Pembayaran COD',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                  )
                else if (paymentProof != null &&
                    paymentProof.isNotEmpty &&
                    paymentProof != 'COD')
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppBar(
                                title: Text('Bukti Pembayaran'),
                                backgroundColor: Colors.pink,
                                foregroundColor: Colors.white,
                                leading: IconButton(
                                  icon: Icon(Icons.close),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                              Container(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.7,
                                ),
                                child: Image.network(
                                  paymentProof,
                                  fit: BoxFit.contain,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.error_outline,
                                              color: Colors.red, size: 48),
                                          SizedBox(height: 8),
                                          Text('Gagal memuat gambar',
                                              style:
                                                  TextStyle(color: Colors.red)),
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
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          paymentProof,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              padding: EdgeInsets.all(16),
                              child: Icon(Icons.image_not_supported,
                                  color: Colors.grey),
                            );
                          },
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.image_not_supported, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'Belum ada bukti pembayaran',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.pink : null,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
