import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import 'shipping_request_cod_detail_screen.dart';
import 'shipping_request_non_cod_detail_screen.dart';

class ShippingRequestFinancialSummaryScreen extends StatefulWidget {
  @override
  State<ShippingRequestFinancialSummaryScreen> createState() => _ShippingRequestFinancialSummaryScreenState();
}

class _ShippingRequestFinancialSummaryScreenState extends State<ShippingRequestFinancialSummaryScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  double totalAll = 0;
  double totalCOD = 0;
  double totalNonCOD = 0;
  int countAll = 0;
  int countCOD = 0;
  int countNonCOD = 0;

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
    fetchSummary();
  }

  Future<void> fetchSummary() async {
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
          .select('*, payment_methods(name)')
          .not('status', 'eq', 'cancelled');

      if (selectedPeriod != 'all') {
        query = query
            .gte('updated_at', startDate.toIso8601String())
            .lte('updated_at', endDate.add(Duration(days: 1)).toIso8601String());
      }

      final response = await query;

      double sumAll = 0;
      double sumCOD = 0;
      double sumNonCOD = 0;
      int cntAll = 0;
      int cntCOD = 0;
      int cntNonCOD = 0;

      for (final req in response) {
        final cost = (req['estimated_cost'] ?? 0).toDouble();
        sumAll += cost;
        cntAll++;
        final payment = req['payment_methods']?['name']?.toString().toLowerCase() ?? '';
        if (payment == 'cod') {
          sumCOD += cost;
          cntCOD++;
        } else {
          sumNonCOD += cost;
          cntNonCOD++;
        }
      }

      setState(() {
        totalAll = sumAll;
        totalCOD = sumCOD;
        totalNonCOD = sumNonCOD;
        countAll = cntAll;
        countCOD = cntCOD;
        countNonCOD = cntNonCOD;
      });
    } catch (e) {
      setState(() {
        totalAll = 0;
        totalCOD = 0;
        totalNonCOD = 0;
        countAll = 0;
        countCOD = 0;
        countNonCOD = 0;
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Summary Keuangan', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
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
                                        fetchSummary();
                                      }
                                    } else {
                                      setState(() {
                                        selectedPeriod = period;
                                        customStartDate = null;
                                        customEndDate = null;
                                      });
                                      fetchSummary();
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
                              fetchSummary();
                            },
                            child: Text('Reset', style: TextStyle(color: Colors.red, fontSize: 12)),
                          )
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(Icons.all_inbox, color: AppTheme.primary, size: 28),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Total Semua Pengiriman Ready', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      SizedBox(height: 2),
                                      Text(formatCurrency(totalAll), style: TextStyle(fontSize: 16, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                      Text('$countAll pengiriman', style: TextStyle(color: Colors.grey[700], fontSize: 11)),
                                      SizedBox(height: 6),
                                      Text(
                                        'Termasuk semua status kecuali "cancelled".',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ShippingRequestCODDetailScreen(),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(Icons.payments, color: Colors.orange, size: 26),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Total COD', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)),
                                        SizedBox(height: 2),
                                        Text(formatCurrency(totalCOD), style: TextStyle(fontSize: 15, color: Colors.orange, fontWeight: FontWeight.bold)),
                                        Text('$countCOD pengiriman COD', style: TextStyle(color: Colors.grey[700], fontSize: 11)),
                                        SizedBox(height: 6),
                                        Text(
                                          'Hanya status "delivered" dengan metode pembayaran COD.',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: Colors.orange),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ShippingRequestNonCODDetailScreen(),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(Icons.credit_card, color: Colors.blue, size: 26),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Total Non-COD', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                                        SizedBox(height: 2),
                                        Text(formatCurrency(totalNonCOD), style: TextStyle(fontSize: 15, color: Colors.blue, fontWeight: FontWeight.bold)),
                                        Text('$countNonCOD pengiriman Non-COD', style: TextStyle(color: Colors.grey[700], fontSize: 11)),
                                        SizedBox(height: 6),
                                        Text(
                                          'Hanya status "delivered" dengan metode pembayaran selain COD.',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: Colors.blue),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
