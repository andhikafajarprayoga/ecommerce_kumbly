import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import 'shipping_request_non_cod_courier_detail_screen.dart';

class ShippingRequestNonCODDetailScreen extends StatefulWidget {
  @override
  State<ShippingRequestNonCODDetailScreen> createState() => _ShippingRequestNonCODDetailScreenState();
}

class _ShippingRequestNonCODDetailScreenState extends State<ShippingRequestNonCODDetailScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> nonCodRequests = [];
  double totalNonCOD = 0;
  double totalAdminFee = 0;
  Map<String, double> courierNonCODTotals = {};
  String searchText = '';

  @override
  void initState() {
    super.initState();
    fetchNonCODDetails();
  }

  Future<void> fetchNonCODDetails() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('shipping_requests')
          .select('id, courier_name, estimated_cost, admin_fee, payment_methods(name), created_at, updated_at')
          .not('status', 'eq', 'cancelled');

      List<Map<String, dynamic>> nonCodList = [];
      double nonCodSum = 0;
      double adminFeeSum = 0;
      Map<String, double> nonCodPerCourier = {};

      for (final req in response) {
        final payment = req['payment_methods']?['name']?.toString().toLowerCase() ?? '';
        if (payment != 'cod') {
          nonCodList.add(req);
          nonCodSum += (req['estimated_cost'] ?? 0).toDouble();
          adminFeeSum += (req['admin_fee'] ?? 0).toDouble();
          final courier = req['courier_name'] ?? '-';
          nonCodPerCourier[courier] = (nonCodPerCourier[courier] ?? 0) + (req['estimated_cost'] ?? 0).toDouble();
        }
      }

      setState(() {
        nonCodRequests = nonCodList;
        totalNonCOD = nonCodSum;
        totalAdminFee = adminFeeSum;
        courierNonCODTotals = nonCodPerCourier;
      });
    } catch (e) {
      setState(() {
        nonCodRequests = [];
        totalNonCOD = 0;
        totalAdminFee = 0;
        courierNonCODTotals = {};
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  String formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final couriers = courierNonCODTotals.keys
        .where((courier) => courier.toLowerCase().contains(searchText.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Non-COD', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total uang yang di Non-COD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 2),
                          Text(formatCurrency(totalNonCOD), style: TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text('Total Admin Fee Non-COD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 2),
                          Text(formatCurrency(totalAdminFee), style: TextStyle(fontSize: 15, color: Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  // Search field
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama kurir...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchText = value;
                      });
                    },
                  ),
                  SizedBox(height: 10),
                  Text('Daftar Pengiriman Non-COD per Kurir:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 6),
                  Expanded(
                    child: couriers.isEmpty
                        ? Center(child: Text('Tidak ada nama kurir sesuai pencariand'))
                        : ListView.builder(
                            itemCount: couriers.length,
                            itemBuilder: (context, idx) {
                              final courier = couriers[idx];
                              final nonCodTotal = courierNonCODTotals[courier] ?? 0;
                              return Card(
                                margin: EdgeInsets.only(bottom: 8),
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: Icon(Icons.person, color: Colors.blue),
                                  ),
                                  title: Text('$courier'),
                                  subtitle: Text('Total Non-COD: ${formatCurrency(nonCodTotal)}'),
                                  trailing: Icon(Icons.chevron_right, color: Colors.blue),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ShippingRequestNonCODCourierDetailScreen(
                                          courierName: courier,
                                        ),
                                      ),
                                    );
                                  },
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
}
