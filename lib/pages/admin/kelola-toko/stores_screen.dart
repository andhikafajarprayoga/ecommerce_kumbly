import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/pages/admin/kelola-toko/store_products_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../feature/edit_store_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Toko'),
        backgroundColor: AppTheme.primary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Cari toko...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
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
                    ? Center(child: Text('Tidak ada toko'))
                    : ListView.builder(
                        itemCount: stores.length,
                        itemBuilder: (context, index) {
                          final store = stores[index];
                          final user = store['users'];
                          return Card(
                            margin: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: store['is_verified'] == true
                                    ? Colors.green.shade100
                                    : Colors.grey.shade100,
                                child: Icon(
                                  Icons.store,
                                  color: store['is_verified'] == true
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                              title: Text(
                                store['store_name'],
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Pemilik: ${user['full_name'] ?? 'N/A'}'),
                                  Text('Email: ${user['email']}'),
                                  Text(
                                      'Telp: ${store['store_phone'] ?? 'N/A'}'),
                                  Text(
                                      'Alamat: ${store['store_address'] ?? 'N/A'}'),
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
}
