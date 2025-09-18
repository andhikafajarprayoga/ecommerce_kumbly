import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../checkout/edit_address_screen.dart';
import 'custom_address_screen.dart';
import 'detail_pengiriman_screen.dart';

class KirimBarangScreen extends StatefulWidget {
  @override
  _KirimBarangScreenState createState() => _KirimBarangScreenState();
}

class _KirimBarangScreenState extends State<KirimBarangScreen> {
  final supabase = Supabase.instance.client;
  
  // Data alamat
  List<Map<String, dynamic>> userAddresses = [];
  Map<String, dynamic>? alamatPengirim;
  Map<String, dynamic>? alamatPenerima;
  
  bool isLoadingAddresses = false;

  @override
  void initState() {
    super.initState();
    // Cek login
    if (supabase.auth.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.dialog(
        AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
          Icon(Icons.lock_outline, color: AppTheme.primary),
          SizedBox(width: 8),
          Text('Login Diperlukan', style: TextStyle(color: AppTheme.primary)),
          ],
        ),
        content: Text(
          'Silakan login dahulu untuk menggunakan fitur Kirim Barang.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
          onPressed: () {
            Get.back(); // tutup dialog
            Get.back(); // kembali ke halaman sebelumnya
          },
          child: Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Get.back(); // tutup dialog
            Get.offAllNamed('/login');
          },
          child: Text('Login'),
          ),
        ],
        ),
        barrierDismissible: false,
      );
      });
      return;
    }
    fetchUserAddresses();
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
        if (response['address2'] != null) userAddresses.add(response['address2']);
        if (response['address3'] != null) userAddresses.add(response['address3']);
        if (response['address4'] != null) userAddresses.add(response['address4']);

        // Set alamat pengirim default
        if (userAddresses.isNotEmpty) {
          alamatPengirim = Map<String, dynamic>.from(userAddresses[0]);
        }
      });
    } catch (e) {
      print('Error fetching addresses: $e');
    }
    setState(() => isLoadingAddresses = false);
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
        title: Text('Kirim Barang'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: isLoadingAddresses
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Langkah 1 dari 2',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Pilih Alamat Pengiriman',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  SizedBox(height: 32),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildAddressSelector(
                            title: 'Alamat Pengirim',
                            selectedAddress: alamatPengirim,
                            onTap: () => _showAddressSelector(true),
                            isRequired: true,
                          ),
                          SizedBox(height: 32),
                          
                          _buildAddressSelector(
                            title: 'Alamat Penerima',
                            selectedAddress: alamatPenerima,
                            onTap: () => _showAddressSelector(false),
                            isRequired: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: alamatPengirim != null && alamatPenerima != null
                          ? _lanjutKeDetailPengiriman
                          : null,
                      child: Text('Lanjut ke Detail Pengiriman'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAddressSelector({
    required String title,
    required Map<String, dynamic>? selectedAddress,
    required VoidCallback onTap,
    required bool isRequired,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title, 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
          ],
        ),
        SizedBox(height: 12),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: selectedAddress != null 
                    ? AppTheme.primary 
                    : Colors.grey.shade300,
                width: selectedAddress != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: selectedAddress != null 
                  ? AppTheme.primaryLight.withOpacity(0.1)
                  : Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  selectedAddress != null 
                      ? Icons.location_on 
                      : Icons.location_on_outlined,
                  color: selectedAddress != null 
                      ? AppTheme.primary 
                      : Colors.grey,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedAddress != null 
                            ? 'Alamat Dipilih'
                            : 'Pilih $title',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: selectedAddress != null 
                              ? AppTheme.primary 
                              : Colors.grey,
                        ),
                      ),
                      if (selectedAddress != null) ...[
                        SizedBox(height: 4),
                        Text(
                          parseAddress(selectedAddress),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_right,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddressSelector(bool isPengirim) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pilih Alamat ${isPengirim ? "Pengirim" : "Penerima"}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Divider(height: 1),
            
            // Alamat tersimpan
            ...userAddresses.map((address) => InkWell(
              onTap: () {
                setState(() {
                  if (isPengirim) {
                    alamatPengirim = Map<String, dynamic>.from(address);
                  } else {
                    alamatPenerima = Map<String, dynamic>.from(address);
                  }
                });
                Navigator.pop(context);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: Colors.grey[600]),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(parseAddress(Map<String, dynamic>.from(address))),
                    ),
                  ],
                ),
              ),
            )).toList(),
            
            Divider(height: 1),
            
            // Alamat dari database lain (jika ada)
            InkWell(
              onTap: () async {
                Navigator.pop(context);
                final newAddress = await Get.to(() => EditAddressScreen(
                  initialAddress: '',
                  onSave: (Map<String, dynamic> addressDetails) {},
                ));
                
                if (newAddress != null) {
                  setState(() {
                    if (isPengirim) {
                      alamatPengirim = newAddress;
                    } else {
                      alamatPenerima = newAddress;
                    }
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Icon(Icons.add_location_alt_outlined, color: const Color.fromARGB(255, 0, 214, 96)),
                    SizedBox(width: 12),
                    Text('Gunakan Maps', 
                         style: TextStyle(color: const Color.fromARGB(255, 0, 182, 30))),
                  ],
                ),
              ),
            ),
            
            Divider(height: 1),
            
            // Custom alamat dengan maps
            
          ],
        ),
      ),
    );
  }

  void _lanjutKeDetailPengiriman() {
    Get.to(() => DetailPengirimanScreen(
      alamatPengirim: alamatPengirim!,
      alamatPenerima: alamatPenerima!,
    ));
  }

  @override
  void dispose() {
    super.dispose();
  }
}
