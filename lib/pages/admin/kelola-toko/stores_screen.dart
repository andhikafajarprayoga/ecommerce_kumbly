import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/pages/admin/kelola-toko/store_products_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../feature/edit_store_screen.dart';
import 'dart:convert';

class StoresScreen extends StatefulWidget {
  @override
  _StoresScreenState createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> stores = [];
  bool isLoading = true;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchStores();
  }

  Future<void> fetchStores() async {
    try {
      final response = await supabase.from('merchants').select('''
            *,
            users (
              email,
              full_name,
              phone
            )
          ''').order('created_at', ascending: false);

      setState(() {
        stores = (response as List<dynamic>).cast<Map<String, dynamic>>();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching stores: $e');
      setState(() => isLoading = false);
    }
  }

  void searchStores(String query) async {
    try {
      final response = await supabase
          .from('merchants')
          .select('''
            *,
            users (
              email,
              full_name,
              phone
            )
          ''')
          .or('store_name.ilike.%${query}%,store_address.ilike.%${query}%')
          .order('created_at', ascending: false);

      setState(() {
        stores = (response as List<dynamic>).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      print('Error searching stores: $e');
    }
  }

  Future<void> toggleVerification(String id, bool currentStatus) async {
    try {
      await supabase
          .from('merchants')
          .update({'is_verified': !currentStatus}).eq('id', id);

      Get.snackbar(
        'Sukses',
        'Status verifikasi toko berhasil diperbarui',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      fetchStores();
    } catch (e) {
      print('Error toggling verification: $e');
      Get.snackbar(
        'Error',
        'Gagal memperbarui status verifikasi',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> deleteStore(String id) async {
    try {
      await supabase.from('merchants').delete().eq('id', id);

      Get.snackbar(
        'Sukses',
        'Toko berhasil dihapus',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      fetchStores();
    } catch (e) {
      print('Error deleting store: $e');
      Get.snackbar(
        'Error',
        'Gagal menghapus toko',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  String _parseAddress(dynamic address) {
    if (address == null) return 'Alamat belum ditambahkan';

    try {
      Map<String, dynamic> addressMap;
      if (address is String) {
        addressMap = json.decode(address);
      } else {
        addressMap = Map<String, dynamic>.from(address);
      }

      final street = addressMap['street'] ?? '';
      final village = addressMap['village'] ?? '';
      final district = addressMap['district'] ?? '';
      final city = addressMap['city'] ?? '';
      final province = addressMap['province'] ?? '';
      final postalCode = addressMap['postal_code'] ?? '';

      // Menggabungkan dengan format yang lebih mudah dibaca
      return '$street, $village, $district, $city, $province $postalCode'
          .replaceAll(RegExp(r'\s+'), ' ') // Menghapus spasi berlebih
          .replaceAll(', ,', ',') // Menghapus koma berlebih
          .replaceAll(',,', ',')
          .trim();
    } catch (e) {
      print('Error parsing address: $e');
      return 'Format alamat tidak valid';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Toko', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Cari toko...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[400]),
                        onPressed: () {
                          searchController.clear();
                          fetchStores();
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                if (value.isEmpty) {
                  fetchStores();
                } else {
                  searchStores(value);
                }
              },
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : stores.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.store_outlined,
                                size: 70, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Tidak ada toko',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: stores.length,
                        itemBuilder: (context, index) {
                          final store = stores[index];
                          final user = store['users'];
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            margin: EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(16),
                              leading: CircleAvatar(
                                radius: 25,
                                backgroundColor: store['is_verified'] == true
                                    ? Colors.green.shade100
                                    : Colors.grey.shade100,
                                child: Icon(
                                  Icons.store,
                                  size: 30,
                                  color: store['is_verified'] == true
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                              title: Text(
                                store['store_name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 8),
                                  _buildInfoRow(Icons.person,
                                      'Pemilik: ${user['full_name'] ?? 'N/A'}'),
                                  _buildInfoRow(
                                      Icons.email, 'Email: ${user['email']}'),
                                  _buildInfoRow(Icons.phone,
                                      'Telp: ${store['store_phone'] ?? 'N/A'}'),
                                  _buildInfoRow(
                                    Icons.location_on,
                                    'Alamat: ${_parseAddress(store['store_address'])}',
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: ListTile(
                                      leading: Icon(
                                        store['is_verified'] == true
                                            ? Icons.remove_done
                                            : Icons.verified,
                                        color: store['is_verified'] == true
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                      title: Text(
                                        store['is_verified'] == true
                                            ? 'Batalkan Verifikasi'
                                            : 'Verifikasi',
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    value: 'verify',
                                  ),
                                  PopupMenuItem(
                                    child: ListTile(
                                      leading:
                                          Icon(Icons.edit, color: Colors.blue),
                                      title: Text('Edit'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    value: 'edit',
                                  ),
                                  PopupMenuItem(
                                    child: ListTile(
                                      leading:
                                          Icon(Icons.delete, color: Colors.red),
                                      title: Text('Hapus'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    value: 'delete',
                                  ),
                                ],
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    final result =
                                        await Get.to(() => EditStoreScreen(
                                              store: store,
                                              user: store['users'],
                                            ));
                                    if (result == true) {
                                      fetchStores();
                                    }
                                  } else if (value == 'verify') {
                                    toggleVerification(
                                      store['id'],
                                      store['is_verified'] ?? false,
                                    );
                                  } else if (value == 'delete') {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Konfirmasi'),
                                        content: Text(
                                            'Yakin ingin menghapus toko ini?'),
                                        actions: [
                                          TextButton(
                                            child: Text('Batal'),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                          ),
                                          TextButton(
                                            child: Text(
                                              'Hapus',
                                              style:
                                                  TextStyle(color: Colors.red),
                                            ),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              deleteStore(store['id']);
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                              onTap: () {
                                Get.to(() => StoreProductsScreen(store: store));
                              },
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}
