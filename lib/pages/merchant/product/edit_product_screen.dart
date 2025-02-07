import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../controllers/product_controller.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../../theme/app_theme.dart';

class EditProductScreen extends StatefulWidget {
  final dynamic product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final ProductController productController = Get.find<ProductController>();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController lengthController = TextEditingController();
  final TextEditingController widthController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final RxList<String> imagePaths = <String>[].obs;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    nameController.text = widget.product['name'];
    priceController.text = widget.product['price'].toString();
    descriptionController.text = widget.product['description'] ?? '';
    stockController.text = widget.product['stock'].toString();
    categoryController.text = widget.product['category'] ?? '';
    // Konversi gram ke kg untuk ditampilkan
    final weightInGrams = widget.product['weight'] ?? 0;
    weightController.text = (weightInGrams / 1000).toString();
    lengthController.text = (widget.product['length'] ?? 0).toString();
    widthController.text = (widget.product['width'] ?? 0).toString();
    heightController.text = (widget.product['height'] ?? 0).toString();

    // Handle existing images
    if (widget.product['image_url'] != null) {
      try {
        if (widget.product['image_url'] is List) {
          imagePaths.addAll(List<String>.from(widget.product['image_url']));
        } else if (widget.product['image_url'] is String) {
          // Parse string JSON ke List
          final List<dynamic> urls = json.decode(widget.product['image_url']);
          imagePaths.addAll(List<String>.from(urls));
        }
      } catch (e) {
        print('Error parsing image URLs: $e');
      }
    }
  }

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      imagePaths.addAll(images.map((image) => image.path));
    }
  }

  Future<List<String>> uploadImages(List<String> paths) async {
    List<String> imageUrls = [];
    try {
      for (String path in paths) {
        // Skip jika path adalah URL (gambar yang sudah ada)
        if (path.startsWith('http')) {
          imageUrls.add(path);
          continue;
        }

        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${path.split('/').last}';
        final file = File(path);

        await supabase.storage.from('products').upload(fileName, file);

        final imageUrl =
            supabase.storage.from('products').getPublicUrl(fileName);

        imageUrls.add(imageUrl);
      }
      return imageUrls;
    } catch (e) {
      print('Error uploading images: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primary,
        title: const Text(
          'Edit Produk',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Obx(() => imagePaths.isNotEmpty
                      ? Column(
                          children: [
                            Container(
                              height: 200,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: imagePaths.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == imagePaths.length) {
                                    return Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: InkWell(
                                        onTap: pickImage,
                                        child: Container(
                                          width: 150,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            border: Border.all(
                                                color: Colors.grey[300]!),
                                          ),
                                          child: Icon(Icons.add_photo_alternate,
                                              size: 40,
                                              color: Colors.grey[400]),
                                        ),
                                      ),
                                    );
                                  }
                                  return Stack(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          child: imagePaths[index]
                                                  .startsWith('http')
                                              ? Image.network(
                                                  imagePaths[index],
                                                  height: 200,
                                                  width: 150,
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.file(
                                                  File(imagePaths[index]),
                                                  height: 200,
                                                  width: 150,
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: IconButton(
                                          icon: Icon(Icons.remove_circle,
                                              color: Colors.red),
                                          onPressed: () {
                                            imagePaths.removeAt(index);
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      : InkWell(
                          onTap: pickImage,
                          child: Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 60, color: Colors.grey[400]),
                                const SizedBox(height: 10),
                                Text(
                                  'Tambah Foto Produk',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      controller: nameController,
                      label: 'Nama Produk',
                      hint: 'Masukkan nama produk',
                      icon: Icons.shopping_bag_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nama produk tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: descriptionController,
                      label: 'Deskripsi',
                      hint: 'Masukkan deskripsi produk',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: priceController,
                      label: 'Harga',
                      hint: 'Masukkan harga produk',
                      icon: Icons.attach_money_outlined,
                      keyboardType: TextInputType.number,
                      prefixText: 'Rp ',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Harga tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: stockController,
                      label: 'Stok',
                      hint: 'Masukkan jumlah stok',
                      icon: Icons.inventory_2_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Stok tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: categoryController,
                      label: 'Kategori',
                      hint: 'Masukkan kategori produk',
                      icon: Icons.category_outlined,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Dimensi & Berat',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: weightController,
                            label: 'Berat (kg)',
                            hint: 'Contoh: 1.5',
                            icon: Icons.scale,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Berat tidak boleh kosong';
                              }
                              try {
                                final weight = double.parse(value);
                                if (weight <= 0) {
                                  return 'Berat harus lebih dari 0';
                                }
                                // Convert kg to grams and update controller
                                final gramWeight = (weight * 1000).round();
                                weightController.text = gramWeight.toString();
                              } catch (e) {
                                return 'Masukkan angka yang valid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: lengthController,
                            label: 'Panjang (cm)',
                            hint: '0',
                            icon: Icons.straighten,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            controller: widthController,
                            label: 'Lebar (cm)',
                            hint: '0',
                            icon: Icons.straighten,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            controller: heightController,
                            label: 'Tinggi (cm)',
                            hint: '0',
                            icon: Icons.height,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: updateProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Simpan Perubahan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? prefixText,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppTheme.primary),
          hintText: hint,
          prefixText: prefixText,
          prefixIcon: Icon(icon, color: AppTheme.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.primary),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: validator,
      ),
    );
  }

  void updateProduct() async {
    if (_formKey.currentState!.validate()) {
      try {
        List<String> imageUrls = await uploadImages(imagePaths);

        await productController.updateProduct(
          widget.product['id'],
          nameController.text,
          double.parse(priceController.text),
          int.parse(stockController.text),
          descriptionController.text,
          categoryController.text,
          imageUrls,
          int.parse(weightController.text),
          int.parse(lengthController.text),
          int.parse(widthController.text),
          int.parse(heightController.text),
        );

        Get.back();
        Get.snackbar(
          'Sukses',
          'Produk berhasil diperbarui',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Gagal memperbarui produk: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }
}
