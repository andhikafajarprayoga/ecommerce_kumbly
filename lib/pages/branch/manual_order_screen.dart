import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/pages/branch/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/auth_controller.dart';

class ManualOrderScreen extends StatefulWidget {
  const ManualOrderScreen({super.key});

  @override
  State<ManualOrderScreen> createState() => _ManualOrderScreenState();
}

class _ManualOrderScreenState extends State<ManualOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;
  final AuthController authController = Get.find<AuthController>();

  // Step tracking
  final _currentStep = 0.obs;

  // Controllers untuk form
  final senderNameController = TextEditingController();
  final senderPhoneController = TextEditingController();
  final senderAddressController = TextEditingController();
  final recipientNameController = TextEditingController();
  final recipientPhoneController = TextEditingController();
  final recipientAddressController = TextEditingController();

  // Tambahan untuk produk
  final selectedProducts = <Map<String, dynamic>>[].obs;
  final quantities = <String, int>{}.obs;
  final totalWeight = 0.obs; // dalam gram
  final shippingCost = 0.0.obs;
  final subtotal = 0.0.obs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat paket Manual'),
      ),
      body: Obx(() => Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep.value,
            onStepContinue: () {
              if (_currentStep.value == 0) {
                if (_validateSenderForm()) {
                  _currentStep.value++;
                }
              } else if (_currentStep.value == 1) {
                if (_validateRecipientForm()) {
                  _currentStep.value++;
                }
              } else if (_currentStep.value == 2) {
                if (_validateProductSelection()) {
                  _currentStep.value++;
                }
              } else if (_currentStep.value == 3) {
                if (_validateShippingAddress()) {
                  _currentStep.value++;
                }
              } else if (_currentStep.value == 4) {
                _submitOrder();
              }
            },
            onStepCancel: () {
              if (_currentStep.value > 0) {
                _currentStep.value--;
              }
            },
            steps: [
              Step(
                title: const Text('Data Pengirim'),
                content: _buildSenderForm(),
                isActive: _currentStep.value >= 0,
              ),
              Step(
                title: const Text('Data Penerima'),
                content: _buildRecipientForm(),
                isActive: _currentStep.value >= 1,
              ),
              Step(
                title: const Text('Pilih Produk'),
                content: _buildProductSelection(),
                isActive: _currentStep.value >= 2,
              ),
              Step(
                title: const Text('Alamat Pengiriman'),
                content: _buildShippingAddress(),
                isActive: _currentStep.value >= 3,
              ),
              Step(
                title: const Text('Kalkulasi Biaya'),
                content: _buildCostCalculation(),
                isActive: _currentStep.value >= 4,
              ),
            ],
          )),
    );
  }

  Widget _buildSenderForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: senderNameController,
            decoration: const InputDecoration(labelText: 'Nama Pengirim'),
            validator: (value) =>
                value?.isEmpty ?? true ? 'Nama wajib diisi' : null,
          ),
          TextFormField(
            controller: senderPhoneController,
            decoration: const InputDecoration(labelText: 'No. HP Pengirim'),
            keyboardType: TextInputType.phone,
            validator: (value) =>
                value?.isEmpty ?? true ? 'No. HP wajib diisi' : null,
          ),
          TextFormField(
            controller: senderAddressController,
            decoration: const InputDecoration(labelText: 'Alamat Pengirim'),
            maxLines: 3,
            validator: (value) =>
                value?.isEmpty ?? true ? 'Alamat wajib diisi' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientForm() {
    return Form(
      child: Column(
        children: [
          TextFormField(
            controller: recipientNameController,
            decoration: const InputDecoration(
              labelText: 'Nama Penerima',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: recipientPhoneController,
            decoration: const InputDecoration(
              labelText: 'No. HP Penerima',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) => value?.isEmpty ?? true ? 'Wajib diisi' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildProductSelection() {
    return Column(
      children: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
              .from('products')
              .stream(primaryKey: ['id']).order('name'),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final product = snapshot.data![index];
                return Card(
                  child: ListTile(
                    title: Text(product['name']),
                    subtitle: Text('Rp ${product['price']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () => _updateQuantity(product, false),
                        ),
                        Text('${quantities[product['id']] ?? 0}'),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _updateQuantity(product, true),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        Obx(() => Text(
              'Subtotal: Rp ${subtotal.value}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            )),
      ],
    );
  }

  Widget _buildShippingAddress() {
    return Column(
      children: [
        TextFormField(
          controller: recipientAddressController,
          decoration: const InputDecoration(
            labelText: 'Alamat Lengkap',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          validator: (value) => value?.isEmpty ?? true ? 'Wajib diisi' : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCostCalculation() {
    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Berat: ${totalWeight.value / 1000} kg'),
            const SizedBox(height: 8),
            Text('Biaya Pengiriman: Rp ${shippingCost.value}'),
            const SizedBox(height: 8),
            Text('Subtotal Produk: Rp ${subtotal.value}'),
            const Divider(),
            Text(
              'Total: Rp ${subtotal.value + shippingCost.value}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ));
  }

  void _updateQuantity(Map<String, dynamic> product, bool increment) {
    final productId = product['id'];
    final currentQty = quantities[productId] ?? 0;

    if (increment) {
      quantities[productId] = currentQty + 1;
      if (currentQty == 0) {
        selectedProducts.add(product);
      }
    } else if (currentQty > 0) {
      quantities[productId] = currentQty - 1;
      if (currentQty == 1) {
        selectedProducts.removeWhere((p) => p['id'] == productId);
      }
    }

    _calculateSubtotal();
  }

  void _calculateSubtotal() {
    double total = 0;
    int weight = 0;

    for (var product in selectedProducts) {
      final quantity = quantities[product['id']] ?? 0;
      total += (product['price'] ?? 0) * quantity;
      weight += ((product['weight'] as num? ?? 1000) * quantity).toInt();
    }

    subtotal.value = total;
    totalWeight.value = weight;
  }

  Future<void> _submitOrder() async {
    try {
      if (selectedProducts.isEmpty) {
        throw 'Pilih minimal 1 produk';
      }

      // 1. Dapatkan branch_id
      final branchData = await supabase
          .from('branches')
          .select('id')
          .eq('user_id', authController.currentUser.value!.id)
          .single();

      // 2. Buat branch order baru
      final orderData = await supabase
          .from('branch_orders')
          .insert({
            'branch_id': branchData['id'],
            'buyer_id': authController.currentUser.value!.id,
            'status': 'pending',
            'total_amount': subtotal.value,
            'shipping_address': recipientAddressController.text,
          })
          .select()
          .single();

      // 3. Buat shipping details dan branch order items
      await Future.wait<dynamic>([
        // Insert branch shipping details
        supabase.from('branch_shipping_details').insert({
          'branch_order_id': orderData['id'],
          'sender_name': senderNameController.text,
          'sender_phone': senderPhoneController.text,
          'sender_address': {
            'full_address': senderAddressController.text,
          },
          'recipient_name': recipientNameController.text,
          'recipient_phone': recipientPhoneController.text,
          'recipient_address': {
            'full_address': recipientAddressController.text,
          },
          'branch_id': branchData['id'],
        }),

        // Insert branch order items
        ...selectedProducts.map((product) async {
          final quantity = quantities[product['id']] ?? 0;
          await supabase.from('branch_order_items').insert({
            'branch_order_id': orderData['id'],
            'product_id': product['id'],
            'quantity': quantity,
            'price': product['price'],
          });
        }),
      ]);

      Get.snackbar(
        'Sukses',
        'Pesanan berhasil dibuat',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      Get.back();
    } catch (e) {
      print('Error detail: $e');
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  bool _validateSenderForm() {
    if (senderNameController.text.isEmpty) {
      Get.snackbar('Error', 'Nama pengirim wajib diisi',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    if (senderPhoneController.text.isEmpty) {
      Get.snackbar('Error', 'No. HP pengirim wajib diisi',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    if (senderAddressController.text.isEmpty) {
      Get.snackbar('Error', 'Alamat pengirim wajib diisi',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    return true;
  }

  bool _validateRecipientForm() {
    if (recipientNameController.text.isEmpty) {
      Get.snackbar('Error', 'Nama penerima wajib diisi',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    if (recipientPhoneController.text.isEmpty) {
      Get.snackbar('Error', 'No. HP penerima wajib diisi',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    return true;
  }

  bool _validateProductSelection() {
    if (selectedProducts.isEmpty) {
      Get.snackbar('Error', 'Pilih minimal 1 produk',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    return true;
  }

  bool _validateShippingAddress() {
    if (recipientAddressController.text.isEmpty) {
      Get.snackbar('Error', 'Alamat pengiriman wajib diisi',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    recipientNameController.dispose();
    recipientPhoneController.dispose();
    recipientAddressController.dispose();
    super.dispose();
  }
}
