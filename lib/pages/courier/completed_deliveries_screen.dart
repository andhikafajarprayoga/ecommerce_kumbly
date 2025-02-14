import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class CompletedDeliveriesScreen extends StatefulWidget {
  @override
  _CompletedDeliveriesScreenState createState() =>
      _CompletedDeliveriesScreenState();
}

class _CompletedDeliveriesScreenState extends State<CompletedDeliveriesScreen> {
  final supabase = Supabase.instance.client;
  DateTime selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengiriman Selesai',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Stream.periodic(const Duration(seconds: 3)).asyncMap((_) async {
          final startOfDay =
              DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
          final endOfDay = startOfDay.add(Duration(days: 1));

          final response = await supabase
              .from('orders')
              .select()
              .eq('courier_id', supabase.auth.currentUser!.id)
              .eq('status', 'completed')
              .gte('created_at', startOfDay.toIso8601String())
              .lt('created_at', endOfDay.toIso8601String())
              .order('created_at', ascending: false);
          return List<Map<String, dynamic>>.from(response);
        }),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final deliveries = snapshot.data!;

          if (deliveries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada pengiriman yang selesai',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: deliveries.length,
            itemBuilder: (context, index) {
              final delivery = deliveries[index];
              return _buildDeliveryCard(delivery);
            },
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Menampilkan data tanggal: ${DateFormat('dd MMM yyyy').format(selectedDate)}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery) {
    final completedDateString = delivery['created_at'];
    if (completedDateString == null) {
      return const Center(child: Text('Tanggal tidak tersedia'));
    }

    final completedDate = DateTime.parse(completedDateString);
    final formattedDate = DateFormat('dd MMM yyyy').format(completedDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.check, color: Colors.white),
        ),
        title: Text(
          'Order #${delivery['id']?.toString().substring(0, 8) ?? 'Tidak ada ID'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Selesai pada: $formattedDate'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Status', 'Terkirim'),
                const Divider(),
                _buildInfoRow(
                    'Alamat Pengiriman', delivery['shipping_address'] ?? '-'),
                const Divider(),
                _buildInfoRow('Catatan', delivery['notes'] ?? '-'),
                if (delivery['proof_of_delivery'] != null) ...[
                  const Divider(),
                  const Text(
                    'Bukti Pengiriman:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Image.network(
                    delivery['proof_of_delivery'] ?? '',
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
