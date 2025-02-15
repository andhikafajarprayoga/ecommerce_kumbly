import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';

class CompletedDeliveriesController extends GetxController {
  final RxList<Map<String, dynamic>> deliveries = <Map<String, dynamic>>[].obs;
  final RxDouble totalIncome = 0.0.obs;
  final RxInt selectedPaymentMethod = 0.obs; // 0 untuk semua metode
  final RxList<Map<String, dynamic>> paymentMethods =
      <Map<String, dynamic>>[].obs;

  void updateDeliveries(List<Map<String, dynamic>> newDeliveries) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      deliveries.value = newDeliveries;
      _calculateTotalIncome();
    });
  }

  void _calculateTotalIncome() {
    double total = 0;
    for (var delivery in deliveries) {
      if (delivery['status'] == 'completed' &&
          delivery['payment_method']?['id'] == 4) {
        // ID 1 untuk COD
        total += ((delivery['total_amount'] ?? 0) +
                (delivery['shipping_cost'] ?? 0) +
                (delivery['payment_method']?['admin'] ?? 0))
            .toDouble();
      }
    }
    totalIncome.value = total;
  }

  // Fungsi untuk mengelompokkan deliveries berdasarkan payment method
  Map<int, List<Map<String, dynamic>>> getGroupedDeliveries() {
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (var delivery in deliveries) {
      final methodId = delivery['payment_method']?['id'] ?? 0;
      if (!grouped.containsKey(methodId)) {
        grouped[methodId] = [];
      }
      grouped[methodId]!.add(delivery);
    }
    return grouped;
  }
}

class CompletedDeliveriesScreen extends StatefulWidget {
  @override
  _CompletedDeliveriesScreenState createState() =>
      _CompletedDeliveriesScreenState();
}

class _CompletedDeliveriesScreenState extends State<CompletedDeliveriesScreen> {
  final controller = Get.put(CompletedDeliveriesController());
  final supabase = Supabase.instance.client;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID');
    _fetchPaymentMethods();
  }

  Future<void> _fetchPaymentMethods() async {
    try {
      final response = await supabase.from('payment_methods').select();
      controller.paymentMethods.assignAll([
        {'id': 0, 'name': 'Semua Metode'},
        ...List<Map<String, dynamic>>.from(response),
      ]);
    } catch (e) {
      print('Error fetching payment methods: $e');
    }
  }

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

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: controller.paymentMethods.length,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final method = controller.paymentMethods[index];
          return Obx(() => Padding(
                padding: EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(method['name']),
                  selected:
                      controller.selectedPaymentMethod.value == method['id'],
                  onSelected: (selected) {
                    controller.selectedPaymentMethod.value = method['id'];
                    controller._calculateTotalIncome();
                  },
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.blue[100],
                ),
              ));
        },
      ),
    );
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
      body: Column(
        children: [
          // Total Income Card
          Obx(() => Card(
                margin: EdgeInsets.all(16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.payments_outlined, size: 24),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Total Pendapatan COD',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMMM yyyy').format(selectedDate),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  NumberFormat.currency(
                                    locale: 'id',
                                    symbol: 'Rp ',
                                    decimalDigits: 0,
                                  ).format(controller.totalIncome.value),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.blue,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.monetization_on_outlined,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Cash on Delivery',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),

          // Payment Method Filter
          _buildFilterChips(),

          // Deliveries List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Stream.periodic(const Duration(seconds: 3))
                  .asyncMap((_) async {
                final startOfDay = DateTime(
                    selectedDate.year, selectedDate.month, selectedDate.day);
                final endOfDay = startOfDay.add(Duration(days: 1));

                final response = await supabase
                    .from('orders')
                    .select('''
                      *,
                      buyer:users!buyer_id (
                        full_name,
                        phone
                      ),
                      payment_method:payment_methods (
                        id,
                        name,
                        account_number,
                        account_name,
                        admin
                      )
                    ''')
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

                controller.updateDeliveries(snapshot.data!);
                final groupedDeliveries = controller.getGroupedDeliveries();

                if (controller.deliveries.isEmpty) {
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
                  itemCount: groupedDeliveries.length,
                  itemBuilder: (context, index) {
                    final methodId = groupedDeliveries.keys.elementAt(index);
                    final methodDeliveries = groupedDeliveries[methodId]!;
                    final methodName = controller.paymentMethods.firstWhere(
                        (m) => m['id'] == methodId,
                        orElse: () => {'name': 'Unknown'})['name'];

                    if (controller.selectedPaymentMethod.value != 0 &&
                        methodId != controller.selectedPaymentMethod.value) {
                      return SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.payment, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                methodName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${methodDeliveries.length}',
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...methodDeliveries
                            .map((delivery) => _buildDeliveryCard(delivery))
                            .toList(),
                        Divider(thickness: 1),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
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
                _buildInfoRow(
                    'Produk',
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(delivery['total_amount'] ?? 0)),
                const Divider(),
                _buildInfoRow(
                    'Ongkir',
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(delivery['shipping_cost'] ?? 0)),
                const Divider(),
                _buildInfoRow(
                    'Admin Fee',
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(delivery['payment_method']?['admin'] ?? 0)),
                const Divider(),
                _buildInfoRow('Metode Pembayaran',
                    delivery['payment_method']?['name'] ?? 'N/A'),
                const Divider(),
                _buildInfoRow(
                    'Total',
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format((delivery['total_amount'] ?? 0) +
                        (delivery['shipping_cost'] ?? 0) +
                        (delivery['payment_method']?['admin'] ?? 0))),
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
