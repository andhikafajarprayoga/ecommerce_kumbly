import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class CancellationRequestsScreen extends StatefulWidget {
  const CancellationRequestsScreen({Key? key}) : super(key: key);

  @override
  _CancellationRequestsScreenState createState() =>
      _CancellationRequestsScreenState();
}

class _CancellationRequestsScreenState
    extends State<CancellationRequestsScreen> {
  final supabase = Supabase.instance.client;
  final cancellationRequests = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _fetchCancellationRequests();
  }

  Future<void> _fetchCancellationRequests() async {
    try {
      isLoading.value = true;

      final response = await supabase.from('order_cancellations').select('''
            id,
            status,
            requested_at,
            processed_at,
            notes,
            reason,
            requested_by,
            processed_by,
            order:orders (
              id,
              total_amount,
              shipping_address,
              order_items (
                quantity,
                price,
                product:products (
                  name,
                  image_url
                )
              )
            )
          ''').eq('status', 'pending').order('requested_at', ascending: false);

      print('Debug response: $response');

      // Fetch user details separately
      if (response != null) {
        final List<Map<String, dynamic>> requests =
            List<Map<String, dynamic>>.from(response);

        for (var request in requests) {
          // Get requester details
          if (request['requested_by'] != null) {
            final requesterResponse = await supabase
                .from('users')
                .select('id, email, full_name')
                .eq('id', request['requested_by'])
                .single();
            request['requester'] = requesterResponse;
          }

          // Get processor details
          if (request['processed_by'] != null) {
            final processorResponse = await supabase
                .from('users')
                .select('id, email, full_name')
                .eq('id', request['processed_by'])
                .single();
            request['processor'] = processorResponse;
          }
        }

        cancellationRequests.value = requests;
      }
    } catch (e) {
      print('Error fetching cancellation requests: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _processRequest(String requestId, String status) async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Ambil data request terlebih dahulu
      final cancellationData = await supabase
          .from('order_cancellations')
          .select('order_id, reason')
          .eq('id', requestId)
          .single();

      if (cancellationData == null) {
        throw Exception('Cancellation request not found');
      }

      // 1. Update order status terlebih dahulu
      final orderId = cancellationData['order_id'];
      final newOrderStatus = status == 'approved' ? 'cancelled' : 'pending';

      await supabase.from('orders').update({
        'status': newOrderStatus,
      }).eq('id', orderId);

      // 2. Update cancellation request
      await supabase.from('order_cancellations').update({
        'status': status,
        'processed_by': currentUserId,
        'processed_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      Get.snackbar(
        'Sukses',
        'Permintaan pembatalan telah ${status == 'approved' ? 'disetujui' : 'ditolak'}',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      await _fetchCancellationRequests();
    } catch (e) {
      print('Error processing cancellation request: $e');
      Get.snackbar(
        'Error',
        'Gagal memproses permintaan pembatalan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showConfirmationDialog(Map<String, dynamic> request) {
    Get.dialog(
      AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Pilih tindakan untuk permintaan pembatalan ini'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _processRequest(request['id'], 'rejected');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tolak'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _processRequest(request['id'], 'approved');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permintaan Pembatalan'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        if (isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (cancellationRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel_outlined, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada permintaan pembatalan',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cancellationRequests.length,
          itemBuilder: (context, index) {
            final request = cancellationRequests[index];
            print('Debug request $index: $request');
            return _buildRequestCard(request);
          },
        );
      }),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final order = request['order'];
    final requester = request['requester'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              'Order #${order['id'].toString().substring(0, 8)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Diminta oleh: ${requester['full_name'] ?? requester['email']}'),
                Text(
                    'Tanggal: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(request['requested_at']))}'),
                if (request['reason']?.isNotEmpty ?? false)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alasan Pembatalan:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request['reason'] ?? '-',
                          style: TextStyle(color: Colors.grey[800]),
                        ),
                      ],
                    ),
                  ),
                if (request['processed_at'] != null) ...[
                  Text(
                      'Diproses oleh: ${request['processor']?['full_name'] ?? request['processor']?['email'] ?? '-'}'),
                  Text(
                      'Tanggal proses: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(request['processed_at']))}'),
                ],
              ],
            ),
            trailing: Text(
              'Rp ${NumberFormat('#,###').format(order['total_amount'])}',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showConfirmationDialog(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                    ),
                    child: const Text('Proses'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
