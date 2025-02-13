import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import 'dart:convert';

class BranchProductsScreen extends StatefulWidget {
  const BranchProductsScreen({super.key});

  @override
  State<BranchProductsScreen> createState() => _BranchProductsScreenState();
}

class _BranchProductsScreenState extends State<BranchProductsScreen> {
  final supabase = Supabase.instance.client;
  String? _getFirstImageUrl(dynamic imageUrl) {
    if (imageUrl is String) {
      try {
        List<dynamic> images = jsonDecode(imageUrl); // Convert ke List
        if (images.isNotEmpty && images[0] is String) {
          return images[0]; // Ambil gambar pertama
        }
      } catch (e) {
        print("Error decoding image_url: $e");
      }
    } else if (imageUrl is List && imageUrl.isNotEmpty) {
      return imageUrl[0]; // Jika sudah berbentuk List<String>
    }
    return null; // Jika tidak ada gambar
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Daftar Produk', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder(
        stream: supabase.from('products').stream(primaryKey: ['id']).execute(),
        builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data!;

          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada produk',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];

              // Cek apakah 'image_url' adalah list dan tidak kosong
              String? imageUrl;
              if (product['image_url'] is List &&
                  product['image_url'].isNotEmpty) {
                imageUrl =
                    product['image_url'][0]; // Ambil gambar pertama dari list
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _getFirstImageUrl(product['image_url']) != null
                        ? Image.network(
                            _getFirstImageUrl(product['image_url'])!,
                            width: 55,
                            height: 55,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholder();
                            },
                          )
                        : _buildPlaceholder(),
                  ),
                  title: Text(
                    product['name'] ?? 'Nama tidak tersedia',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Stok: ${product['stock'] ?? 0}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Rp ${product['price'] ?? 0}',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }
}
