import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'edit_address_screen.dart';

class AlamatScreen extends StatefulWidget {
  const AlamatScreen({super.key});

  @override
  State<AlamatScreen> createState() => _AlamatScreenState();
}

class _AlamatScreenState extends State<AlamatScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> addresses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAddresses();
  }

  Future<void> fetchAddresses() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('users')
          .select('address, address2, address3, address4')
          .eq('id', userId)
          .single();

      List<Map<String, dynamic>> tempAddresses = [];
      if (response['address'] != null) tempAddresses.add(response['address']);
      if (response['address2'] != null) tempAddresses.add(response['address2']);
      if (response['address3'] != null) tempAddresses.add(response['address3']);
      if (response['address4'] != null) tempAddresses.add(response['address4']);

      setState(() {
        addresses = tempAddresses;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Get.snackbar('Error', 'Gagal mengambil alamat: $e');
    }
  }

  Future<void> deleteAddress(int index) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      Map<String, dynamic> updateData = {};

      // Menggeser alamat setelah yang dihapus
      for (int i = index; i < 3; i++) {
        if (i + 1 < addresses.length) {
          updateData['address${i == 0 ? "" : i}'] = addresses[i + 1];
        } else {
          updateData['address${i == 0 ? "" : i}'] = null;
        }
      }
      // Mengatur alamat terakhir menjadi null
      updateData[
              'address${addresses.length - 1 == 0 ? "" : addresses.length - 1}'] =
          null;

      await supabase.from('users').update(updateData).eq('id', userId);

      await fetchAddresses();
      Get.snackbar('Sukses', 'Alamat berhasil dihapus');
    } catch (e) {
      Get.snackbar('Error', 'Gagal menghapus alamat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primary,
        title: const Text(
          'Daftar Alamat',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      floatingActionButton: addresses.length < 4
          ? FloatingActionButton.extended(
              onPressed: () => Get.to(() => EditAddressScreen(
                    initialAddress: {},
                    onSave: (Map<String, dynamic> newAddress) async {
                      try {
                        final userId = supabase.auth.currentUser?.id;
                        if (userId == null) return;

                        String field = addresses.isEmpty
                            ? 'address'
                            : 'address${addresses.length}';
                        await supabase
                            .from('users')
                            .update({field: newAddress}).eq('id', userId);

                        await fetchAddresses();
                      } catch (e) {
                        Get.snackbar('Error', 'Gagal menambah alamat: $e');
                      }
                    },
                  )),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Tambah Alamat',
                  style: TextStyle(color: Colors.white)),
            )
          : null,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : addresses.isEmpty
              ? _buildEmptyState()
              : _buildAddressList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Belum ada alamat tersimpan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan alamat pengiriman Anda',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Get.to(() => EditAddressScreen(
                  initialAddress: {},
                  onSave: (Map<String, dynamic> newAddress) async {
                    try {
                      final userId = supabase.auth.currentUser?.id;
                      if (userId == null) return;

                      await supabase
                          .from('users')
                          .update({'address': newAddress}).eq('id', userId);

                      await fetchAddresses();
                    } catch (e) {
                      Get.snackbar('Error', 'Gagal menambah alamat: $e');
                    }
                  },
                )),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Alamat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        final address = addresses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Alamat ${index + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit') {
                          Get.to(() => EditAddressScreen(
                                initialAddress: address,
                                onSave: (Map<String, dynamic>
                                    updatedAddress) async {
                                  try {
                                    final userId =
                                        supabase.auth.currentUser?.id;
                                    if (userId == null) return;

                                    String field = index == 0
                                        ? 'address'
                                        : 'address$index';
                                    await supabase
                                        .from('users')
                                        .update({field: updatedAddress}).eq(
                                            'id', userId);

                                    await fetchAddresses();
                                  } catch (e) {
                                    Get.snackbar(
                                        'Error', 'Gagal mengubah alamat: $e');
                                  }
                                },
                              ));
                        } else if (value == 'delete') {
                          _showDeleteConfirmation(index);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Hapus',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildAddressDetail(
                  icon: Icons.location_on_outlined,
                  text: address['street'] ?? '',
                ),
                const SizedBox(height: 8),
                _buildAddressDetail(
                  icon: Icons.location_city_outlined,
                  text:
                      'Kec. ${address['district'] ?? ''}, ${address['city'] ?? ''}',
                ),
                const SizedBox(height: 8),
                _buildAddressDetail(
                  icon: Icons.map_outlined,
                  text:
                      '${address['province'] ?? ''}, ${address['postal_code'] ?? ''}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddressDetail({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(int index) {
    Get.dialog(
      AlertDialog(
        title: const Text('Hapus Alamat'),
        content: const Text('Anda yakin ingin menghapus alamat ini?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              deleteAddress(index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
