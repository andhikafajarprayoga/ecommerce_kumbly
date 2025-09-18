import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import 'shipping_request_detail_screen.dart';
import 'shipping_request_financial_summary_screen.dart';
import 'dart:convert';

class ShippingRequestsScreen extends StatefulWidget {
  @override
  _ShippingRequestsScreenState createState() => _ShippingRequestsScreenState();
}

class _ShippingRequestsScreenState extends State<ShippingRequestsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> shippingRequests = [];
  bool isLoading = true;
  String selectedStatus = 'all';
  final searchController = TextEditingController();

  final List<String> statusOptions = [
    'all',
    'pending',
    'waiting_verification',
    'confirmed',
    'picked_up',
    'in_transit',
    'out_for_delivery',
    'delivered',
    'cancelled'
  ];

  @override
  void initState() {
    super.initState();
    fetchShippingRequests();
  }

  Future<void> fetchShippingRequests() async {
    setState(() => isLoading = true);

    try {
      var query = supabase
          .from('shipping_requests')
          .select('''
            *,
            pengiriman!inner(nama_pengiriman),
            payment_methods!inner(name)
          ''');

      if (selectedStatus != 'all') {
        query = query.eq('status', selectedStatus);
      }

      List<Map<String, dynamic>> response = await query.order('created_at', ascending: false);

      setState(() {
        shippingRequests = response;
      });
    } catch (e) {
      print('Error fetching shipping requests: $e');
      Get.snackbar('Error', 'Gagal memuat data permintaan pengiriman');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> updateStatus(int requestId, String newStatus) async {
    try {
      await supabase
          .from('shipping_requests')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', requestId);

      Get.snackbar('Berhasil', 'Status berhasil diperbarui');
      fetchShippingRequests();
    } catch (e) {
      print('Error updating status: $e');
      Get.snackbar('Error', 'Gagal memperbarui status');
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
      if (address['village'] != null) parts.add(address['village']);
      if (address['district'] != null) parts.add(address['district']);
      if (address['city'] != null) parts.add(address['city']);
      
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

  String getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu';
      case 'waiting_verification':
        return 'Verifikasi';
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

  @override
  Widget build(BuildContext context) {
    // Group shippingRequests by date (created_at)
    Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    for (var req in shippingRequests) {
      String dateKey = DateFormat('yyyy-MM-dd').format(DateTime.parse(req['created_at']));
      groupedByDate.putIfAbsent(dateKey, () => []).add(req);
    }
    final sortedDateKeys = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // descending (terbaru di atas)

    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Kirim Barang', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.summarize, color: Colors.white),
            tooltip: 'Summary Keuangan',
            onPressed: () {
              Get.to(() => ShippingRequestFinancialSummaryScreen());
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchShippingRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter dan Search
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Status Filter
                Row(
                  children: [
                    Text('Filter Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedStatus,
                        isExpanded: true,
                        items: statusOptions.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status == 'all' ? 'Semua' : getStatusText(status)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedStatus = value!;
                          });
                          fetchShippingRequests();
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // Search
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari berdasarkan nama barang atau pengirim...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    // TODO: Implement search functionality
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1),
          
          // Content
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : shippingRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Tidak ada permintaan pengiriman', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: sortedDateKeys.length,
                        itemBuilder: (context, dateIdx) {
                          final dateKey = sortedDateKeys[dateIdx];
                          final requests = groupedByDate[dateKey]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8, top: 16),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
                                    SizedBox(width: 8),
                                    Text(
                                      DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.parse(dateKey)),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...requests.map((request) => _buildRequestCard(request)).toList(),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Get.to(() => ShippingRequestDetailScreen(request: request)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SR#${request['id'].toString().padLeft(6, '0')}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primary,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: getStatusColor(request['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: getStatusColor(request['status'])),
                    ),
                    child: Text(
                      getStatusText(request['status']),
                      style: TextStyle(
                        color: getStatusColor(request['status']),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              
              // Item Info
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request['item_name'],
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${request['weight']} kg',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 8),
              
              // Sender Info
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${request['sender_name']} → ${request['receiver_name']}',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              
              // Cost & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatCurrency(request['estimated_cost']),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(request['created_at'])),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              
              // Quick Actions
              if (request['status'] == 'pending' || request['status'] == 'waiting_verification')
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showStatusDialog(request),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Update Status', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Get.to(() => ShippingRequestDetailScreen(request: request)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Detail', style: TextStyle(color: Colors.black87)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusDialog(Map<String, dynamic> request) {
    Get.dialog(
      AlertDialog(
        title: Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statusOptions
              .where((status) => status != 'all')
              .map((status) => ListTile(
                    title: Text(getStatusText(status)),
                    onTap: () {
                      Get.back();
                      updateStatus(request['id'], status);
                    },
                  ))
              .toList(),
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
}