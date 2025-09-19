import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../controllers/product_controller.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'dart:isolate';

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
  final RxString uploadStatus = ''.obs;
  final RxDouble uploadProgress = 0.0.obs;

  @override
  void initState() {
    super.initState();
    nameController.text = widget.product['name'];
    final price = widget.product['price'] ?? 0;
    priceController.text = NumberFormat('#,###', 'id_ID').format(price);
    descriptionController.text = widget.product['description'] ?? '';
    stockController.text = widget.product['stock'].toString();
    categoryController.text = widget.product['category'] ?? '';
    weightController.text = (widget.product['weight'] ?? 0).toString();
    lengthController.text = (widget.product['length'] ?? 0).toString();
    widthController.text = (widget.product['width'] ?? 0).toString();
    heightController.text = (widget.product['height'] ?? 0).toString();

    // Handle existing images
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

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    
    // Tampilkan dialog loading saat memilih gambar
    showDialog(
      context: Get.context!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memproses gambar...'),
          ],
        ),
      ),
    );
    
    try {
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 70, // Reduksi kualitas dari picker
      );
      
      Get.back(); // Tutup loading dialog
      
      if (images.isNotEmpty) {
        int remaining = 4 - imagePaths.length;
        if (remaining <= 0) {
          Get.snackbar(
            'Maksimal Foto',
            'Anda hanya dapat mengunggah maksimal 4 foto produk',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          return;
        }
        
        // Filter hanya jpg/jpeg/png
        final allowed = images.where((img) {
          final ext = img.path.toLowerCase();
          return ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png');
        }).toList();
        
        if (allowed.isEmpty) {
          Get.snackbar(
            'Format Tidak Didukung',
            'Hanya file JPG dan PNG yang diperbolehkan',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }
        
        if (allowed.length < images.length) {
          Get.snackbar(
            'Sebagian Foto Ditolak',
            'Hanya file JPG dan PNG yang diunggah, lainnya diabaikan.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        }
        
        // Cek ukuran file dan beri peringatan
        for (var image in allowed) {
          final file = File(image.path);
          final sizeInMB = (await file.length()) / (1024 * 1024);
          if (sizeInMB > 5) {
            Get.snackbar(
              'Ukuran File Besar',
              'Gambar ${image.name} berukuran ${sizeInMB.toStringAsFixed(1)}MB. Proses kompresi mungkin memerlukan waktu.',
              backgroundColor: Colors.orange,
              colorText: Colors.white,
              duration: Duration(seconds: 4),
            );
          }
        }
        
        // Batasi maksimal 4 foto total
        final toAdd = allowed.take(remaining).map((image) => image.path).toList();
        imagePaths.addAll(toAdd);
        
        if (allowed.length > remaining) {
          Get.snackbar(
            'Maksimal Foto',
            'Hanya 4 foto pertama yang diunggah, sisanya diabaikan.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        }
      }
    } catch (e) {
      Get.back(); // Pastikan dialog loading ditutup
      Get.snackbar(
        'Error',
        'Gagal memilih gambar: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<List<String>> uploadImages(List<String> paths) async {
    List<String> imageUrls = [];
    try {
      // Tampilkan dialog progress
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false, // Prevent dismissing during upload
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Obx(() => Text(uploadStatus.value)),
                SizedBox(height: 8),
                Obx(() => LinearProgressIndicator(value: uploadProgress.value)),
                SizedBox(height: 8),
                Obx(() => Text('${(uploadProgress.value * 100).toInt()}%')),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      for (int i = 0; i < paths.length; i++) {
        final path = paths[i];
        
        // Skip jika path adalah URL (gambar yang sudah ada)
        if (path.startsWith('http')) {
          imageUrls.add(path);
          uploadProgress.value = ((i + 1) / paths.length) * 0.9;
          continue;
        }

        uploadStatus.value = 'Memproses gambar ${i + 1} dari ${paths.length}...';
        uploadProgress.value = (i / paths.length) * 0.7; // 70% for compression

        // Kompresi gambar menggunakan isolate
        final compressedImageData = await _compressImageInIsolate(path);
        
        if (compressedImageData == null) continue;

        uploadStatus.value = 'Mengunggah gambar ${i + 1}...';
        
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${i}.jpg';

        // Simpan ke file sementara
        final tempFile = File('${path}_compressed.jpg');
        await tempFile.writeAsBytes(compressedImageData);

        try {
          await supabase.storage.from('products').upload(fileName, tempFile);
          
          final imageUrl = supabase.storage.from('products').getPublicUrl(fileName);
          imageUrls.add(imageUrl);
          
          // Hapus file sementara
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          
          uploadProgress.value = ((i + 1) / paths.length) * 0.9; // 90% for upload progress
        } catch (e) {
          print('Error uploading image $i: $e');
          // Hapus file sementara jika error
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      }
      
      uploadStatus.value = 'Selesai!';
      uploadProgress.value = 1.0;
      
      // Tutup dialog setelah delay singkat
      await Future.delayed(Duration(milliseconds: 500));
      if (Get.isDialogOpen == true) Get.back();
      
      return imageUrls;
    } catch (e) {
      uploadStatus.value = 'Error: $e';
      await Future.delayed(Duration(seconds: 2));
      if (Get.isDialogOpen == true) Get.back();
      print('Error uploading images: $e');
      Get.snackbar(
        'Error',
        'Gagal mengupload gambar: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return [];
    }
  }

  // Fungsi untuk kompresi gambar di isolate terpisah
  static Future<List<int>?> _compressImageInIsolate(String imagePath) async {
    final receivePort = ReceivePort();
    
    try {
      await Isolate.spawn(_imageCompressionWorker, {
        'imagePath': imagePath,
        'sendPort': receivePort.sendPort,
      });
      
      // Timeout 30 detik untuk kompresi
      final result = await receivePort.first.timeout(
        Duration(seconds: 30),
        onTimeout: () => null,
      );
      
      return result as List<int>?;
    } catch (e) {
      print('Error in image compression isolate: $e');
      return null;
    }
  }

  // Worker function yang berjalan di isolate terpisah
  static void _imageCompressionWorker(Map<String, dynamic> params) {
    final String imagePath = params['imagePath'];
    final SendPort sendPort = params['sendPort'];
    
    try {
      final file = File(imagePath);
      final originalBytes = file.readAsBytesSync();
      
      // Decode gambar
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) {
        sendPort.send(null);
        return;
      }
      
      // Resize jika terlalu besar (max 1024x1024)
      img.Image resizedImage = originalImage;
      if (originalImage.width > 1024 || originalImage.height > 1024) {
        resizedImage = img.copyResize(
          originalImage, 
          width: originalImage.width > originalImage.height ? 1024 : null,
          height: originalImage.height > originalImage.width ? 1024 : null,
        );
      }
      
      // Kompresi dengan kualitas bertahap
      List<int> compressedImage;
      int quality = 85;
      int targetSize = 100 * 1024; // Target 100KB
      int minQuality = 20;
      
      do {
        compressedImage = img.encodeJpg(resizedImage, quality: quality);
        if (compressedImage.length <= targetSize || quality <= minQuality) {
          break;
        }
        quality -= 15;
      } while (quality > minQuality);
      
      sendPort.send(compressedImage);
    } catch (e) {
      print('Worker error: $e');
      sendPort.send(null);
    }
  }

  String formatNumber(String value) {
    if (value.isEmpty) return '';
    final number = int.tryParse(value.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    final format = NumberFormat('#,###', 'id_ID');
    return format.format(number);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
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
                                // Hapus tombol tambah jika sudah 4 foto
                                itemCount: imagePaths.length >= 4
                                    ? 4
                                    : imagePaths.length + 1,
                                itemBuilder: (context, index) {
                                  // Tampilkan tombol tambah hanya jika < 4 foto
                                  if (index == imagePaths.length && imagePaths.length < 4) {
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
                      onChanged: (value) {
                        final cursorPos = priceController.selection;
                        final text = formatNumber(value);
                        priceController.text = text;
                        if (text.length > 0) {
                          priceController.selection =
                              TextSelection.fromPosition(
                            TextPosition(offset: text.length),
                          );
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Harga tidak boleh kosong';
                        }
                        final number = value.replaceAll(RegExp(r'[^\d]'), '');
                        if (number.isEmpty || int.tryParse(number) == null) {
                          return 'Masukkan angka yang valid';
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
                            label: 'Berat (gram)',
                            hint: 'Contoh: 1000',
                            icon: Icons.scale,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Berat tidak boleh kosong';
                              }
                              try {
                                final weight = int.parse(value);
                                if (weight <= 0) {
                                  return 'Berat harus lebih dari 0';
                                }
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
    Function(String)? onChanged,
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
        onChanged: onChanged,
      ),
    );
  }

  void updateProduct() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Tampilkan loading segera setelah tombol update ditekan
        if (Get.isDialogOpen != true) {
          Get.dialog(
            const Center(child: CircularProgressIndicator()),
            barrierDismissible: false,
          );
        }

        List<String> imageUrls = await uploadImages(imagePaths);

        final priceString =
            priceController.text.replaceAll(RegExp(r'[^\d]'), '');
        final price = int.parse(priceString);

        await productController.updateProduct(
          widget.product['id'],
          nameController.text,
          price.toDouble(),
          int.parse(stockController.text),
          descriptionController.text,
          categoryController.text,
          imageUrls,
          int.parse(weightController.text),
          int.parse(lengthController.text),
          int.parse(widthController.text),
          int.parse(heightController.text),
        );

        if (Get.isDialogOpen == true) Get.back(); // Tutup loading
        Get.back();
        Get.snackbar(
          'Sukses',
          'Produk berhasil diperbarui',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        if (Get.isDialogOpen == true) Get.back(); // Tutup loading
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
