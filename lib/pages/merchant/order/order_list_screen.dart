import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class OrderListScreen extends StatefulWidget {
  final String sellerId;

  const OrderListScreen({Key? key, required this.sellerId}) : super(key: key);

  @override
  _OrderListScreenState createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final supabase = Supabase.instance.client;
  final orders = <Map<String, dynamic>>[].obs;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final response = await supabase
          .from('orders')
          .select('*')
          .eq('merchant_id', widget.sellerId)
          .order('created_at', ascending: false);

      orders.value = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching orders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Pesanan'),
      ),
      body: Obx(() => ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title:
                      Text('Order #${order['id'].toString().substring(0, 8)}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: ${order['status']}'),
                      Text('Total: Rp${order['total_amount']}'),
                      Text('Tanggal: ${order['created_at']}'),
                    ],
                  ),
                  trailing: Icon(_getStatusIcon(order['status'])),
                  onTap: () {
                    // TODO: Navigate to order detail
                  },
                ),
              );
            },
          )),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
      case 'processing':
      case 'shipping':
        return Icons.local_shipping;
      case 'cancelled':
        return Icons.cancel;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }
}
