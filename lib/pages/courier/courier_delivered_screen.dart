import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import 'dart:convert';

class CourierDeliveredScreen extends StatefulWidget {
  @override
  _CourierDeliveredScreenState createState() => _CourierDeliveredScreenState();
}

class _CourierDeliveredScreenState extends State<CourierDeliveredScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> deliveredPackages = [];
  Map<String, List<Map<String, dynamic>>> groupedPackages = {};
  bool isLoading = true;
  double totalCODAmount = 0.0;
  int totalCODPackages = 0;
  double totalAdminFee = 0.0;
  int courierCodFee = 2000; // default, akan diambil dari DB
  String courierName = '';
  String selectedPeriod = 'today'; // today, week, month, all, custom
  DateTime selectedDate = DateTime.now();
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
    fetchCourierCodFeeAndPackages();
  }

  Future<void> fetchCourierCodFeeAndPackages() async {
    await fetchCourierCodFee();
    await fetchDeliveredPackages();
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

  Future<void> fetchDeliveredPackages() async {
    setState(() => isLoading = true);
    try {
      // Ambil nama kurir dari auth user
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userResponse = await supabase
          .from('users')
          .select('full_name')
          .eq('id', user.id)
          .single();

      courierName = userResponse['full_name'];

      // Calculate date range based on selected period
      DateTime startDate;
      DateTime endDate = DateTime.now();

      switch (selectedPeriod) {
        case 'today':
          startDate = DateTime(endDate.year, endDate.month, endDate.day);
          break;
        case 'week':
          startDate = endDate.subtract(Duration(days: endDate.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'month':
          startDate = DateTime(endDate.year, endDate.month, 1);
          break;
        case 'custom':
          startDate = customStartDate ?? DateTime(endDate.year, endDate.month, endDate.day);
          endDate = customEndDate ?? endDate;
          break;
        case 'all':
        default:
          startDate = DateTime(2020, 1, 1); // Very old date to include all
          break;
      }

      // Ambil paket yang sudah delivered oleh kurir ini dalam periode yang dipilih
      var query = supabase
          .from('shipping_requests')
          .select('''
            *,
            pengiriman(nama_pengiriman),
            payment_methods(name)
          ''')
          .eq('courier_name', courierName)
          .eq('status', 'delivered')
          .gte('updated_at', startDate.toIso8601String())
          .lte('updated_at', endDate.add(Duration(days: 1)).toIso8601String())
          .order('updated_at', ascending: false);

      final response = await query;

      setState(() {
        deliveredPackages = List<Map<String, dynamic>>.from(response);
        _groupPackagesByDate();
        _calculateCODTotal();
      });
    } catch (e) {
      print('Error fetching delivered packages: $e');
      Get.snackbar('Error', 'Gagal memuat data paket terkirim');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _groupPackagesByDate() {
    groupedPackages = {};
    
    for (var package in deliveredPackages) {
      String updatedAt = package['updated_at'] ?? package['created_at'];
      DateTime date = DateTime.parse(updatedAt);
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      
      if (!groupedPackages.containsKey(dateKey)) {
        groupedPackages[dateKey] = [];
      }
      groupedPackages[dateKey]!.add(package);
    }
  }

  void _calculateCODTotal() {
    totalCODAmount = 0.0;
    totalCODPackages = 0;
    totalAdminFee = 0.0; // <-- Reset di sini

    for (var package in deliveredPackages) {
      final paymentMethodName = package['payment_methods']?['name']?.toString().toLowerCase() ?? '';
      if (paymentMethodName == 'cod') {
        totalCODAmount += (package['estimated_cost'] ?? 0.0);
        totalCODPackages++;
      }
      totalAdminFee += (package['admin_fee'] ?? 0.0); // <-- Akumulasi admin_fee
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

  bool isCODPayment(Map<String, dynamic> package) {
    final paymentMethodName = package['payment_methods']?['name']?.toString().toLowerCase() ?? '';
    return paymentMethodName == 'cod';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Paket Terkirim', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchDeliveredPackages,
          ),
        ],
      ),
      body: Column(
        children: [
          // Period Filter
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.date_range, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Periode:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(width: 12),
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
                                fetchDeliveredPackages();
                              }
                            } else {
                              setState(() {
                                selectedPeriod = period;
                                customStartDate = null;
                                customEndDate = null;
                              });
                              fetchDeliveredPackages();
                            }
                          },
                          child: Container(
                            margin: EdgeInsets.only(right: 8),
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.green : Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              periodLabels[period]!,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[700],
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Dari ${DateFormat('dd/MM/yyyy').format(customStartDate!)} '
                    'sampai ${DateFormat('dd/MM/yyyy').format(customEndDate!)}',
                    style: TextStyle(color: Colors.green.shade800, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedPeriod = 'today';
                        customStartDate = null;
                        customEndDate = null;
                      });
                      fetchDeliveredPackages();
                    },
                    child: Text('Reset', style: TextStyle(color: Colors.red)),
                  )
                ],
              ),
            ),

          // COD Summary Card
            Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
              colors: [Colors.green.shade600, Colors.green.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                Icon(Icons.account_balance_wallet, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  'Uang COD - ${periodLabels[selectedPeriod]}',
                  style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  ),
                ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Total COD:',
                style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                ),
              ),
              SizedBox(height: 2),
              Text(
                formatCurrency(totalCODAmount),
                style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                Icon(Icons.monetization_on, color: Colors.yellow[200], size: 14),
                SizedBox(width: 2),
                Text(
                  'Admin Kurir:',
                  style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  formatCurrency(totalCODPackages * courierCodFee),
                  style: TextStyle(
                  color: Colors.yellow[100],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  ),
                ),
                ],
              ),
              SizedBox(height: 2),
              Row(
                children: [
                Icon(Icons.receipt_long, color: Colors.blue[100], size: 14),
                SizedBox(width: 2),
                Text(
                  'Admin Aplikasi COD Pengiriman:',
                  style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  formatCurrency(totalAdminFee),
                  style: TextStyle(
                  color: Colors.blue[50],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  ),
                ),
                ],
              ),
              SizedBox(height: 2),
              Row(
                children: [
                Icon(Icons.summarize, color: Colors.white, size: 14),
                SizedBox(width: 2),
                Text(
                  'Total Setoran:',
                  style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  formatCurrency((totalCODPackages * courierCodFee) + totalAdminFee),
                  style: TextStyle(
                  color: Colors.purple[50],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  ),
                ),
                ],
              ),
              SizedBox(height: 2),
              Row(
                children: [
                Icon(Icons.local_shipping, color: Colors.white70, size: 12),
                SizedBox(width: 2),
                Text(
                  '$totalCODPackages paket COD dari ${deliveredPackages.length} total terkirim',
                  style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  ),
                ),
                ],
              ),
              ],
            ),
            ),

          // Package List by Date
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : deliveredPackages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Belum ada paket terkirim ${periodLabels[selectedPeriod]?.toLowerCase()}', 
                                 style: TextStyle(color: Colors.grey)),
                            SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: fetchDeliveredPackages,
                              child: Text('Refresh'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchDeliveredPackages,
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: groupedPackages.keys.length,
                          itemBuilder: (context, index) {
                            String dateKey = groupedPackages.keys.elementAt(index);
                            List<Map<String, dynamic>> packagesForDate = groupedPackages[dateKey]!;
                            return _buildDateSection(dateKey, packagesForDate);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection(String dateKey, List<Map<String, dynamic>> packages) {
    DateTime date = DateTime.parse(dateKey);
    String displayDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
    
    // Calculate COD amount for this date
    double dateCODAmount = 0.0;
    int dateCODCount = 0;
    for (var package in packages) {
      if (isCODPayment(package)) {
        dateCODAmount += (package['estimated_cost'] ?? 0.0);
        dateCODCount++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Header
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: 16, bottom: 8),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayDate,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${packages.length} paket',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (dateCODCount > 0) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.money, color: Colors.orange, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'COD: ${formatCurrency(dateCODAmount)} ($dateCODCount paket)',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        // Packages for this date
        ...packages.map((package) => _buildPackageCard(package)).toList(),
      ],
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> package) {
    final bool isCOD = isCODPayment(package);
    // Tambahkan state untuk expand/collapse per paket
    return StatefulBuilder(
      builder: (context, setState) {
        bool isExpanded = package['isExpanded'] ?? false;

        // Widget ringkasan jika collapsed
        Widget collapsedCard = Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                package['isExpanded'] = true;
              });
            },
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: isCOD
                    ? Border.all(color: Colors.orange, width: 2)
                    : null,
                color: isCOD ? Colors.orange.shade50 : Colors.grey[50],
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SR#${package['id'].toString().padLeft(6, '0')}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCurrency(package['estimated_cost']),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCOD ? Colors.orange : AppTheme.primary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Text(
                          'TERKIRIM',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          ),
        );

        // Widget detail jika expanded
        Widget expandedCard = Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isCOD
                  ? Border.all(color: Colors.orange, width: 2)
                  : null,
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with COD indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'SR#${package['id'].toString().padLeft(6, '0')}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (isCOD) ...[
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Text(
                                'COD',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                          ],
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Text(
                              'TERKIRIM',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.expand_less, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                package['isExpanded'] = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Package Info
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCOD ? Colors.orange.shade50 : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[600]),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                package['item_name'],
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                            ),
                            Text(
                              '${package['weight']} kg',
                              style: TextStyle(
                                color: isCOD ? Colors.orange : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Jenis: ${package['item_type']}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),

                  // Delivery Info
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${package['sender_name']} → ${package['receiver_name']}',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Address
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ke: ${parseAddress(package['receiver_address'])}',
                          style: TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Payment & Date Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCOD ? 'Uang Diterima (COD)' : 'Biaya Pengiriman',
                            style: TextStyle(
                              fontSize: 12,
                              color: isCOD ? Colors.orange : Colors.grey[600],
                              fontWeight: isCOD ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          Text(
                            formatCurrency(package['estimated_cost']),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isCOD ? Colors.orange : AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Terkirim:',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy').format(DateTime.parse(package['updated_at'] ?? package['created_at'])),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Payment Method Info
                  if (package['payment_methods'] != null) ...[
                    SizedBox(height: 8),
                    Divider(),
                    Row(
                      children: [
                        Icon(Icons.payment, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Text(
                          'Metode: ${package['payment_methods']['name']}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        return isExpanded ? expandedCard : collapsedCard;
      },
    );
  }
  }
