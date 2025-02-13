import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../controllers/order_controller.dart';

final supabase = Supabase.instance.client;

class DetailPesananScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const DetailPesananScreen({super.key, required this.order});

  @override
  State<DetailPesananScreen> createState() => _DetailPesananScreenState();
}

class _DetailPesananScreenState extends State<DetailPesananScreen> {
  String formatDate(String date) {
    final DateTime dateTime = DateTime.parse(date);
    return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'pending_cancellation':
        return Colors.orange.shade700;
      case 'processing':
        return Colors.blue;
      case 'shipping':
        return Colors.blue.shade700;
      case 'delivered':
        return Colors.green;
      case 'completed':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  double calculateSubtotal(List items) {
    return items.fold(0.0, (sum, item) {
      final quantity = item['total_amount'] ?? 0;
      final price = double.tryParse(item['price'].toString()) ?? 0.0;
      return sum + (quantity * price);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order['items'] ?? [];
    final status = widget.order['status'] ?? 'pending';
    final shippingAddress =
        widget.order['shipping_address'] ?? 'Alamat tidak tersedia';
    final shippingCost =
        double.tryParse(widget.order['shipping_cost'].toString()) ?? 0.0;
    final totalAmount =
        double.tryParse(widget.order['total_amount'].toString()) ?? 0.0;
    final subtotal = totalAmount;
    final totalPayment = totalAmount + shippingCost;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: AppTheme.primary,
        title: Text(
          'Detail Pesanan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status Pesanan
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status Pesanan',
                    style: AppTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: AppTheme.textTheme.bodyMedium?.copyWith(
                        color: getStatusColor(status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Progress Status
                  Row(
                    children: [
                      _buildStatusStep(
                        icon: Icons.pending_actions,
                        label: 'Menunggu',
                        isActive: [
                          'pending',
                          'processing',
                          'shipping',
                          'delivered',
                          'completed'
                        ].contains(status.toLowerCase()),
                        isCompleted: [
                          'processing',
                          'shipping',
                          'delivered',
                          'completed'
                        ].contains(status.toLowerCase()),
                      ),
                      _buildStatusLine(
                        isActive: [
                          'processing',
                          'shipping',
                          'delivered',
                          'completed'
                        ].contains(status.toLowerCase()),
                      ),
                      _buildStatusStep(
                        icon: Icons.inventory_2,
                        label: 'Dikemas',
                        isActive: [
                          'processing',
                          'shipping',
                          'delivered',
                          'completed'
                        ].contains(status.toLowerCase()),
                        isCompleted: ['shipping', 'delivered', 'completed']
                            .contains(status.toLowerCase()),
                      ),
                      _buildStatusLine(
                        isActive: ['shipping', 'delivered', 'completed']
                            .contains(status.toLowerCase()),
                      ),
                      _buildStatusStep(
                        icon: Icons.local_shipping,
                        label: 'Dikirim',
                        isActive: ['shipping', 'delivered', 'completed']
                            .contains(status.toLowerCase()),
                        isCompleted: ['delivered', 'completed']
                            .contains(status.toLowerCase()),
                      ),
                      _buildStatusLine(
                        isActive: ['delivered', 'completed']
                            .contains(status.toLowerCase()),
                      ),
                      _buildStatusStep(
                        icon: Icons.check_circle,
                        label: 'Selesai',
                        isActive: ['delivered', 'completed']
                            .contains(status.toLowerCase()),
                        isCompleted:
                            ['completed'].contains(status.toLowerCase()),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Produk yang Dipesan
            if (items.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Produk yang Dipesan',
                      style: AppTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final product = item['product'] ?? {};
                        final productName =
                            product['name'] ?? 'Produk tidak tersedia';
                        final productImage = product['image_url'] ?? '';
                        final quantity = item['quantity'] ?? 0;
                        final price =
                            double.tryParse(item['price'].toString()) ?? 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Gambar Produk
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: productImage.isNotEmpty
                                    ? Image.network(
                                        productImage,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[200],
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                    : null,
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return _buildImageError();
                                        },
                                      )
                                    : _buildImageError(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      productName,
                                      style: AppTheme.textTheme.bodyMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$quantity x Rp ${NumberFormat('#,###').format(price)}',
                                      style: AppTheme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total: Rp ${NumberFormat('#,###').format(quantity * price)}',
                                      style: AppTheme.textTheme.bodyMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

            // Informasi Pengiriman
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informasi Pengiriman',
                    style: AppTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Debug print
                      Builder(builder: (context) {
                        print('Order Items: ${widget.order['order_items']}');
                        print(
                            'Product Image: ${widget.order['order_items'][0]['products']['image_url']}');
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            widget.order['order_items'][0]['products']
                                    ['image_url']
                                .toString()
                                .replaceAll(RegExp(r'[\[\]"]'), '')
                                .split(',')[0],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading image: $error');
                              return Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[200],
                                child: Icon(Icons.image_not_supported,
                                    color: Colors.grey[400]),
                              );
                            },
                          ),
                        );
                      }),
                      const SizedBox(width: 12),
                      // Informasi Produk
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                                'Produk',
                                widget.order['order_items'][0]['products']
                                    ['name']),
                            const SizedBox(height: 8),
                            _buildInfoRow('Jumlah',
                                '${widget.order['order_items'][0]['quantity']} pcs'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Alamat', shippingAddress),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                      'Kurir',
                      widget.order['shipping_method'] ??
                          'Kurir tidak tersedia'),
                ],
              ),
            ),

            // Rincian Pembayaran
            _buildPaymentSummary(),

            // Bukti Pembayaran
            _buildPaymentProof(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[200],
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(String label, num amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.textTheme.bodyMedium?.copyWith(
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          'Rp ${NumberFormat('#,###').format(amount)}',
          style: AppTheme.textTheme.bodyMedium?.copyWith(
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            color: isTotal ? AppTheme.primary : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSummary() {
    final items = widget.order['items'] ?? [];
    final shippingCost =
        double.tryParse(widget.order['shipping_cost'].toString()) ?? 0.0;
    final totalAmount =
        double.tryParse(widget.order['total_amount'].toString()) ?? 0.0;
    final paymentGroupId = widget.order['payment_group_id'];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rincian Pembayaran',
            style: AppTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentRow('Subtotal Produk', totalAmount),
          const SizedBox(height: 8),
          _buildPaymentRow(
              'Biaya Pengiriman\nAkumulasi per chekout', shippingCost),
          FutureBuilder<Map<String, dynamic>?>(
            future: _fetchPaymentGroupDetails(paymentGroupId),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final adminFee =
                    double.tryParse(snapshot.data!['admin_fee'].toString()) ??
                        0.0;
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildPaymentRow('Biaya Admin', adminFee),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(),
                    ),
                    _buildPaymentRow('Total Pembayaran',
                        totalAmount + shippingCost + adminFee,
                        isTotal: true),
                  ],
                );
              }
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(),
                  ),
                  _buildPaymentRow(
                      'Total Pembayaran', totalAmount + shippingCost,
                      isTotal: true),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchPaymentGroupDetails(
      String? paymentGroupId) async {
    if (paymentGroupId == null) return null;

    try {
      final response = await supabase
          .from('payment_groups')
          .select()
          .eq('id', paymentGroupId)
          .single();

      print('Payment Group Details: $response'); // Debug print
      return response;
    } catch (e) {
      print('Error fetching payment group details: $e');
      return null;
    }
  }

  Widget _buildPaymentProof() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bukti Pembayaran',
            style: AppTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>?>(
            future: _fetchPaymentInfo(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final paymentInfo = snapshot.data;
              final paymentProof = paymentInfo?['payment_proof'];
              final paymentGroupId = paymentInfo?['id'];

              print('Payment Info: $paymentInfo'); // Debug print
              print('Payment Proof: $paymentProof'); // Debug print
              print('Payment Group ID: $paymentGroupId'); // Debug print

              if (paymentProof != null && paymentProof.isNotEmpty) {
                return InkWell(
                  onTap: () => Get.to(() => ImageViewScreen(
                        imageUrl: paymentProof,
                        tag: 'payment_proof',
                      )),
                  child: Hero(
                    tag: 'payment_proof',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        paymentProof,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading image: $error');
                          return Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey[200],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text('Gagal memuat gambar',
                                    style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              } else if (paymentGroupId != null) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'Belum ada bukti pembayaran',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _uploadPaymentProof(paymentGroupId),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Bukti Pembayaran'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchPaymentInfo() async {
    try {
      // Ambil data payment_groups dari order
      final paymentGroups = widget.order['payment_groups'];
      print('Full Order Data: ${widget.order}');
      print('Payment Groups Data: $paymentGroups');

      if (paymentGroups == null) {
        // Jika tidak ada di order, ambil dari database
        final response = await supabase
            .from('payment_groups')
            .select()
            .eq('id', widget.order['payment_group_id'])
            .single();

        print('Payment Groups from DB: $response');
        return response;
      }

      return paymentGroups;
    } catch (e) {
      print('Error fetching payment info: $e');
      return null;
    }
  }

  Future<void> _uploadPaymentProof(String paymentGroupId) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      // Baca file sebagai bytes
      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // Upload ke storage
      await supabase.storage
          .from('payment-proofs')
          .uploadBinary(fileName, bytes);

      // Dapatkan URL publik
      final imageUrl =
          supabase.storage.from('payment-proofs').getPublicUrl(fileName);

      // Update payment_proof
      final updatedPaymentGroup = await supabase
          .from('payment_groups')
          .update({'payment_proof': imageUrl})
          .eq('id', paymentGroupId)
          .select()
          .single();

      // Update widget.order dengan data terbaru
      setState(() {
        if (widget.order['payment_groups'] != null) {
          widget.order['payment_groups']['payment_proof'] = imageUrl;
        }
      });

      print('Updated Payment Group: $updatedPaymentGroup');

      Get.snackbar(
        'Berhasil',
        'Bukti pembayaran berhasil diupload',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Refresh OrderController untuk memperbarui data di halaman PesananSaya
      final orderController = Get.put(OrderController());
      await orderController.fetchOrders();
    } catch (e) {
      print('Error uploading payment proof: $e');
      Get.snackbar(
        'Gagal',
        'Terjadi kesalahan saat mengupload bukti pembayaran',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildStatusStep({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primary : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTheme.textTheme.bodySmall?.copyWith(
              color: isActive ? AppTheme.primary : Colors.grey,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLine({required bool isActive}) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? AppTheme.primary : Colors.grey[300],
      ),
    );
  }
}

class ImageViewScreen extends StatelessWidget {
  final String imageUrl;
  final String tag;

  const ImageViewScreen({
    Key? key,
    required this.imageUrl,
    required this.tag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: tag,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
