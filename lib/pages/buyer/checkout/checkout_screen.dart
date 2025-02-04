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

  @override
  void initState() {
    super.initState();
    fetchPaymentMethods();
    fetchShippingRates();
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

  Future<void> handleConfirmOrder() async {
    if (paymentMethod != null) {
      try {
        print('Debug: Starting order creation process');

        // Debug print data yang akan dikirim
        final params = {
          'p_buyer_id': supabase.auth.currentUser!.id,
          'p_payment_method_id': int.parse(paymentMethod!),
          'p_shipping_address': widget.data['shipping_address'],
          'p_items': widget.data['items']
              .map((item) => {
                    'product_id': item['products']['id'],
                    'quantity': item['quantity'],
                    'price': item['products']['price'],
                    'merchant_id': item['products']['seller_id'],
                  })
              .toList(),
          'p_shipping_costs': merchantShippingCosts,
          'p_admin_fee': adminFee,
          'p_total_amount':
              widget.data['total_amount'] + adminFee + shippingCost,
          'p_total_shipping_cost': shippingCost,
        };

        print('Debug: Parameters being sent:');
        print(params);

        final response = await supabase.rpc(
          'create_order_with_items',
          params: params,
        );

        print('Debug: RPC Response:');
        print(response);

        if (response == null || response['success'] == false) {
          throw Exception(response?['message'] ?? 'Unknown error occurred');
        }

        // Ambil payment_group_id dari response
        final paymentGroupId = response['payment_group_id'];

        await cartController.clearCart();

        final selectedPaymentMethod = paymentMethods
            .firstWhere((method) => method['id'].toString() == paymentMethod);

        Get.off(() => PaymentScreen(
              orderData: {
                ...widget.data,
                'payment_group_id':
                    paymentGroupId, // Tambahkan payment_group_id
                'total_amount':
                    widget.data['total_amount'] + adminFee + shippingCost,
                'total_shipping_cost': shippingCost,
                'admin_fee': adminFee,
              },
              paymentMethod: selectedPaymentMethod,
            ));
      } catch (e) {
        print('Error creating order: $e');
        Get.snackbar(
          'Error',
          'Terjadi kesalahan saat membuat pesanan: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    } else {
      Get.snackbar(
        'Error',
        'Silakan pilih metode pembayaran',
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
      final selectedRate = shippingRates.firstWhere(
        (rate) => rate['type'] == shippingType,
        orElse: () => throw Exception('Rate not found'),
      );

      if (shippingType == 'special') {
        // Untuk tarif khusus, langsung set total shipping cost tanpa kalkulasi
        setState(() {
          shippingCost = double.parse(selectedRate['base_rate'].toString());
          merchantShippingCosts.clear();
          // Simpan total ke merchant pertama saja
          if (widget.data['items'].isNotEmpty) {
            final firstItem = widget.data['items'][0];
            merchantShippingCosts[firstItem['products']['seller_id']] =
                shippingCost;
          }
        });
        return;
      }

      // Kalkulasi normal untuk tarif regular (within/between)
      double baseRate = double.parse(selectedRate['base_rate'].toString());
      Map<String, double> merchantWeights = {};

      // Hitung berat per merchant
      for (var item in widget.data['items']) {
        final product = item['products'];
        final merchantId = product['seller_id'];

        if (!merchantWeights.containsKey(merchantId)) {
          merchantWeights[merchantId] = 0.0;
        }

        final actualWeight = (product['weight'] ?? 1000) / 1000.0;
        final volumetricWeight = calculateVolumetricWeight(
          product['length'] ?? 0,
          product['width'] ?? 0,
          product['height'] ?? 0,
        );

        final itemWeight =
            actualWeight > volumetricWeight ? actualWeight : volumetricWeight;
        merchantWeights[merchantId] =
            merchantWeights[merchantId]! + (itemWeight * item['quantity']);
      }

      // Hitung ongkir per merchant untuk tarif regular
      double totalShippingCost = 0;
      merchantShippingCosts.clear();

      merchantWeights.forEach((merchantId, totalWeight) {
        double chargeableWeight = totalWeight < 1.0
            ? 1.0
            : (totalWeight - totalWeight.floor() >= 0.5)
                ? totalWeight.ceil().toDouble()
                : totalWeight.floor().toDouble();

        final merchantShippingCost = baseRate * chargeableWeight;
        merchantShippingCosts[merchantId] = merchantShippingCost;
        totalShippingCost += merchantShippingCost;
      });

      setState(() {
        shippingCost = totalShippingCost;
      });
    } catch (e) {
      print('Error calculating shipping cost: $e');
    }
  }

  Future<void> validateVoucherCode(String code) async {
    try {
      final response = await supabase
          .from('shipping_vouchers')
          .select()
          .eq('code', code)
          .single();

      if (response != null) {
        setState(() {
          specialRate = {
            'type': 'special',
            'base_rate': response['rate'],
          };
          shippingRates.add(specialRate!);
        });
        Get.snackbar(
          'Sukses',
          'Kode tarif khusus berhasil digunakan',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Kode tarif khusus tidak valid',
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
            Row(
              children: [
                Icon(Icons.local_shipping, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Pilih Pengiriman',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            // Input kode tarif khusus
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
                        if (specialRate != null) {
                          setState(() {
                            shippingRates.remove(specialRate);
                            specialRate = null;
                          });
                        }
                        validateVoucherCode(code);
                      }
                    },
                    child: Text(
                      'Cek Voucher',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      minimumSize: Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
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
                                  : 'Tarif Khusus',
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
            // Tombol Chat Admin
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
                    // Header toko
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
                          if (merchantShippingCosts[merchantId] != null)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Ongkir: Rp ${NumberFormat('#,###').format(merchantShippingCosts[merchantId])}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
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
                                  // Gambar produk
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      item['products']['image_url'],
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

                // Ringkasan Pembayaran
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
                        Text(
                          'Ringkasan Pembayaran',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 12),
                        _buildPaymentDetail(
                            'Total Harga', widget.data['total_amount']),
                        _buildPaymentDetail('Biaya Penanganan', adminFee),
                        _buildPaymentDetail('Ongkos Kirim', shippingCost),
                        Divider(height: 16),
                        _buildPaymentDetail(
                          'Total Pembayaran',
                          widget.data['total_amount'] + adminFee + shippingCost,
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),
                ),
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
          onPressed: () {
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
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child:
              Text('Konfirmasi Pesanan', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildPaymentDetail(String label, double amount,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13)),
          Text(
            'Rp ${NumberFormat('#,###').format(amount)}',
            style: TextStyle(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? AppTheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
