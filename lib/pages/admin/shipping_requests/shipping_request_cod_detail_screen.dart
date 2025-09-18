import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import 'shipping_request_cod_courier_detail_screen.dart';

class ShippingRequestCODDetailScreen extends StatefulWidget {
  @override
  State<ShippingRequestCODDetailScreen> createState() => _ShippingRequestCODDetailScreenState();
}

class _ShippingRequestCODDetailScreenState extends State<ShippingRequestCODDetailScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> codRequests = [];
  double totalAdminFee = 0;
  double totalCOD = 0;
  Map<String, double> courierCODTotals = {};
  Map<String, double> courierAdminFeeTotals = {};
  String searchText = '';
  String selectedPeriod = 'today'; // today, week, month, all, custom
  DateTime? customStartDate;
  DateTime? customEndDate;

  final Map<String, String> periodLabels = {
    'today': 'Hari Ini',
    'week': 'Minggu Ini',
    'month': 'Bulan Ini',
    'all': 'Semua',
    'custom': 'Custom'
  };

  @override
  void initState() {
    super.initState();
    fetchCODDetails();
  }

  Future<void> fetchCODDetails() async {
    setState(() => isLoading = true);
    try {
      // Date filter
      DateTime now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;
      switch (selectedPeriod) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'custom':
          startDate = customStartDate ?? DateTime(now.year, now.month, now.day);
          endDate = customEndDate ?? now;
          break;
        case 'all':
        default:
          startDate = DateTime(2020, 1, 1);
          break;
      }

      var query = supabase
          .from('shipping_requests')
          .select('id, courier_name, estimated_cost, admin_fee, payment_methods(name), updated_at')
          .eq('status', 'delivered');

      if (selectedPeriod != 'all') {
        query = query
            .gte('updated_at', startDate.toIso8601String())
            .lte('updated_at', endDate.add(Duration(days: 1)).toIso8601String());
      }

      final response = await query;

      List<Map<String, dynamic>> codList = [];
      double adminFeeSum = 0;
      double codSum = 0;
      Map<String, double> codPerCourier = {};
      Map<String, double> adminFeePerCourier = {};

      for (final req in response) {
        final payment = req['payment_methods']?['name']?.toString().toLowerCase() ?? '';
        if (payment == 'cod') {
          codList.add(req);
          adminFeeSum += (req['admin_fee'] ?? 0).toDouble();
          codSum += (req['estimated_cost'] ?? 0).toDouble();
          final courier = req['courier_name'] ?? '-';
          codPerCourier[courier] = (codPerCourier[courier] ?? 0) + (req['estimated_cost'] ?? 0).toDouble();
          adminFeePerCourier[courier] = (adminFeePerCourier[courier] ?? 0) + (req['admin_fee'] ?? 0).toDouble();
        }
      }

      setState(() {
        codRequests = codList;
        totalAdminFee = adminFeeSum;
        totalCOD = codSum;
        courierCODTotals = codPerCourier;
        courierAdminFeeTotals = adminFeePerCourier;
      });
    } catch (e) {
      setState(() {
        codRequests = [];
        totalAdminFee = 0;
        totalCOD = 0;
        courierCODTotals = {};
        courierAdminFeeTotals = {};
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
    // Filter courier list by searchText
    final filteredCouriers = courierCODTotals.keys
        .where((courier) => courier.toLowerCase().contains(searchText.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail COD', style: TextStyle(color: Colors.white)),
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
                  // Filter Periode
                  Container(
                    margin: EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.08),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range, color: AppTheme.primary, size: 18),
                        SizedBox(width: 8),
                        Text('Periode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: periodLabels.keys.map((period) {
                                final isSelected = selectedPeriod == period;
                                return GestureDetector(
                                  onTap: () async {
                                    if (period == 'custom') {
                                      final picked = await showDateRangePicker(
                                        context: context,
                                        firstDate: DateTime(2020, 1, 1),
                                        lastDate: DateTime.now(),
                                        initialDateRange: customStartDate != null && customEndDate != null
                                            ? DateTimeRange(start: customStartDate!, end: customEndDate!)
                                            : null,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          selectedPeriod = 'custom';
                                          customStartDate = picked.start;
                                          customEndDate = picked.end;
                                        });
                                        fetchCODDetails();
                                      }
                                    } else {
                                      setState(() {
                                        selectedPeriod = period;
                                        customStartDate = null;
                                        customEndDate = null;
                                      });
                                      fetchCODDetails();
                                    }
                                  },
                                  child: Container(
                                    margin: EdgeInsets.only(right: 8),
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primary : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      periodLabels[period]!,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.grey[700],
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedPeriod == 'custom' && customStartDate != null && customEndDate != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.primary, size: 15),
                          SizedBox(width: 6),
                          Text(
                            'Dari ${DateFormat('dd/MM/yyyy').format(customStartDate!)} '
                            'sampai ${DateFormat('dd/MM/yyyy').format(customEndDate!)}',
                            style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedPeriod = 'today';
                                customStartDate = null;
                                customEndDate = null;
                              });
                              fetchCODDetails();
                            },
                            child: Text('Reset', style: TextStyle(color: Colors.red, fontSize: 12)),
                          )
                        ],
                      ),
                    ),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Setoran COD di tangan semua kurir dari Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 2),
                          Text(formatCurrency(totalCOD), style: TextStyle(fontSize: 16, color: Colors.orange, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text('Total Admin Fee COD Aplikasi Semua Kurir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 2),
                          Text(formatCurrency(totalAdminFee), style: TextStyle(fontSize: 15, color: Colors.blue, fontWeight: FontWeight.bold)),
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
                  Text('Rekap Setoran COD per Kurir:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 6),
                  Expanded(
                    child: filteredCouriers.isEmpty
                        ? Center(child: Text('Tidak ada data kurir ditemukan.'))
                        : ListView.builder(
                            itemCount: filteredCouriers.length,
                            itemBuilder: (context, idx) {
                              final courier = filteredCouriers[idx];
                              final codTotal = courierCODTotals[courier] ?? 0;
                              final adminFeeTotal = courierAdminFeeTotals[courier] ?? 0;
                              return Card(
                                margin: EdgeInsets.only(bottom: 8),
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.orange.shade100,
                                    child: Icon(Icons.person, color: Colors.orange),
                                  ),
                                  title: Text('$courier'),
                                  trailing: Icon(Icons.chevron_right, color: Colors.orange),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ShippingRequestCODCourierDetailScreen(
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
