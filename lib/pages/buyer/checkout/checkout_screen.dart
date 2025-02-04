import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/cart_controller.dart';
import 'package:kumbly_ecommerce/controllers/order_controller.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../checkout/edit_address_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kumbly_ecommerce/pages/buyer/payment/payment_screen.dart';

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
  bool isLoadingRates = false;
  Map<String, double> merchantShippingCosts = {};

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
      final response =
          await supabase.from('shipping_rates').select().order('type');

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
      final rateResponse = await supabase
          .from('shipping_rates')
          .select()
          .eq('type', shippingType!)
          .single();

      final baseRate = double.parse(rateResponse['base_rate'].toString());
      Map<String, double> merchantWeights = {};

      // Mengelompokkan dan menghitung total berat per merchant
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

      // Menghitung ongkir per merchant
      double totalShippingCost = 0;
      merchantShippingCosts.clear();

      merchantWeights.forEach((merchantId, totalWeight) {
        print('Final calculation for Merchant $merchantId:');
        print('Total accumulated weight: $totalWeight kg');

        // Gunakan minimum 1 kg atau pembulatan matematika yang tepat
        double chargeableWeight;
        if (totalWeight < 1.0) {
          chargeableWeight = 1.0;
        } else {
          // Pembulatan ke atas jika desimal >= 0.5, ke bawah jika < 0.5
          chargeableWeight = (totalWeight - totalWeight.floor() >= 0.5)
              ? totalWeight.ceil().toDouble()
              : totalWeight.floor().toDouble();
        }

        final merchantShippingCost = baseRate * chargeableWeight;
        merchantShippingCosts[merchantId] = merchantShippingCost;
        totalShippingCost += merchantShippingCost;

        print('Chargeable weight: $chargeableWeight kg');
        print('Shipping cost: Rp $merchantShippingCost');
      });

      setState(() {
        shippingCost = totalShippingCost;
      });
    } catch (e) {
      print('Error calculating shipping cost: $e');
    }
  }

  Widget _buildShippingOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping, color: AppTheme.primary),
                SizedBox(width: 8),
                Text(
                  'Pilih Pengiriman',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (isLoadingRates)
              Center(child: CircularProgressIndicator())
            else
              ...shippingRates
                  .map((rate) => RadioListTile<String>(
                        title: Text(rate['type'] == 'within'
                            ? 'Dalam Kabupaten'
                            : 'Antar Kabupaten'),
                        subtitle: Text(
                            'Rp ${NumberFormat('#,###').format(rate['base_rate'])}/kg'),
                        value: rate['type'],
                        groupValue: shippingType,
                        onChanged: (value) async {
                          setState(() => shippingType = value);
                          await calculateShippingCost();
                        },
                      ))
                  .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSummary() {
    final totalAmount = widget.data['total_amount'];
    final totalPayment = totalAmount + adminFee + shippingCost;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ringkasan Pembayaran',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Harga'),
                Text(
                  'Rp ${NumberFormat('#,###').format(totalAmount)}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Biaya Penanganan'),
                Text(
                  'Rp ${NumberFormat('#,###').format(adminFee)}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ongkos Kirim'),
                Text(
                  'Rp ${NumberFormat('#,###').format(shippingCost)}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Pembayaran',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Rp ${NumberFormat('#,###').format(totalPayment)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    fontSize: 16,
                  ),
                ),
              ],
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Alamat Pengiriman
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Text(
                              'Alamat Pengiriman',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Apakah Anda ingin menambahkan alamat lain?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
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
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                              Icon(Icons.edit,
                                  color: AppTheme.primary, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Metode Pembayaran
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payment, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Text(
                              'Metode Pembayaran',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (isLoadingPayments)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          ...paymentMethods.map((method) {
                            return RadioListTile<String>(
                              title: Text(method['name']),
                              subtitle: method['account_number'] != null
                                  ? Text(
                                      '${method['account_number']} (${method['account_name']})')
                                  : null,
                              value: method['id'].toString(),
                              groupValue: paymentMethod,
                              onChanged: (value) {
                                setState(() {
                                  paymentMethod = value!;
                                  // Update admin fee berdasarkan metode pembayaran yang dipilih
                                  final selectedMethod =
                                      paymentMethods.firstWhere(
                                    (m) => m['id'].toString() == value,
                                  );
                                  adminFee = double.parse(
                                      selectedMethod['admin'].toString());
                                });
                              },
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                _buildProductList(),
                SizedBox(height: 16),
                _buildPaymentSummary(),
                SizedBox(height: 16),
                _buildShippingOptions(),
              ],
            ),
          ),
        );
      }),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
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
                      onPressed: () {
                        Navigator.of(context).pop(); // Tutup dialog
                      },
                      child: Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                        handleConfirmOrder(); // Panggil fungsi konfirmasi pesanan
                        Navigator.of(context)
                            .pop(); // Tutup dialog setelah konfirmasi
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
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Konfirmasi Pesanan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
