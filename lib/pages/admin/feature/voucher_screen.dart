import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class VoucherScreen extends StatefulWidget {
  @override
  _VoucherScreenState createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  final supabase = Supabase.instance.client;
  final _shippingFormKey = GlobalKey<FormState>();
  final _discountFormKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _rateController = TextEditingController();
  final _minPurchaseController = TextEditingController();
  final _maxDiscountController = TextEditingController();
  String _selectedType = 'shipping';

  @override
  void dispose() {
    _codeController.dispose();
    _rateController.dispose();
    _minPurchaseController.dispose();
    _maxDiscountController.dispose();
    super.dispose();
  }

  Future<void> _addVoucher() async {
    final formKey =
        _selectedType == 'shipping' ? _shippingFormKey : _discountFormKey;
    if (!formKey.currentState!.validate()) return;

    try {
      final table = _selectedType == 'shipping'
          ? 'shipping_vouchers'
          : 'discount_vouchers';
      final data = {
        'code': _codeController.text.toUpperCase(),
        'rate': double.parse(_rateController.text),
      };

      if (_selectedType == 'discount') {
        data['min_purchase'] = _minPurchaseController.text.isEmpty
            ? 0
            : double.parse(_minPurchaseController.text);
        if (_maxDiscountController.text.isNotEmpty) {
          data['max_discount'] = double.parse(_maxDiscountController.text);
        }
      }

      await supabase.from(table).insert(data);
      Get.snackbar(
        'Sukses',
        'Voucher berhasil ditambahkan',
        backgroundColor: Colors.green.shade400,
        colorText: Colors.white,
        borderRadius: 10,
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: 2),
      );

      _clearForm();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal menambahkan voucher',
        backgroundColor: Colors.red.shade400,
        colorText: Colors.white,
        borderRadius: 10,
        margin: EdgeInsets.all(10),
      );
    }
  }

  Future<void> _deleteVoucher(String id, String type) async {
    try {
      final table =
          type == 'shipping' ? 'shipping_vouchers' : 'discount_vouchers';
      await supabase.from(table).delete().eq('id', id);
      Get.snackbar(
        'Sukses',
        'Voucher berhasil dihapus',
        backgroundColor: Colors.green.shade400,
        colorText: Colors.white,
        borderRadius: 10,
        margin: EdgeInsets.all(10),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal menghapus voucher',
        backgroundColor: Colors.red.shade400,
        colorText: Colors.white,
        borderRadius: 10,
        margin: EdgeInsets.all(10),
      );
    }
  }

  void _clearForm() {
    _codeController.clear();
    _rateController.clear();
    _minPurchaseController.clear();
    _maxDiscountController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Text('Kelola Voucher',
              style: TextStyle(
                  fontWeight: FontWeight.normal, color: Colors.white)),
          backgroundColor: AppTheme.primary,
          foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(width: 3, color: Colors.white),
              insets: EdgeInsets.symmetric(horizontal: 16),
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_shipping),
                    SizedBox(width: 8),
                    Text('Tarif Khusus'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.discount),
                    SizedBox(width: 8),
                    Text('Diskon'),
                  ],
                ),
              ),
            ],
            onTap: (index) {
              setState(() {
                _selectedType = index == 0 ? 'shipping' : 'discount';
                _clearForm();
              });
            },
          ),
        ),
        body: TabBarView(
          children: [
            _buildVoucherTab('shipping'),
            _buildVoucherTab('discount'),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primary, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
      ),
    );
  }

  Widget _buildVoucherTab(String type) {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Form(
              key: type == 'shipping' ? _shippingFormKey : _discountFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tambah Voucher Baru',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildTextField(
                    controller: _codeController,
                    label: 'Kode Voucher',
                    icon: Icons.code,
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Kode tidak boleh kosong'
                        : null,
                  ),
                  _buildTextField(
                    controller: _rateController,
                    label: type == 'shipping' ? 'Nilai Tarif' : 'Nilai Diskon',
                    icon: Icons.money,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Nilai tidak boleh kosong'
                        : null,
                  ),
                  if (type == 'discount') ...[
                    _buildTextField(
                      controller: _minPurchaseController,
                      label: 'Minimal Pembelian',
                      icon: Icons.shopping_cart,
                      keyboardType: TextInputType.number,
                    ),
                    _buildTextField(
                      controller: _maxDiscountController,
                      label: 'Maksimal Diskon (Opsional)',
                      icon: Icons.price_check,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _addVoucher,
                    icon: Icon(Icons.add),
                    label: Text('Tambah Voucher'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase
                  .from(type == 'shipping'
                      ? 'shipping_vouchers'
                      : 'discount_vouchers')
                  .stream(primaryKey: ['id']).order('created_at',
                      ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }

                final vouchers = snapshot.data!;

                if (vouchers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sentiment_dissatisfied,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Belum ada voucher',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: vouchers.length,
                  itemBuilder: (context, index) {
                    final voucher = vouchers[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          child: Icon(
                            type == 'shipping'
                                ? Icons.local_shipping
                                : Icons.discount,
                            color: AppTheme.primary,
                          ),
                        ),
                        title: Text(
                          voucher['code'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 6),
                            Text(
                              type == 'shipping'
                                  ? 'Tarif: Rp ${voucher['rate'].toStringAsFixed(0)}'
                                  : 'Diskon: Rp ${voucher['rate'].toStringAsFixed(0)}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            if (type == 'discount' &&
                                voucher['min_purchase'] != null)
                              Text(
                                'Min. Pembelian: Rp ${voucher['min_purchase'].toStringAsFixed(0)}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            if (type == 'discount' &&
                                voucher['max_discount'] != null)
                              Text(
                                'Maks. Diskon: Rp ${voucher['max_discount'].toStringAsFixed(0)}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: Colors.red.shade400),
                          onPressed: () => _deleteVoucher(voucher['id'], type),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
