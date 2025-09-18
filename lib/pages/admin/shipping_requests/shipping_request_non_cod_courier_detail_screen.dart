import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';

class ShippingRequestNonCODCourierDetailScreen extends StatefulWidget {
  final String courierName;
  const ShippingRequestNonCODCourierDetailScreen({Key? key, required this.courierName}) : super(key: key);

  @override
  State<ShippingRequestNonCODCourierDetailScreen> createState() => _ShippingRequestNonCODCourierDetailScreenState();
}

class _ShippingRequestNonCODCourierDetailScreenState extends State<ShippingRequestNonCODCourierDetailScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> nonCodRequests = [];
  double totalNonCOD = 0;
  double totalAdminFee = 0;
  String selectedPeriod = 'today'; // today, week, month, all, custom
  DateTime? customStartDate;
  DateTime? customEndDate;
  int courierCodFee = 2000; // default, akan diambil dari DB

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
    fetchCourierCodFeeAndDetails();
  }

  Future<void> fetchCourierCodFeeAndDetails() async {
    await fetchCourierCodFee();
    await fetchNonCODDetails();
  }

  Future<void> fetchCourierCodFee() async {
    try {
      final res = await supabase
          .from('admin_settings')
          .select('courier_cod_fee')
          .limit(1)
          .maybeSingle();
      if (res != null && res['courier_cod_fee'] != null) {
        setState(() {
          courierCodFee = int.tryParse(res['courier_cod_fee'].toString()) ?? 2000;
        });
      }
    } catch (e) {
      courierCodFee = 2000;
    }
  }

  Future<void> fetchNonCODDetails() async {
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
          .select('id, estimated_cost, admin_fee, payment_methods(name), created_at, updated_at')
          .not('status', 'eq', 'cancelled')
          .eq('courier_name', widget.courierName);

      if (selectedPeriod != 'all') {
        query = query
            .gte('updated_at', startDate.toIso8601String())
            .lte('updated_at', endDate.add(Duration(days: 1)).toIso8601String());
      }

      final response = await query;

      List<Map<String, dynamic>> nonCodList = [];
      double nonCodSum = 0;
      double adminFeeSum = 0;

      for (final req in response) {
        final payment = req['payment_methods']?['name']?.toString().toLowerCase() ?? '';
        if (payment != 'cod') {
          nonCodList.add(req);
          nonCodSum += (req['estimated_cost'] ?? 0).toDouble();
          adminFeeSum += (req['admin_fee'] ?? 0).toDouble();
        }
      }

      setState(() {
        nonCodRequests = nonCodList;
        totalNonCOD = nonCodSum;
        totalAdminFee = adminFeeSum;
      });
    } catch (e) {
      setState(() {
        nonCodRequests = [];
        totalNonCOD = 0;
        totalAdminFee = 0;
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
    final int paketCount = nonCodRequests.length;
    final double adminFeecourierSummary = paketCount * courierCodFee.toDouble();
    final double totalUangKeKurir = totalNonCOD - totalAdminFee - adminFeecourierSummary;

    // Group nonCodRequests by date (created_at/updated_at)
    Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    for (var req in nonCodRequests) {
      String? dateStr;
      if (req['updated_at'] != null && req['updated_at'].toString().isNotEmpty) {
        dateStr = req['updated_at'];
      } else if (req['created_at'] != null && req['created_at'].toString().isNotEmpty) {
        dateStr = req['created_at'];
      }
      if (dateStr != null) {
        try {
          final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.parse(dateStr));
          groupedByDate.putIfAbsent(dateKey, () => []).add(req);
        } catch (_) {}
      }
    }
    final sortedDateKeys = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // descending

    return Scaffold(
      appBar: AppBar(
        title: Text('Non-COD: ${widget.courierName}', style: TextStyle(color: Colors.white)),
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
                                        fetchNonCODDetails();
                                      }
                                    } else {
                                      setState(() {
                                        selectedPeriod = period;
                                        customStartDate = null;
                                        customEndDate = null;
                                      });
                                      fetchNonCODDetails();
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
                              fetchNonCODDetails();
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
                          Text('Total Non-COD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 2),
                          Text(formatCurrency(totalNonCOD), style: TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text('Total Admin Fee Non-COD ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 2),
                          Text(formatCurrency(totalAdminFee), style: TextStyle(fontSize: 15, color: Colors.orange, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                            Text('Total uang yang harus dikirim ke ${widget.courierName}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 2),
                          Text(formatCurrency(totalUangKeKurir), style: TextStyle(fontSize: 15, color: Colors.green, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Divider(),
                          Row(
                            children: [
                              Icon(Icons.summarize, color: Colors.orange, size: 18),
                              SizedBox(width: 6),
                              Text('Admin Fee Kurir ($courierCodFee x $paketCount ): ',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              SizedBox(width: 6),
                              Text(formatCurrency(adminFeecourierSummary),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 0, 0, 0))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text('Daftar Pengiriman Non-COD:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 6),
                  Expanded(
                    child: nonCodRequests.isEmpty
                        ? Center(child: Text('Tidak ada data Non-COD'))
                        : ListView.builder(
                            itemCount: sortedDateKeys.length,
                            itemBuilder: (context, dateIdx) {
                              final dateKey = sortedDateKeys[dateIdx];
                              final requests = groupedByDate[dateKey]!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6, top: 10),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 15, color: AppTheme.primary),
                                        SizedBox(width: 6),
                                        Text(
                                          DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.parse(dateKey)),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...requests.map((req) => Card(
                                    margin: EdgeInsets.only(bottom: 8),
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.blue.shade100,
                                        child: Icon(Icons.credit_card, color: Colors.blue),
                                      ),
                                      title: Text('SR#${req['id'].toString().padLeft(6, '0')}'),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Biaya: ${formatCurrency(req['estimated_cost'] ?? 0)}'),
                                          Text('Metode: ${req['payment_methods']?['name'] ?? '-'}'),
                                          Text('Admin Fee: ${formatCurrency(req['admin_fee'] ?? 0)}'),
                                        ],
                                      ),
                                    ),
                                  )),
                                ],
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

