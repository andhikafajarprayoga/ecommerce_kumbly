import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';

class PengirimanTypesScreen extends StatefulWidget {
  @override
  _PengirimanTypesScreenState createState() => _PengirimanTypesScreenState();
}

class _PengirimanTypesScreenState extends State<PengirimanTypesScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> pengirimanList = [];
  Map<int, List<Map<String, dynamic>>> ordersByType = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPengiriman();
  }

  Future<void> fetchPengiriman() async {
    try {
      final response = await supabase
          .from('pengiriman')
          .select()
          .order('id_pengiriman', ascending: true);

      setState(() {
        pengirimanList = List<Map<String, dynamic>>.from(response);
      });

      // Fetch orders untuk setiap tipe pengiriman
      for (var pengiriman in pengirimanList) {
        await fetchOrdersByType(pengiriman['id_pengiriman']);
      }

      setState(() => isLoading = false);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal mengambil data pengiriman: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchOrdersByType(int pengirimanId) async {
    try {
      final response = await supabase
          .from('orders')
          .select('''
            id,
            created_at,
            total_amount,
            payment_groups (
              payment_status
            ),
            users (
              email
            )
          ''')
          .eq('pengiriman_id', pengirimanId)
          .order('created_at', ascending: false);

      setState(() {
        ordersByType[pengirimanId] = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching orders for type $pengirimanId: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tipe Pengiriman'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : pengirimanList.isEmpty
              ? Center(child: Text('Tidak ada data pengiriman'))
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: pengirimanList.length,
                  itemBuilder: (context, index) {
                    final pengiriman = pengirimanList[index];
                    final orders =
                        ordersByType[pengiriman['id_pengiriman']] ?? [];

                    return ExpansionTile(
                      title: Row(
                        children: [
                          Icon(Icons.local_shipping,
                              color: AppTheme.primary, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pengiriman['nama_pengiriman'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${orders.length} Pesanan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPriceRow(
                                'Harga per KG',
                                pengiriman['harga_per_kg'],
                              ),
                              SizedBox(height: 4),
                              _buildPriceRow(
                                'Harga per KM',
                                pengiriman['harga_per_km'],
                              ),
                              Divider(height: 24),
                              Text(
                                'Daftar Pesanan',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              if (orders.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Belum ada pesanan',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: orders.length,
                                  itemBuilder: (context, index) {
                                    final order = orders[index];
                                    return Card(
                                      margin: EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title: Text(
                                          'Order #${order['id']}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Pembeli: ${order['users']['email']}',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            Text(
                                              'Tanggal: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(order['created_at']))}',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            Text(
                                              'Total: Rp ${NumberFormat('#,###').format(order['total_amount'])}',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        trailing: _buildStatusChip(
                                          order['payment_groups']
                                                  ['payment_status'] ??
                                              'pending',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildPriceRow(String label, dynamic price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Text(
          'Rp ${NumberFormat('#,###').format(price)}',
          style: TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'completed':
        color = Colors.green;
        label = 'Selesai';
        break;
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Batal';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
