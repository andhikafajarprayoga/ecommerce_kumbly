import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'dart:io';
import 'dart:convert';

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
  final RxList<String> imagePaths = <String>[].obs;

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  final stockController = TextEditingController();
  final weightController = TextEditingController();
  final lengthController = TextEditingController();
  final widthController = TextEditingController();
  final heightController = TextEditingController();
  String? selectedCategory;

  // Tambahkan controller untuk alamat
  final streetController = TextEditingController();
  final villageController = TextEditingController();
  final districtController = TextEditingController();
  final cityController = TextEditingController();
  final provinceController = TextEditingController();
  final postalCodeController = TextEditingController();

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
    _initializeImages();
    _initializeAddress();
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

    if (categories.contains(widget.product['category'])) {
      selectedCategory = widget.product['category'];
    } else {
      selectedCategory = 'Lainnya';
    }
  }

  void _initializeImages() {
    if (widget.product['image_url'] != null) {
      try {
        if (widget.product['image_url'] is List) {
          imagePaths.addAll(List<String>.from(widget.product['image_url']));
        } else if (widget.product['image_url'] is String) {
          final List<dynamic> urls = json.decode(widget.product['image_url']);
          imagePaths.addAll(List<String>.from(urls));
        }
      } catch (e) {
        print('Error parsing image URLs: $e');
      }
    }
  }

  void _initializeAddress() {
    if (widget.product['store_address'] != null) {
      try {
        Map<String, dynamic> address;
        if (widget.product['store_address'] is String) {
          address = json.decode(widget.product['store_address']);
        } else {
          address = widget.product['store_address'];
        }

        streetController.text = address['street'] ?? '';
        villageController.text = address['village'] ?? '';
        districtController.text = address['district'] ?? '';
        cityController.text = address['city'] ?? '';
        provinceController.text = address['province'] ?? '';
        postalCodeController.text = address['postal_code'] ?? '';
      } catch (e) {
        print('Error parsing address: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      imagePaths.addAll(images.map((image) => image.path));
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];
    try {
      for (String path in imagePaths) {
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
            Obx(() => Container(
                  height: 200,
                  child: imagePaths.isEmpty
                      ? InkWell(
                          onTap: _pickImage,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.add_photo_alternate,
                                size: 50, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: imagePaths.length + 1,
                          itemBuilder: (context, index) {
                            if (index == imagePaths.length) {
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: InkWell(
                                  onTap: _pickImage,
                                  child: Container(
                                    width: 150,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.add_photo_alternate,
                                        size: 50, color: Colors.grey),
                                  ),
                                ),
                              );
                            }
                            return Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: imagePaths[index].startsWith('http')
                                        ? Image.network(
                                            imagePaths[index],
                                            width: 150,
                                            height: 200,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.file(
                                            File(imagePaths[index]),
                                            width: 150,
                                            height: 200,
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
                )),
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

            // Tambahkan widget form untuk alamat
            _buildAddressFields(),

            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate()) {
                        setState(() => isLoading = true);
                        try {
                          final imageUrls = await _uploadImages();

                          // Buat objek alamat
                          final addressData = {
                            'street': streetController.text,
                            'village': villageController.text,
                            'district': districtController.text,
                            'city': cityController.text,
                            'province': provinceController.text,
                            'postal_code': postalCodeController.text,
                          };

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
                            'image_url': imageUrls,
                            'store_address':
                                addressData, // Tambahkan data alamat
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
                    },
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

  // Tambahkan widget form untuk alamat
  Widget _buildAddressFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alamat Toko',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 12),
        TextFormField(
          controller: streetController,
          decoration: InputDecoration(
            labelText: 'Nama Jalan',
            hintText: 'Contoh: Jln Sigra',
          ),
          validator: (value) =>
              value!.isEmpty ? 'Nama jalan tidak boleh kosong' : null,
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: villageController,
                decoration: InputDecoration(
                  labelText: 'Desa/Kelurahan',
                  hintText: 'Contoh: Cisetu',
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Desa/Kelurahan tidak boleh kosong' : null,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: districtController,
                decoration: InputDecoration(
                  labelText: 'Kecamatan',
                  hintText: 'Contoh: Rajagaluh',
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Kecamatan tidak boleh kosong' : null,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: cityController,
                decoration: InputDecoration(
                  labelText: 'Kota/Kabupaten',
                  hintText: 'Contoh: Majalengka',
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Kota/Kabupaten tidak boleh kosong' : null,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: provinceController,
                decoration: InputDecoration(
                  labelText: 'Provinsi',
                  hintText: 'Contoh: Jawa Barat',
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Provinsi tidak boleh kosong' : null,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        TextFormField(
          controller: postalCodeController,
          decoration: InputDecoration(
            labelText: 'Kode Pos',
            hintText: 'Contoh: 45471',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) =>
              value!.isEmpty ? 'Kode pos tidak boleh kosong' : null,
        ),
      ],
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
    streetController.dispose();
    villageController.dispose();
    districtController.dispose();
    cityController.dispose();
    provinceController.dispose();
    postalCodeController.dispose();
    super.dispose();
  }
}
