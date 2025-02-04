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
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await supabase.from('order_cancellations').select('''
            *,
            order:orders (
              id,
              total_amount,
              shipping_address,
              order_items (
                quantity,
                price,
                product:products (
                  name
                )
              )
            ),
            requester:auth_users (
              email
            )
          ''').eq('status', 'pending').order('requested_at', ascending: false);

      cancellationRequests.value = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching cancellation requests: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _processRequest(
      String requestId, String status, String notes) async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      await supabase.from('order_cancellations').update({
        'status': status,
        'processed_by': currentUserId,
        'processed_at': DateTime.now().toIso8601String(),
        'notes': notes
      }).eq('id', requestId);

      if (status == 'approved') {
        // Update order status jika pembatalan disetujui
        final request =
            cancellationRequests.firstWhere((req) => req['id'] == requestId);
        await supabase
            .from('orders')
            .update({'status': 'cancelled'}).eq('id', request['order_id']);
      }

      Get.snackbar(
        'Sukses',
        'Permintaan pembatalan telah ${status == 'approved' ? 'disetujui' : 'ditolak'}',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      _fetchCancellationRequests();
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

  void _showProcessDialog(Map<String, dynamic> request) {
    final notesController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Proses Permintaan Pembatalan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Catatan (opsional):'),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                hintText: 'Masukkan catatan...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _processRequest(request['id'], 'rejected', notesController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tolak'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _processRequest(request['id'], 'approved', notesController.text);
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
                    subtitle: Text(
                      'Diminta oleh: ${requester['email']}\n'
                      'Tanggal: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(request['requested_at']))}',
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
                            onPressed: () =>
                                _processRequest(request['id'], 'rejected', ''),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Tolak'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _showProcessDialog(request),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
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
          },
        );
      }),
    );
  }
}
