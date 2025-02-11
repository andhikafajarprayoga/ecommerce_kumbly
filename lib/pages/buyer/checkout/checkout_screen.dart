import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/cart_controller.dart';
import 'package:kumbly_ecommerce/controllers/order_controller.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../checkout/edit_address_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kumbly_ecommerce/pages/buyer/payment/payment_screen.dart';
import 'package:kumbly_ecommerce/pages/buyer/chat/chat_detail_screen.dart';
import 'dart:convert';
import 'dart:math' show cos, sqrt, asin, pi;
import 'dart:math' show sin;

class CheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  CheckoutScreen({required this.data}); // Menerima data dari CartScreen

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? paymentMethod;
  final OrderController orderController = Get.put(OrderController());
  final CartController cartController = Get.put(CartController());
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> paymentMethods = [];
  bool isLoadingPayments = false;
  double adminFee = 0;
  double shippingCost = 0;
  String? selectedDistrict;
  String? shippingType;
  List<Map<String, dynamic>> shippingRates = [];
  Map<String, dynamic>? specialRate; // Untuk menyimpan tarif khusus
  bool isLoadingRates = false;
  Map<String, double> merchantShippingCosts = {};
  final TextEditingController _voucherController = TextEditingController();
  Map<String, dynamic>?
      discountVoucher; // Tambahkan variabel untuk menyimpan data voucher diskon
  double discountAmount = 0; // Tambahkan variabel untuk menyimpan jumlah diskon
  List<Map<String, dynamic>> availableDiscountVouchers = [];
  bool isLoadingVouchers = false;
  List<Map<String, dynamic>> userAddresses = [];
  String? selectedAddress;
  bool isLoadingAddresses = false;
  Map<String, String> merchantShippingTypes = {};
  Map<String, double> merchantDistances = {};
  Map<String, dynamic>? selectedShippingMethod;
  List<Map<String, dynamic>> shippingMethods = [];
  List<Map<String, dynamic>> voucherList = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
    fetchVouchers();
    print('InitState called'); // Debug print
  }

  Future<void> _initializeData() async {
    if (mounted) {
      await fetchPaymentMethods();
      await fetchShippingMethods();
      await fetchAvailableVouchers();
      await fetchUserAddresses();
    }
  }

  Future<void> fetchPaymentMethods() async {
    setState(() => isLoadingPayments = true);
    try {
      final response =
          await supabase.from('payment_methods').select().eq('is_active', true);
      setState(() {
        paymentMethods = List<Map<String, dynamic>>.from(response);
        if (paymentMethods.isNotEmpty) {
          paymentMethod = paymentMethods[0]['id'].toString();
          adminFee = double.parse(paymentMethods[0]['admin'].toString());
        }
      });
    } catch (e) {
      print('Error fetching payment methods: $e');
    }
    setState(() => isLoadingPayments = false);
  }

  Future<void> fetchShippingMethods() async {
    try {
      print('\n=== DEBUG PENGIRIMAN ===');
      print('1. Mencoba mengambil data...');

      final response = await supabase
          .from('pengiriman')
          .select('id_pengiriman, nama_pengiriman, harga_per_kg, harga_per_km');

      print('2. Raw response:');
      print(response);

      setState(() {
        shippingMethods = List<Map<String, dynamic>>.from(response);
        print('3. Data yang tersimpan:');
        shippingMethods.forEach((method) {
          print('- ID: ${method['id_pengiriman']}');
          print('  Nama: ${method['nama_pengiriman']}');
          print('  Harga/KG: ${method['harga_per_kg']}');
          print('  Harga/KM: ${method['harga_per_km']}');
        });
      });
    } catch (e) {
      print('ERROR: $e');
    }
  }

  Future<void> fetchShippingRates() async {
    setState(() => isLoadingRates = true);
    try {
      final response = await supabase.from('shipping_rates').select().filter(
              'type', 'in', ['within', 'between']) // Hanya ambil tarif regular
          .order('type');

      setState(() {
        shippingRates = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching shipping rates: $e');
    }
    setState(() => isLoadingRates = false);
  }

  Future<void> fetchAvailableVouchers() async {
    setState(() => isLoadingVouchers = true);
    try {
      final response = await supabase
          .from('discount_vouchers')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        availableDiscountVouchers = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching vouchers: $e');
    }
    setState(() => isLoadingVouchers = false);
  }

  Future<void> fetchUserAddresses() async {
    setState(() => isLoadingAddresses = true);
    try {
      final response = await supabase
          .from('users')
          .select('address, address2, address3, address4')
          .eq('id', supabase.auth.currentUser!.id)
          .single();

      setState(() {
        userAddresses = [];
        if (response['address'] != null) userAddresses.add(response['address']);
        if (response['address2'] != null)
          userAddresses.add(response['address2']);
        if (response['address3'] != null)
          userAddresses.add(response['address3']);
        if (response['address4'] != null)
          userAddresses.add(response['address4']);

        // Set alamat default jika ada
        if (userAddresses.isNotEmpty) {
          // Pastikan alamat pertama diformat dengan benar
          final firstAddress = Map<String, dynamic>.from(userAddresses[0]);
          widget.data['shipping_address'] = {
            'street': firstAddress['street'] ?? '',
            'village': firstAddress['village'] ?? '',
            'district': firstAddress['district'] ?? '',
            'city': firstAddress['city'] ?? '',
            'province': firstAddress['province'] ?? '',
            'postal_code': firstAddress['postal_code'] ?? '',
            'latitude': firstAddress['latitude'] ?? '',
            'longitude': firstAddress['longitude'] ?? ''
          };
          selectedAddress = userAddresses[0].toString();
        }
      });
    } catch (e) {
      print('Error fetching addresses: $e');
    }
    setState(() => isLoadingAddresses = false);
  }

  Future<void> handleConfirmOrder() async {
    // Validasi alamat
    if (widget.data['shipping_address'] == null ||
        widget.data['shipping_address'].toString().trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Silakan lengkapi alamat pengiriman terlebih dahulu',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Pastikan setiap merchant memiliki shipping cost
    for (var item in widget.data['items']) {
      final merchantId = item['products']['seller_id'];
      if (!merchantShippingCosts.containsKey(merchantId)) {
        Get.snackbar(
          'Error',
          'Silakan pilih metode pengiriman terlebih dahulu',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
    }

    try {
      print('Debug: Starting order creation process');

      // Cek apakah metode pembayaran adalah COD
      final selectedMethod = paymentMethods.firstWhere(
        (method) => method['id'].toString() == paymentMethod,
        orElse: () => {'name': ''},
      );
      final isCOD =
          selectedMethod['name'].toString().toLowerCase().contains('cod');

      // Parse alamat menjadi string yang rapi
      String formattedAddress = '';

      // Bersihkan string dan konversi ke Map
      String cleanAddress =
          selectedAddress!.replaceAll('{', '').replaceAll('}', '');

      Map<String, String> addressMap = {};
      cleanAddress.split(',').forEach((pair) {
        var keyValue = pair.split(':');
        if (keyValue.length == 2) {
          addressMap[keyValue[0].trim()] = keyValue[1].trim();
        }
      });

      // Format alamat menjadi string yang rapi
      formattedAddress = [
        addressMap['street'],
        if (addressMap['village']?.isNotEmpty == true)
          "Desa ${addressMap['village']}",
        if (addressMap['district']?.isNotEmpty == true)
          "Kec. ${addressMap['district']}",
        addressMap['city'],
        addressMap['province'],
        addressMap['postal_code']
      ].where((e) => e != null && e.isNotEmpty).join(', ');

      final params = {
        'p_buyer_id': supabase.auth.currentUser!.id,
        'p_payment_method_id': int.parse(paymentMethod ?? '1'),
        'p_shipping_address': formattedAddress,
        'p_items': widget.data['items']
            .map((item) => {
                  'product_id': item['products']['id'],
                  'quantity': item['quantity'],
                  'price': item['products']['price'],
                  'merchant_id': item['products']['seller_id'],
                })
            .toList(),
        'p_shipping_costs': Map<String, dynamic>.fromEntries(
          merchantShippingCosts.entries.map(
            (e) => MapEntry(e.key, e.value.toDouble()),
          ),
        ),
        'p_admin_fee': adminFee,
        'p_total_amount': widget.data['total_amount'] + adminFee + shippingCost,
        'p_total_shipping_cost': shippingCost,
      };

      final response = await supabase.rpc(
        'create_order_with_items',
        params: params,
      );

      if (response == null || response['success'] == false) {
        throw Exception(response?['message'] ?? 'Unknown error occurred');
      }

      final paymentGroupId = response['payment_group_id'];

      await cartController.clearCart(
          widget.data['items'].map((item) => item['product_id']).toList());

      // Navigasi ke PaymentScreen
      Get.off(() => PaymentScreen(
            orderData: {
              ...widget.data,
              'payment_group_id': paymentGroupId,
              'total_amount':
                  widget.data['total_amount'] + adminFee + shippingCost,
              'total_shipping_cost': shippingCost,
              'admin_fee': adminFee,
            },
            paymentMethod: selectedMethod,
          ));
    } catch (e) {
      print('Error creating order: $e');
      Get.snackbar(
        'Error',
        'Terjadi kesalahan saat membuat pesanan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Fungsi untuk menghitung berat volumetrik (dalam kg)
  double calculateVolumetricWeight(int length, int width, int height) {
    print('Debug Perhitungan Volumetrik DETAIL:');
    print('Input Dimensi:');
    print('Panjang: ${length}cm');
    print('Lebar: ${width}cm');
    print('Tinggi: ${height}cm');

    final volume = length * width * height;
    print('Volume: $volume cm³');

    final result = volume / 12000.0;
    print('Kalkulasi: $volume / 12000= $result kg');

    return result;
  }

  // Tambahkan fungsi untuk menghitung jarak
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // radius bumi dalam kilometer

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * asin(sqrt(a));
    return earthRadius * c; // jarak dalam kilometer
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  Future<void> calculateShippingCost() async {
    if (selectedShippingMethod == null) return;

    try {
      merchantShippingCosts.clear();
      merchantDistances.clear();
      double totalShippingCost = 0;

      if (widget.data['shipping_address'] != null) {
        double buyerLat =
            double.parse(widget.data['shipping_address']['latitude']);
        double buyerLon =
            double.parse(widget.data['shipping_address']['longitude']);

        final perKg =
            double.parse(selectedShippingMethod!['harga_per_kg'].toString());
        final perKm =
            double.parse(selectedShippingMethod!['harga_per_km'].toString());

        for (var item in widget.data['items']) {
          final merchantId = item['products']['seller_id'];
          final product = item['products'];
          final quantity = item['quantity'];

          final actualWeight = (product['weight'] ?? 1000) / 1000.0;
          final volumetricWeight = calculateVolumetricWeight(
            product['length'] ?? 0,
            product['width'] ?? 0,
            product['height'] ?? 0,
          );
          final itemWeight =
              actualWeight > volumetricWeight ? actualWeight : volumetricWeight;
          final totalWeight = roundWeight(itemWeight * quantity);

          final merchantData = await supabase
              .from('merchants')
              .select('store_address')
              .eq('id', merchantId)
              .single();

          if (merchantData['store_address'] != null) {
            var storeAddress =
                json.decode(merchantData['store_address'].toString());
            double storeLat = double.parse(storeAddress['latitude']);
            double storeLon = double.parse(storeAddress['longitude']);

            double distance =
                calculateDistance(buyerLat, buyerLon, storeLat, storeLon);
            merchantDistances[merchantId] = distance;

            double ongkirBerat = (perKg * roundWeight(totalWeight)).toDouble();
            double ongkirJarak = (perKm * distance).toDouble();
            double merchantOngkir = roundToThousand(ongkirBerat + ongkirJarak);

            print('DEBUG ONGKIR:');
            print(
                'Berat: ${roundWeight(totalWeight)} kg x Rp $perKg = Rp $ongkirBerat');
            print('Jarak: $distance km x Rp $perKm = Rp $ongkirJarak');
            print('Total sebelum pembulatan: ${ongkirBerat + ongkirJarak}');
            print('Total setelah pembulatan: $merchantOngkir');

            merchantShippingCosts[merchantId] = merchantOngkir;
            totalShippingCost += merchantOngkir;
          }
        }

        setState(() {
          shippingCost = totalShippingCost;
        });
      }
    } catch (e) {
      print('Error calculating shipping cost: $e');
    }
  }

  double roundWeight(double weight) {
    // Ambil desimal
    double decimal = weight - weight.floor();

    if (decimal < 0.2) {
      return weight.floor().toDouble(); // Bulatkan ke bawah
    } else if (decimal < 0.6) {
      return weight.floor() + 0.5; // Bulatkan ke 0.5
    } else {
      return weight.ceil().toDouble(); // Bulatkan ke atas
    }
  }

  double roundToThousand(double value) {
    // Bulatkan ke ribuan terdekat
    double rounded = (value / 1000).round() * 1000.0;

    // Tetapkan minimum 5000
    return rounded < 5000 ? 5000.0 : rounded;
  }

  Future<void> fetchVouchers() async {
    try {
      final response = await supabase
          .from('discount_vouchers')
          .select()
          .order('min_purchase', ascending: true);

      setState(() {
        availableDiscountVouchers = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching vouchers: $e');
    }
  }

  Future<void> validateVoucherCode(String code) async {
    try {
      print('Debug - Validasi kode: $code');
      print('Debug - Total sebelum diskon: ${calculateTotal()}');

      // Cek dari tabel discount_vouchers dulu
      final discountResponse = await supabase
          .from('discount_vouchers')
          .select()
          .eq('code', code)
          .maybeSingle();

      // Jika tidak ada di discount_vouchers, cek di shipping_vouchers
      if (discountResponse != null) {
        double total = calculateTotal();
        double minPurchase =
            (discountResponse['min_purchase'] as num).toDouble();

        if (total >= minPurchase) {
          setState(() {
            discountVoucher = discountResponse;
            discountAmount = (discountResponse['rate'] as num).toDouble();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Voucher diskon berhasil digunakan'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Total pembelian minimum Rp ${NumberFormat('#,###').format(minPurchase)}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Cek di tabel shipping_vouchers
      final shippingResponse = await supabase
          .from('shipping_vouchers')
          .select()
          .eq('code', code)
          .maybeSingle();

      if (shippingResponse != null) {
        setState(() {
          discountVoucher = shippingResponse;
          discountAmount = (shippingResponse['rate'] as num).toDouble();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voucher ongkir berhasil digunakan'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kode voucher tidak valid'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Debug - Error validasi voucher: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kode voucher tidak valid'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildShippingOptions() {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input kode voucher
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _voucherController,
                      decoration: InputDecoration(
                        hintText: 'Punya kode tarif khusus?',
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final code = _voucherController.text.trim();
                      if (code.isNotEmpty) {
                        validateVoucherCode(code);
                      }
                    },
                    child: Text('Cek Voucher'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Chat Admin button
            TextButton.icon(
              onPressed: createOrOpenChatRoom,
              icon: Icon(Icons.chat_bubble_outline, size: 16),
              label: Text(
                'Butuh tarif khusus? Chat Admin',
                style: TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 0),
                minimumSize: Size(double.infinity, 32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList() {
    Map<String, List<dynamic>> itemsByMerchant = {};
    Map<String, Map<String, dynamic>> merchantShippingInfo = {};

    for (var item in widget.data['items']) {
      final merchantId = item['products']['seller_id'];
      if (!itemsByMerchant.containsKey(merchantId)) {
        itemsByMerchant[merchantId] = [];
      }
      itemsByMerchant[merchantId]!.add(item);
    }

    String _getFirstImageUrl(Map<String, dynamic> product) {
      List<String> imageUrls = [];
      if (product['image_url'] != null) {
        try {
          if (product['image_url'] is List) {
            imageUrls = List<String>.from(product['image_url']);
          } else if (product['image_url'] is String) {
            final List<dynamic> urls = json.decode(product['image_url']);
            imageUrls = List<String>.from(urls);
          }
        } catch (e) {
          print('Error parsing image URLs: $e');
        }
      }
      return imageUrls.isNotEmpty
          ? imageUrls.first
          : 'https://via.placeholder.com/150';
    }

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag_outlined, color: AppTheme.primary),
                SizedBox(width: 8),
                Text(
                  'Daftar Produk',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...itemsByMerchant.entries.map((entry) {
              final merchantId = entry.key;
              final items = entry.value;
              final firstItem = items.first;
              final shippingInfo = merchantShippingCosts[merchantId];
              final distance = merchantDistances[merchantId];

              return Container(
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header toko
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.store,
                                  size: 20, color: AppTheme.primary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  firstItem['products']['merchant']
                                      ['store_name'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Kolom kiri untuk jarak dan berat
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.location_on_outlined,
                                            size: 16, color: Colors.grey),
                                        SizedBox(width: 4),
                                        Text(
                                          'Jarak: ${distance?.toStringAsFixed(2)} km',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 12),
                                    Icon(Icons.scale_outlined,
                                        size: 16, color: Colors.grey),
                                    SizedBox(width: 4),
                                    Text(
                                      'Berat: ${items.fold(0.0, (sum, item) {
                                        final weight = (item['products']
                                                    ['weight'] ??
                                                1000) /
                                            1000.0;
                                        return sum +
                                            (weight * item['quantity']);
                                      }).toStringAsFixed(2)} kg',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                // Kolom kanan untuk ongkir
                                if (shippingInfo != null)
                                  Text(
                                    'Rp ${NumberFormat('#,###').format(shippingInfo)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Daftar produk
                    ...items
                        .map((item) => Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _getFirstImageUrl(item['products']),
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  // Informasi produk
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['products']['name'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Rp ${NumberFormat('#,###').format(item['products']['price'])}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${item['quantity']} item',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> createOrOpenChatRoom() async {
    try {
      // Cek apakah sudah ada room chat admin
      final existingRooms = await supabase
          .from('admin_chat_rooms')
          .select()
          .eq('buyer_id', supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);

      Map<String, dynamic> chatRoom;

      if (existingRooms.isEmpty) {
        // Buat room chat admin baru
        final response = await supabase
            .from('admin_chat_rooms')
            .insert({
              'buyer_id': supabase.auth.currentUser!.id,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        chatRoom = response;
      } else {
        chatRoom = existingRooms[0];
      }

      // Navigasi ke halaman chat detail
      Get.to(() => ChatDetailScreen(
            chatRoom: chatRoom,
            seller: {
              'store_name': 'Admin Kumbly',
              'image': 'https://via.placeholder.com/50'
            },
            isAdminRoom: true,
          ));
    } catch (e) {
      print('Error creating/opening chat room: $e');
      Get.snackbar(
        'Error',
        'Gagal membuka ruang chat',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildShippingMethodSelector() {
    print(
        'Building shipping selector. Methods: $shippingMethods'); // Debug print
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping_outlined, color: AppTheme.primary),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Pengiriman',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            if (shippingMethods.isEmpty)
              Center(
                child: Text(
                  'Tidak ada metode pengiriman tersedia',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              )
            else
              ...shippingMethods
                  .map(
                    (method) => RadioListTile<Map<String, dynamic>>(
                      title: Text(method['nama_pengiriman']),
                      value: method,
                      groupValue: selectedShippingMethod,
                      onChanged: (value) {
                        setState(() {
                          selectedShippingMethod = value;
                        });
                        calculateShippingCost();
                      },
                    ),
                  )
                  .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountVoucherCard() {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input voucher
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _voucherController,
                      decoration: InputDecoration(
                        hintText: 'Masukkan kode voucher',
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final code = _voucherController.text.trim();
                      if (code.isNotEmpty) {
                        validateVoucherCode(code);
                      }
                    },
                    child: Text('Gunakan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Menampilkan voucher yang sedang digunakan
            if (discountVoucher != null)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voucher Aktif: ${discountVoucher!['code']}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            'Potongan: Rp ${NumberFormat('#,###').format(discountAmount)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          discountVoucher = null;
                          discountAmount = 0;
                          _voucherController.clear();
                        });
                      },
                      icon: Icon(Icons.close,
                          color: Colors.green.shade700, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: createOrOpenChatRoom,
              icon: Icon(Icons.chat_bubble_outline, size: 24),
              label: Text(
                'Ongkirmu besar? Chat Admin',
                style: TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 0),
                minimumSize: Size(double.infinity, 32),
              ),
            ),

            // Existing voucher list header
            Row(
              children: [
                Icon(Icons.discount, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Voucher Diskon',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (isLoadingVouchers)
              Center(child: CircularProgressIndicator())
            else if (availableDiscountVouchers.isEmpty)
              Center(
                child: Text(
                  'Tidak ada voucher tersedia',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: availableDiscountVouchers.length,
                itemBuilder: (context, index) {
                  final voucher = availableDiscountVouchers[index];
                  final isSelected = discountVoucher?['id'] == voucher['id'];
                  final totalAmount =
                      widget.data['total_amount'] + adminFee + shippingCost;
                  final isEligible =
                      totalAmount >= (voucher['min_purchase'] ?? 0);

                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color:
                          isSelected ? AppTheme.primary.withOpacity(0.1) : null,
                    ),
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      title: Text(
                        'Diskon Rp ${NumberFormat('#,###').format(voucher['rate'])}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (voucher['min_purchase'] != null)
                            Text(
                              'Min. pembelian Rp ${NumberFormat('#,###').format(voucher['min_purchase'])}',
                              style: TextStyle(fontSize: 12),
                            ),
                          if (voucher['max_discount'] != null)
                            Text(
                              'Maks. diskon Rp ${NumberFormat('#,###').format(voucher['max_discount'])}',
                              style: TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: isEligible
                          ? ElevatedButton(
                              onPressed: isSelected
                                  ? () {
                                      setState(() {
                                        discountVoucher = null;
                                        discountAmount = 0;
                                      });
                                    }
                                  : () {
                                      validateVoucherCode(voucher['code']);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isSelected ? Colors.red : AppTheme.primary,
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: Size(0, 32),
                              ),
                              child: Text(
                                isSelected ? 'Hapus' : 'Pakai',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Min. pembelian tidak terpenuhi',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                              ),
                            ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
      ),
      body: Obx(() {
        if (orderController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // Alamat Pengiriman
                _buildShippingAddressCard(),
                SizedBox(height: 8),

                // Opsi Pengiriman
                _buildShippingMethodSelector(),
                SizedBox(height: 8),

                // Metode Pembayaran
                Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payment,
                                color: AppTheme.primary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Metode Pembayaran',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        if (isLoadingPayments)
                          Center(child: CircularProgressIndicator())
                        else
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: paymentMethod,
                                hint: Text('Pilih metode pembayaran'),
                                items: paymentMethods.map((method) {
                                  return DropdownMenuItem(
                                    value: method['id'].toString(),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(method['name'],
                                            style: TextStyle(fontSize: 13)),
                                        if (method['account_number'] != null)
                                          Text(
                                            '${method['account_number']} (${method['account_name']} ${method['admin']})',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    paymentMethod = value!;
                                    final method = paymentMethods.firstWhere(
                                        (m) => m['id'].toString() == value);
                                    adminFee = double.parse(
                                        method['admin'].toString());
                                  });
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8),

                // Daftar Produk
                _buildProductList(),
                SizedBox(height: 8),

                // Voucher Diskon
                _buildDiscountVoucherCard(),
                SizedBox(height: 8),

                // Ringkasan Pembayaran
                _buildPaymentSummary(),
              ],
            ),
          ),
        );
      }),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isAddressValid()
              ? () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Konfirmasi Pesanan'),
                        content: Text(
                            'Apakah Anda yakin ingin mengonfirmasi pesanan ini?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              handleConfirmOrder();
                            },
                            child: Text('Ya'),
                          ),
                        ],
                      );
                    },
                  );
                }
              : null, // Disable tombol jika alamat tidak valid
          style: ElevatedButton.styleFrom(
            backgroundColor: isAddressValid() ? AppTheme.primary : Colors.grey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text('Konfirmasi Pesanan',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildShippingAddressCard() {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: AppTheme.primary, size: 18),
                SizedBox(width: 8),
                Text(
                  'Alamat Pengiriman',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Divider(height: 16),
            if (isLoadingAddresses)
              Center(child: CircularProgressIndicator())
            else
              InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(15)),
                    ),
                    builder: (context) => Container(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Text(
                              'Pilih Alamat',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Divider(height: 1),
                          ...userAddresses
                              .map((address) => InkWell(
                                    onTap: () async {
                                      setState(() {
                                        selectedAddress = address.toString();
                                        widget.data['shipping_address'] =
                                            address;
                                      });
                                      Navigator.pop(context);

                                      // Debug print setelah alamat berubah
                                      print('\nDEBUG: ALAMAT BERUBAH');
                                      print('Alamat Baru Pembeli:');
                                      print(json.encode(
                                          widget.data['shipping_address']));

                                      // Recalculate shipping cost akan memicu debug alamat toko juga
                                      await calculateShippingCost();
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: widget
                                                    .data['shipping_address'] ==
                                                address
                                            ? AppTheme.primary.withOpacity(0.1)
                                            : Colors.transparent,
                                        border: Border(
                                          bottom: BorderSide(
                                              color: Colors.grey.shade200),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              parseAddress(
                                                  Map<String, dynamic>.from(
                                                      address)),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: widget.data[
                                                            'shipping_address'] ==
                                                        address
                                                    ? AppTheme.primary
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          if (widget.data['shipping_address'] ==
                                              address)
                                            Icon(
                                              Icons.check_circle,
                                              color: AppTheme.primary,
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ))
                              .toList(),
                          Divider(height: 1),
                          InkWell(
                            onTap: () async {
                              Navigator.pop(context);
                              final Map<String, dynamic>? tempAddress =
                                  await Get.to(() => EditAddressScreen(
                                        initialAddress: '',
                                        onSave: (Map<String, dynamic>
                                            addressDetails) {
                                          setState(() {
                                            selectedAddress =
                                                addressDetails.toString();
                                            widget.data['shipping_address'] =
                                                addressDetails;
                                          });
                                        },
                                      ));

                              if (tempAddress != null) {
                                setState(() {
                                  selectedAddress = tempAddress.toString();
                                  widget.data['shipping_address'] = tempAddress;
                                  if (userAddresses.contains(tempAddress)) {
                                    userAddresses.remove(tempAddress);
                                  }
                                });
                                await calculateShippingCost();
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_circle_outline,
                                    color: AppTheme.primary,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Gunakan Alamat Lain',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.data['shipping_address'] != null)
                              Text(
                                widget.data['shipping_address'] is Map
                                    ? _formatAddressDisplay(
                                        Map<String, dynamic>.from(
                                            widget.data['shipping_address']))
                                    : widget.data['shipping_address']
                                        .toString(),
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              )
                            else
                              Text(
                                'Pilih alamat pengiriman',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSummary() {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ringkasan Pembayaran',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildPaymentDetail(
                'Total Harga', widget.data['total_amount'].toDouble()),
            _buildPaymentDetail('Biaya Penanganan', adminFee),
            _buildPaymentDetail('Ongkos Kirim', shippingCost,
                note:
                    discountAmount >= shippingCost ? '(Gratis Ongkir)' : null),
            if (discountAmount > 0)
              _buildPaymentDetail('Diskon Voucher', -discountAmount,
                  isDiscount: true),
            Divider(height: 16),
            _buildPaymentDetail(
              'Total Pembayaran',
              (widget.data['total_amount'].toDouble() +
                      adminFee +
                      shippingCost) -
                  (discountAmount > shippingCost
                      ? shippingCost
                      : discountAmount),
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetail(String label, double amount,
      {bool isTotal = false, bool isDiscount = false, String? note}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13)),
          Row(
            children: [
              Text(
                '${isDiscount ? "-" : ""}Rp ${NumberFormat('#,###').format(amount.abs())}',
                style: TextStyle(
                  fontSize: isTotal ? 14 : 13,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  color: isTotal
                      ? AppTheme.primary
                      : isDiscount
                          ? Colors.red
                          : null,
                ),
              ),
              if (note != null) ...[
                SizedBox(width: 4),
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Tambahkan fungsi untuk validasi alamat
  bool isAddressValid() {
    return widget.data['shipping_address'] != null &&
        widget.data['shipping_address'].toString().trim().isNotEmpty;
  }

  String parseAddress(Map<String, dynamic> addressJson) {
    try {
      // Bersihkan string dari karakter yang tidak diinginkan
      Map<String, String> cleanAddress = {};
      addressJson.forEach((key, value) {
        if (value is String) {
          // Bersihkan string dari karakter khusus dan spasi berlebih
          cleanAddress[key] = value.replaceAll(RegExp(r'[{}"]'), '').trim();
        }
      });

      List<String> addressParts = [];

      // Susun alamat sesuai format yang diinginkan
      if (cleanAddress['street']?.isNotEmpty == true)
        addressParts.add(cleanAddress['street']!);

      if (cleanAddress['village']?.isNotEmpty == true)
        addressParts.add("Desa ${cleanAddress['village']}");

      if (cleanAddress['district']?.isNotEmpty == true)
        addressParts.add("Kec. ${cleanAddress['district']}");

      if (cleanAddress['city']?.isNotEmpty == true)
        addressParts.add(cleanAddress['city']!);

      if (cleanAddress['province']?.isNotEmpty == true)
        addressParts.add(cleanAddress['province']!);

      if (cleanAddress['postal_code']?.isNotEmpty == true)
        addressParts.add(cleanAddress['postal_code']!);

      // Gabungkan semua bagian alamat dengan koma
      return addressParts.where((part) => part.isNotEmpty).join(', ');
    } catch (e) {
      print('Error parsing address: $e');
      // Jika terjadi error, kembalikan string kosong atau pesan error
      return 'Format alamat tidak valid';
    }
  }

  // Tambahkan method baru untuk format tampilan alamat
  String _formatAddressDisplay(Map<String, dynamic> address) {
    try {
      // Filter dan susun hanya informasi penting untuk tampilan awal
      List<String> displayParts = [];

      if (address['street']?.isNotEmpty == true)
        displayParts.add(address['street']);

      if (address['district']?.isNotEmpty == true)
        displayParts.add("Kec. ${address['district']}");

      if (address['city']?.isNotEmpty == true)
        displayParts.add(address['city']);

      if (address['province']?.isNotEmpty == true)
        displayParts.add(address['province']);

      // Hilangkan data koordinat dan informasi teknis lainnya
      return displayParts
          .where((part) => part.isNotEmpty)
          .join(', ')
          .replaceAll(RegExp(r'[{}"]'), '')
          .trim();
    } catch (e) {
      print('Error formatting address display: $e');
      return 'Pilih alamat pengiriman';
    }
  }

  double calculateTotal() {
    return widget.data['total_amount'] + adminFee + shippingCost;
  }
}
