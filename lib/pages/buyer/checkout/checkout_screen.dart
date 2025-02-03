import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/cart_controller.dart';
import 'package:kumbly_ecommerce/controllers/order_controller.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../checkout/edit_address_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kumbly_ecommerce/pages/buyer/payment/payment_screen.dart';
import 'package:kumbly_ecommerce/services/raja_ongkir_service.dart';

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
  String? selectedProvinceId;
  String? selectedCityId;
  List<dynamic> provinces = [];
  List<dynamic> cities = [];
  Map<String, dynamic>? shippingCost;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchPaymentMethods();
    _loadProvinces();
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

  Future<void> _loadProvinces() async {
    try {
      setState(() => isLoading = true);
      final provinceList = await RajaOngkirService.getProvinces();
      setState(() {
        provinces = provinceList;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      Get.snackbar('Error', 'Gagal memuat data provinsi');
    }
  }

  Future<void> _loadCities(String provinceId) async {
    try {
      setState(() => isLoading = true);
      final cityList = await RajaOngkirService.getCities(provinceId);
      setState(() {
        cities = cityList;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      Get.snackbar('Error', 'Gagal memuat data kota');
    }
  }

  Future<void> _checkShippingCost() async {
    if (selectedCityId == null) return;

    try {
      setState(() => isLoading = true);
      final cost = await RajaOngkirService.checkShippingCost(
        origin: "153", // ID kota asal (contoh: Jakarta Pusat)
        destination: selectedCityId!,
        weight: 1000, // Berat dalam gram
        courier: "jne", // Bisa diganti sesuai kebutuhan
      );
      setState(() {
        shippingCost = cost;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      Get.snackbar('Error', 'Gagal menghitung ongkos kirim');
    }
  }

  Future<void> handleConfirmOrder() async {
    if (paymentMethod != null) {
      try {
        await orderController.createSeparateOrders(
          {
            ...widget.data,
            'payment_method_id': paymentMethod,
          },
          adminFee,
        );

        await cartController.clearCart();

        final selectedPaymentMethod = paymentMethods
            .firstWhere((method) => method['id'].toString() == paymentMethod);

        Get.off(() => PaymentScreen(
              orderData: {
                ...widget.data,
                'total_amount': widget.data['total_amount'] + adminFee,
              },
              paymentMethod: selectedPaymentMethod,
            ));
      } catch (e) {
        print('Error: $e');
      }
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
                                setState(() => paymentMethod = value!);
                              },
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Daftar Produk
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shopping_bag, color: AppTheme.primary),
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
                        SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: widget.data['items'].length,
                          itemBuilder: (context, index) {
                            final item = widget.data['items'][index];
                            print('Debug item data:');
                            print(item);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: NetworkImage(
                                        item['products']['image_url']),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['products']?['merchant']
                                            ?['store_name'] ??
                                        'Nama Merchant',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    item['products']['name'],
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'Rp ${NumberFormat('#,###').format(item['products']['price'])}',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Text('x${item['quantity']}'),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Total Pembayaran
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ringkasan Pembayaran',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Harga'),
                            Text(
                              'Rp ${NumberFormat('#,###').format(widget.data['total_amount'])}',
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
                        Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Pembayaran',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Rp ${NumberFormat('#,###').format(widget.data['total_amount'] + adminFee)}',
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
                ),
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
          onPressed: handleConfirmOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
              padding: EdgeInsets.symmetric(vertical: 5),
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
      ),
    );
  }
}
