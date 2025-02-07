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

  @override
  void initState() {
    super.initState();
    fetchPaymentMethods();
    fetchShippingRates();
    fetchAvailableVouchers();
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

      final params = {
        'p_buyer_id': supabase.auth.currentUser!.id,
        'p_payment_method_id':
            int.parse(paymentMethod ?? '1'), // Default ke ID 1 untuk COD
        'p_shipping_address': widget.data['shipping_address'],
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

  Future<void> calculateShippingCost() async {
    if (shippingType == null) return;

    try {
      double baseRate;
      Map<String, double> merchantWeights = {};
      merchantShippingCosts.clear();
      double totalShippingCost = 0;

      // Ambil base rate sesuai tipe pengiriman
      if (shippingType == 'special') {
        final selectedRate = shippingRates.firstWhere(
          (rate) => rate['type'] == 'special',
        );
        baseRate = double.parse(selectedRate['base_rate'].toString());
      } else {
        final selectedRate = shippingRates.firstWhere(
          (rate) => rate['type'] == shippingType,
        );
        baseRate = double.parse(selectedRate['base_rate'].toString());
      }

      // Kelompokkan item berdasarkan merchant
      Map<String, List<dynamic>> itemsByMerchant = {};
      for (var item in widget.data['items']) {
        final merchantId = item['products']['seller_id'];
        if (!itemsByMerchant.containsKey(merchantId)) {
          itemsByMerchant[merchantId] = [];
        }
        itemsByMerchant[merchantId]!.add(item);
      }

      // Hitung ongkir untuk setiap merchant
      itemsByMerchant.forEach((merchantId, items) {
        if (shippingType == 'special') {
          // Untuk tarif khusus, gunakan base rate langsung per merchant
          merchantShippingCosts[merchantId] = baseRate;
          totalShippingCost += baseRate;
        } else {
          // Untuk tarif regular, hitung berdasarkan berat
          double totalWeight = 0.0;
          for (var item in items) {
            final product = item['products'];
            final actualWeight = (product['weight'] ?? 1000) / 1000.0;
            final volumetricWeight = calculateVolumetricWeight(
              product['length'] ?? 0,
              product['width'] ?? 0,
              product['height'] ?? 0,
            );
            final itemWeight = actualWeight > volumetricWeight
                ? actualWeight
                : volumetricWeight;
            totalWeight += itemWeight * item['quantity'];
          }

          // Pembulatan berat
          double chargeableWeight = totalWeight < 1.0
              ? 1.0
              : (totalWeight - totalWeight.floor() >= 0.5)
                  ? totalWeight.ceil().toDouble()
                  : totalWeight.floor().toDouble();

          final merchantShippingCost = baseRate * chargeableWeight;
          merchantShippingCosts[merchantId] = merchantShippingCost;
          totalShippingCost += merchantShippingCost;
        }
      });

      setState(() {
        shippingCost = totalShippingCost;
      });

      print('Debug - Shipping costs per merchant:');
      merchantShippingCosts.forEach((merchantId, cost) {
        print('Merchant $merchantId: Rp ${NumberFormat('#,###').format(cost)}');
      });
    } catch (e) {
      print('Error calculating shipping cost: $e');
    }
  }

  Future<void> validateVoucherCode(String code) async {
    try {
      // Cek apakah sedang menggunakan tarif khusus
      if (shippingType == 'special') {
        Get.snackbar(
          'Gagal',
          'Tidak dapat menggunakan diskon saat menggunakan tarif khusus',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Cek shipping voucher terlebih dahulu
      final shippingVoucher = await supabase
          .from('shipping_vouchers')
          .select()
          .eq('code', code)
          .maybeSingle();

      if (shippingVoucher != null) {
        setState(() {
          if (specialRate != null) {
            shippingRates.remove(specialRate);
          }
          specialRate = {
            'type': 'special',
            'base_rate': shippingVoucher['rate'],
            'code': shippingVoucher['code']
          };
          shippingRates.add(specialRate!);
        });
        Get.snackbar(
          'Sukses',
          'Kode tarif khusus tersedia, silakan pilih untuk menggunakan',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        return; // Keluar dari fungsi jika ini adalah shipping voucher
      }

      // Cek discount voucher
      final discountVoucher = await supabase
          .from('discount_vouchers')
          .select()
          .eq('code', code)
          .maybeSingle();

      if (discountVoucher != null) {
        final totalAmount =
            widget.data['total_amount'] + adminFee + shippingCost;
        if (totalAmount >= (discountVoucher['min_purchase'] ?? 0)) {
          setState(() {
            this.discountVoucher = discountVoucher;

            // Ambil rate sebagai nilai potongan langsung
            double calculatedDiscount =
                double.parse(discountVoucher['rate'].toString());

            // Batasi diskon tidak melebihi ongkir
            if (calculatedDiscount > shippingCost) {
              calculatedDiscount = shippingCost;
            }

            discountAmount = calculatedDiscount;
          });

          Get.snackbar(
            'Sukses',
            'Diskon ongkir Rp ${NumberFormat('#,###').format(discountAmount)} berhasil digunakan',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        } else {
          Get.snackbar(
            'Gagal',
            'Minimal pembelian Rp ${NumberFormat('#,###').format(discountVoucher['min_purchase'] ?? 0)}',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
        return;
      }

      // Jika kode tidak valid untuk kedua jenis voucher
      Get.snackbar(
        'Error',
        'Kode tidak valid',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error validating voucher: $e');
      Get.snackbar(
        'Error',
        'Terjadi kesalahan saat validasi',
        backgroundColor: Colors.red,
        colorText: Colors.white,
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

            // Opsi pengiriman
            if (isLoadingRates)
              Center(child: CircularProgressIndicator())
            else
              ...shippingRates.map((rate) => RadioListTile<String>(
                    contentPadding: EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          rate['type'] == 'within'
                              ? 'Dalam Kabupaten'
                              : rate['type'] == 'between'
                                  ? 'Antar Kabupaten'
                                  : 'Tarif Khusus (${rate['code']})',
                          style: TextStyle(fontSize: 13),
                        ),
                        Text(
                          'Rp ${NumberFormat('#,###').format(rate['base_rate'])}${rate['type'] != 'special' ? '/kg' : ''}',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    value: rate['type'],
                    groupValue: shippingType,
                    onChanged: (value) async {
                      setState(() => shippingType = value);
                      await calculateShippingCost();
                    },
                  )),

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

              return Container(
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header toko dengan ongkir
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.store, size: 20, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              firstItem['products']['merchant']['store_name'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.pink.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Ongkir: Rp ${NumberFormat('#,###').format(merchantShippingCosts[merchantId] ?? 0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.pink,
                                fontWeight: FontWeight.w500,
                              ),
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
              'created_at': DateTime.now().toUtc().toIso8601String(),
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
                            Icon(Icons.location_on,
                                color: AppTheme.primary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Alamat Pengiriman',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Divider(height: 16),
                        GestureDetector(
                          onTap: () async {
                            final updatedAddress =
                                await Get.to(() => EditAddressScreen(
                                      initialAddress:
                                          widget.data['shipping_address'],
                                      onSave: (newAddress) {
                                        setState(() {
                                          widget.data['shipping_address'] =
                                              newAddress;
                                        });
                                      },
                                    ));
                            if (updatedAddress != null) {
                              setState(() {
                                widget.data['shipping_address'] =
                                    updatedAddress;
                              });
                            }
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.data['shipping_address'],
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              Icon(Icons.edit,
                                  color: AppTheme.primary, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8),

                // Opsi Pengiriman
                _buildShippingOptions(),
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
                                            '${method['account_number']} (${method['account_name']})',
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
}
