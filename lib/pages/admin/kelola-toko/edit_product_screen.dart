import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'dart:io';

class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  EditProductScreen({required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;
  bool isLoading = false;
  File? _imageFile;
  String? _imageUrl;

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  final stockController = TextEditingController();
  final weightController = TextEditingController();
  final lengthController = TextEditingController();
  final widthController = TextEditingController();
  final heightController = TextEditingController();
  String? selectedCategory;

  final List<String> categories = [
    'Makanan',
    'Minuman',
    'Pakaian',
    'Aksesoris',
    'Perkakas',
    'Lainnya'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    nameController.text = widget.product['name'];
    descriptionController.text = widget.product['description'] ?? '';
    priceController.text = widget.product['price'].toString();
    stockController.text = widget.product['stock'].toString();
    weightController.text = widget.product['weight'].toString();
    lengthController.text = widget.product['length'].toString();
    widthController.text = widget.product['width'].toString();
    heightController.text = widget.product['height'].toString();
    _imageUrl = widget.product['image_url'];

    if (categories.contains(widget.product['category'])) {
      selectedCategory = widget.product['category'];
    } else {
      selectedCategory = 'Lainnya';
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _imageUrl;

    try {
      final String path = 'products/${DateTime.now().toIso8601String()}.jpg';
      final file =
          await supabase.storage.from('products').upload(path, _imageFile!);

      return supabase.storage.from('products').getPublicUrl(path);
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      String? imageUrl = await _uploadImage();

      final updatedData = {
        'name': nameController.text,
        'description': descriptionController.text,
        'price': double.parse(priceController.text),
        'stock': int.parse(stockController.text),
        'category': selectedCategory,
        'weight': int.parse(weightController.text),
        'length': int.parse(lengthController.text),
        'width': int.parse(widthController.text),
        'height': int.parse(heightController.text),
        if (imageUrl != null) 'image_url': imageUrl,
      };

      await supabase
          .from('products')
          .update(updatedData)
          .eq('id', widget.product['id']);

      Get.back(result: true);
      Get.snackbar(
        'Sukses',
        'Produk berhasil diperbarui',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error updating product: $e');
      Get.snackbar(
        'Error',
        'Gagal memperbarui produk',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Produk'),
        backgroundColor: AppTheme.primary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Image Picker
            InkWell(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : _imageUrl != null
                        ? Image.network(_imageUrl!, fit: BoxFit.cover)
                        : Icon(Icons.add_photo_alternate,
                            size: 50, color: Colors.grey),
              ),
            ),
            SizedBox(height: 16),

            // Form Fields
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Nama Produk'),
              validator: (value) =>
                  value!.isEmpty ? 'Nama produk tidak boleh kosong' : null,
            ),
            SizedBox(height: 12),

            TextFormField(
              controller: descriptionController,
              decoration: InputDecoration(labelText: 'Deskripsi'),
              maxLines: 3,
            ),
            SizedBox(height: 12),

            TextFormField(
              controller: priceController,
              decoration: InputDecoration(labelText: 'Harga'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) =>
                  value!.isEmpty ? 'Harga tidak boleh kosong' : null,
            ),
            SizedBox(height: 12),

            TextFormField(
              controller: stockController,
              decoration: InputDecoration(labelText: 'Stok'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) =>
                  value!.isEmpty ? 'Stok tidak boleh kosong' : null,
            ),
            SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: InputDecoration(labelText: 'Kategori'),
              items: categories.map((String category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedCategory = newValue;
                });
              },
              validator: (value) =>
                  value == null ? 'Pilih kategori produk' : null,
            ),
            SizedBox(height: 12),

            // Dimensi Produk
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: weightController,
                    decoration: InputDecoration(labelText: 'Berat (gram)'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) =>
                        value!.isEmpty ? 'Berat tidak boleh kosong' : null,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: lengthController,
                    decoration: InputDecoration(labelText: 'Panjang (cm)'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widthController,
                    decoration: InputDecoration(labelText: 'Lebar (cm)'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: heightController,
                    decoration: InputDecoration(labelText: 'Tinggi (cm)'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            ElevatedButton(
              onPressed: isLoading ? null : _updateProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    stockController.dispose();
    weightController.dispose();
    lengthController.dispose();
    widthController.dispose();
    heightController.dispose();
    super.dispose();
  }
}
