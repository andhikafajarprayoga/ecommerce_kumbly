import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math' show cos, sqrt, asin, pi, sin;
import '../home_screen.dart';
import 'shipping_payment_screen.dart';

class DetailPengirimanScreen extends StatefulWidget {
  final Map<String, dynamic> alamatPengirim;
  final Map<String, dynamic> alamatPenerima;

  const DetailPengirimanScreen({
    Key? key,
    required this.alamatPengirim,
    required this.alamatPenerima,
  }) : super(key: key);

  @override
  _DetailPengirimanScreenState createState() => _DetailPengirimanScreenState();
}

class _DetailPengirimanScreenState extends State<DetailPengirimanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaBarangController = TextEditingController();
  final _beratController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _namaPengirimController = TextEditingController();
  final _teleponPengirimController = TextEditingController();
  final _namaPenerimaController = TextEditingController();
  final _teleponPenerimaController = TextEditingController();
  
  final supabase = Supabase.instance.client;
  
  // Data dari database
  List<Map<String, dynamic>> shippingMethods = [];
  Map<String, dynamic>? selectedShippingMethod;
  List<Map<String, dynamic>> paymentMethods = [];
  String? paymentMethod;
  double adminFee = 0;
  bool isLoadingPayments = false;
  bool isLoadingShipping = false;
  double ongkirTotal = 0;

  String _jenisBarang = 'Dokumen';
  bool _asuransi = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await fetchShippingMethods();
    await fetchPaymentMethods();
    await _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('users')
            .select('full_name, phone')
            .eq('id', user.id)
            .single();
        
        setState(() {
          _namaPengirimController.text = response['full_name'] ?? '';
          _teleponPengirimController.text = response['phone'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> fetchShippingMethods() async {
    setState(() => isLoadingShipping = true);
    try {
      final response = await supabase
          .from('pengiriman')
          .select('id_pengiriman, nama_pengiriman, harga_per_kg, harga_per_km, is_reguler');

      setState(() {
        // Hanya tampilkan pengiriman dengan is_reguler = false (khusus pengiriman barang)
        shippingMethods = List<Map<String, dynamic>>.from(
          response.where((m) => m['is_reguler'] == false)
        );
        if (shippingMethods.isNotEmpty) {
          selectedShippingMethod = shippingMethods[0];
        }
      });
    } catch (e) {
      print('Error fetching shipping methods: $e');
    }
    setState(() => isLoadingShipping = false);
  }

  Future<void> fetchPaymentMethods() async {
    setState(() => isLoadingPayments = true);
    try {
      final response = await supabase
          .from('payment_methods')
          .select()
          .eq('is_active', true);
      
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

  Future<void> calculateShippingCost() async {
    if (selectedShippingMethod == null) {
      setState(() => ongkirTotal = 0);
      return;
    }

    try {
      double berat = double.tryParse(_beratController.text) ?? 0;
      if (berat <= 0) {
        setState(() => ongkirTotal = 0);
        return;
      }

      // Koordinat pengirim
      double pengirimLat = double.parse(widget.alamatPengirim['latitude']);
      double pengirimLon = double.parse(widget.alamatPengirim['longitude']);
      
      // Koordinat penerima
      double penerimaLat = double.parse(widget.alamatPenerima['latitude']);
      double penerimaLon = double.parse(widget.alamatPenerima['longitude']);

      // Hitung jarak
      double jarak = calculateDistance(pengirimLat, pengirimLon, penerimaLat, penerimaLon);

      // Tarif dari database
      final perKg = double.parse(selectedShippingMethod!['harga_per_kg'].toString());
      final perKm = double.parse(selectedShippingMethod!['harga_per_km'].toString());

      // Hitung ongkir
      double ongkirBerat = perKg * berat;
      double ongkirJarak = perKm * jarak;
      double total = ongkirBerat + ongkirJarak;
      
      // Minimum ongkir 5000
      total = total < 5000 ? 5000 : total;
      
      // Tambah asuransi jika dipilih
      if (_asuransi) {
        total += 2000;
      }

      // Tambah admin fee jika ada
      total += adminFee;

      setState(() {
        ongkirTotal = total;
      });
    } catch (e) {
      print('Error calculating shipping cost: $e');
      setState(() => ongkirTotal = 0);
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  String parseAddress(Map<String, dynamic> addressJson) {
    try {
      List<String> addressParts = [];
      if (addressJson['street']?.isNotEmpty == true)
        addressParts.add(addressJson['street']);
      if (addressJson['village']?.isNotEmpty == true)
        addressParts.add("Desa ${addressJson['village']}");
      if (addressJson['district']?.isNotEmpty == true)
        addressParts.add("Kec. ${addressJson['district']}");
      if (addressJson['city']?.isNotEmpty == true)
        addressParts.add(addressJson['city']);
      if (addressJson['province']?.isNotEmpty == true)
        addressParts.add(addressJson['province']);
      if (addressJson['postal_code']?.isNotEmpty == true)
        addressParts.add(addressJson['postal_code']);
      return addressParts.where((part) => part.isNotEmpty).join(', ');
    } catch (e) {
      return 'Format alamat tidak valid';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Pengiriman'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Langkah 2 dari 2',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Detail Pengiriman',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              SizedBox(height: 24),

              _buildSectionTitle('Informasi Barang'),
              _buildTextField(
                controller: _namaBarangController,
                label: 'Nama Barang',
                hint: 'Masukkan nama barang',
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Nama barang tidak boleh kosong';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      value: _jenisBarang,
                      label: 'Jenis Barang',
                      items: ['Dokumen', 'Paket', 'Elektronik', 'Makanan', 'Lainnya'],
                      onChanged: (value) => setState(() => _jenisBarang = value!),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _beratController,
                      label: 'Berat (kg)',
                      hint: '0.5',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Berat tidak boleh kosong';
                        }
                        return null;
                      },
                      onChanged: (value) => calculateShippingCost(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              _buildTextField(
                controller: _deskripsiController,
                label: 'Deskripsi (Opsional)',
                hint: 'Deskripsi tambahan...',
                maxLines: 3,
              ),
              SizedBox(height: 24),

              _buildSectionTitle('Data Pengirim'),
              _buildTextField(
                controller: _namaPengirimController,
                label: 'Nama Pengirim',
                hint: 'Masukkan nama pengirim',
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Nama pengirim tidak boleh kosong';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              _buildTextField(
                controller: _teleponPengirimController,
                label: 'No. Telepon Pengirim',
                hint: '08xxxxxxxxxx',
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'No. telepon tidak boleh kosong';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              _buildAddressDisplay('Alamat Pengirim', widget.alamatPengirim),
              SizedBox(height: 24),

              _buildSectionTitle('Data Penerima'),
              _buildTextField(
                controller: _namaPenerimaController,
                label: 'Nama Penerima',
                hint: 'Masukkan nama penerima',
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Nama penerima tidak boleh kosong';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              _buildTextField(
                controller: _teleponPenerimaController,
                label: 'No. Telepon Penerima',
                hint: '08xxxxxxxxxx',
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'No. telepon tidak boleh kosong';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              _buildAddressDisplay('Alamat Penerima', widget.alamatPenerima),
              SizedBox(height: 24),

              _buildSectionTitle('Layanan Pengiriman'),
              if (isLoadingShipping)
                Center(child: CircularProgressIndicator())
              else
                _buildShippingMethodSelector(),
              SizedBox(height: 16),
              
              CheckboxListTile(
                title: Text('Asuransi Pengiriman'),
                subtitle: Text('Perlindungan tambahan untuk barang Anda (+ Rp 2.000)'),
                value: _asuransi,
                onChanged: (value) {
                  setState(() => _asuransi = value ?? false);
                  calculateShippingCost();
                },
                activeColor: AppTheme.primary,
              ),
              SizedBox(height: 20),

              _buildSectionTitle('Metode Pembayaran'),
              if (isLoadingPayments)
                Center(child: CircularProgressIndicator())
              else
                _buildPaymentMethodSelector(),
              SizedBox(height: 32),

              _buildEstimasiHarga(),
              SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: Text('Kirim Sekarang'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressDisplay(String title, Map<String, dynamic> address) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryLight),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  parseAddress(address),
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShippingMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<Map<String, dynamic>>(
          value: selectedShippingMethod,
          decoration: InputDecoration(
            labelText: 'Pilih Layanan Pengiriman',
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primary),
            ),
          ),
          items: shippingMethods.map((method) {
            String label =
                '${method['nama_pengiriman']} (Rp ${NumberFormat('#,###').format(method['harga_per_kg'])}/kg, Rp ${NumberFormat('#,###').format(method['harga_per_km'])}/km)';
            return DropdownMenuItem(
              value: method,
              child: Text(label, style: TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => selectedShippingMethod = value);
            calculateShippingCost();
          },
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector() {
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
            if (paymentMethods.isEmpty)
              Center(
                child: Text(
                  'Tidak ada metode pembayaran tersedia',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              )
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
                      // Gabungkan semua info dalam satu baris
                      String info = method['name'];
                      if (method['account_number'] != null && method['account_number'].toString().isNotEmpty) {
                        info +=
                            ' - ${method['account_number']} (${method['account_name']})';
                      }
                      info +=
                          ' - Admin: Rp ${NumberFormat('#,###').format(method['admin'])}';
                      return DropdownMenuItem(
                        value: method['id'].toString(),
                        child: Text(
                          info,
                          style: TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        paymentMethod = value!;
                        final method = paymentMethods.firstWhere(
                          (m) => m['id'].toString() == value
                        );
                        adminFee = double.parse(method['admin'].toString());
                      });
                      calculateShippingCost(); // Recalculate total dengan admin fee baru
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimasiHarga() {
    double berat = double.tryParse(_beratController.text) ?? 0;
    
    if (ongkirTotal == 0 || selectedShippingMethod == null) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          'Lengkapi data untuk melihat estimasi biaya',
          style: TextStyle(color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Hitung komponen biaya
    double jarak = 0;
    double ongkirBerat = 0;
    double ongkirJarak = 0;
    
    try {
      double pengirimLat = double.parse(widget.alamatPengirim['latitude']);
      double pengirimLon = double.parse(widget.alamatPengirim['longitude']);
      double penerimaLat = double.parse(widget.alamatPenerima['latitude']);
      double penerimaLon = double.parse(widget.alamatPenerima['longitude']);
      jarak = calculateDistance(pengirimLat, pengirimLon, penerimaLat, penerimaLon);
      
      final perKg = double.parse(selectedShippingMethod!['harga_per_kg'].toString());
      final perKm = double.parse(selectedShippingMethod!['harga_per_km'].toString());
      ongkirBerat = perKg * berat;
      ongkirJarak = perKm * jarak;
    } catch (_) {}

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimasi Biaya Pengiriman',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          SizedBox(height: 12),
          _buildCostDetail('Layanan', selectedShippingMethod!['nama_pengiriman']),
          _buildCostDetail('Jarak', '${jarak.toStringAsFixed(2)} km'),
          _buildCostDetail('Berat', '${berat}kg'),
          _buildCostDetail('Ongkir Berat', 'Rp ${NumberFormat('#,###').format(ongkirBerat)}'),
          _buildCostDetail('Ongkir Jarak', 'Rp ${NumberFormat('#,###').format(ongkirJarak)}'),
          if (_asuransi) _buildCostDetail('Asuransi', 'Rp 2.000'),
          if (adminFee > 0) _buildCostDetail('Biaya Admin', 'Rp ${NumberFormat('#,###').format(adminFee)}'),
          Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Estimasi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Rp ${NumberFormat('#,###').format(ongkirTotal)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostDetail(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primary),
        ),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdown({
    required String value,
    required String label,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primary),
        ),
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item),
      )).toList(),
      onChanged: onChanged,
    );
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      if (paymentMethod == null) {
        Get.snackbar(
          'Error',
          'Pilih metode pembayaran terlebih dahulu.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.local_shipping, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Konfirmasi Pengiriman', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(),
              Text(
                'Apakah Anda yakin ingin mengirim barang dengan detail berikut?',
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
              SizedBox(height: 16),
              _buildConfirmRow('Nama Barang', _namaBarangController.text),
              _buildConfirmRow('Jenis Barang', _jenisBarang),
              _buildConfirmRow('Berat', '${_beratController.text} kg'),
              _buildConfirmRow('Layanan', selectedShippingMethod!['nama_pengiriman']),
              _buildConfirmRow('Pembayaran', paymentMethods.firstWhere((m) => m['id'].toString() == paymentMethod)['name']),
              _buildConfirmRow('Asuransi', _asuransi ? 'Ya (+Rp 2.000)' : 'Tidak'),
              _buildConfirmRow('Total Biaya', 'Rp ${NumberFormat('#,###').format(ongkirTotal)}'),
              SizedBox(height: 8),
              Divider(),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Pastikan data sudah benar sebelum melanjutkan.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Batal', style: TextStyle(color: Colors.grey[700])),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.send, size: 18),
              label: Text('Ya, Kirim'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Get.back();
                await _saveShippingRequest();
              },
            ),
          ],
        ),
      );
    }
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500, color: AppTheme.primary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveShippingRequest() async {
    if (selectedShippingMethod == null) {
      Get.snackbar(
        'Error',
        'Pilih metode pengiriman terlebih dahulu.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    
    if (paymentMethod == null) {
      Get.snackbar(
        'Error',
        'Pilih metode pembayaran terlebih dahulu.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    
    try {
      final response = await supabase.from('shipping_requests').insert({
        'user_id': supabase.auth.currentUser!.id,
        'item_name': _namaBarangController.text,
        'item_type': _jenisBarang,
        'weight': double.parse(_beratController.text),
        'description': _deskripsiController.text,
        'sender_name': _namaPengirimController.text,
        'sender_phone': _teleponPengirimController.text,
        'sender_address': json.encode(widget.alamatPengirim),
        'sender_latitude': widget.alamatPengirim['latitude'],
        'sender_longitude': widget.alamatPengirim['longitude'],
        'receiver_name': _namaPenerimaController.text,
        'receiver_phone': _teleponPenerimaController.text,
        'receiver_address': json.encode(widget.alamatPenerima),
        'receiver_latitude': widget.alamatPenerima['latitude'],
        'receiver_longitude': widget.alamatPenerima['longitude'],
        'shipping_method_id': selectedShippingMethod!['id_pengiriman'],
        'payment_method_id': int.parse(paymentMethod!),
        'insurance': _asuransi,
        'estimated_cost': ongkirTotal,
        'admin_fee': adminFee,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      print('Debug: Shipping request created with ID: ${response['id']}');

      // Cek apakah metode pembayaran adalah COD
      final selectedPaymentMethod = paymentMethods.firstWhere(
        (method) => method['id'].toString() == paymentMethod
      );
      
      final isCOD = selectedPaymentMethod['name'].toString().toLowerCase().contains('cod');
      
      if (isCOD) {
        // Jika COD, tampilkan dialog sukses seperti sebelumnya
        Get.dialog(
          AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 60,
                ),
                SizedBox(height: 8),
                Text(
                  'Pengiriman Berhasil!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Permintaan pengiriman Anda telah berhasil diterima.',
                  style: TextStyle(fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.delivery_dining, color: Colors.blue, size: 24),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kurir sedang dalam perjalanan ke lokasi Anda',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Pembayaran akan dilakukan saat barang sampai (COD).',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Get.back(); // Tutup dialog
                    Get.offAll(() => BuyerHomeScreen());
                  },
                  child: Text(
                    'Kembali ke Beranda',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
          barrierDismissible: false,
        );
      } else {
        // Jika bukan COD, arahkan ke halaman pembayaran
        Get.snackbar(
          'Berhasil!',
          'Permintaan kirim barang telah diterima. Silakan lakukan pembayaran.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        
        // Siapkan data untuk shipping payment screen
        Map<String, dynamic> shippingData = {
          'id': response['id'], // Pastikan ID ada
          'item_name': response['item_name'],
          'estimated_cost': response['estimated_cost'],
          'shipping_method_name': selectedShippingMethod!['nama_pengiriman'],
        };
        
        print('Debug: Navigating to ShippingPaymentScreen with data: $shippingData');
        
        Get.off(() => ShippingPaymentScreen(
          shippingData: shippingData,
          paymentMethod: selectedPaymentMethod,
        ));
      }
    } catch (e) {
      print('Error saving shipping request: $e');
      Get.snackbar(
        'Error',
        'Gagal menyimpan permintaan. Silakan coba lagi.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  void dispose() {
    _namaBarangController.dispose();
    _beratController.dispose();
    _deskripsiController.dispose();
    _namaPengirimController.dispose();
    _teleponPengirimController.dispose();
    _namaPenerimaController.dispose();
    _teleponPenerimaController.dispose();
    super.dispose();
  }
}

