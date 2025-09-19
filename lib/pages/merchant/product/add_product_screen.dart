import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../controllers/product_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'dart:isolate';

class AddProductScreen extends StatelessWidget {
  AddProductScreen({super.key});

  final ProductController productController = Get.find<ProductController>();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController lengthController =
      TextEditingController(text: '0');
  final TextEditingController widthController =
      TextEditingController(text: '0');
  final TextEditingController heightController =
      TextEditingController(text: '0');
  final RxList<String> imagePaths = <String>[].obs;
  final supabase = Supabase.instance.client;
  final RxString uploadStatus = ''.obs;
  final RxDouble uploadProgress = 0.0.obs;

  final Map<String, List<String>> categoryMap = {
    'Elektronik & Gadget': [
      'Smartphone & Aksesoris',
      'Laptop & PC',
      'Kamera & Aksesoris',
      'Smartwatch & Wearable Tech',
      'Peralatan Gaming',
    ],
    'Fashion & Aksesoris': [
      'Pakaian Pria',
      'Pakaian Wanita',
      'Sepatu & Sandal',
      'Tas & Dompet',
      'Jam Tangan & Perhiasan',
    ],
    'Kesehatan & Kecantikan': [
      'Skincare',
      'Make-up',
      'Parfum',
      'Suplemen & Vitamin',
      'Alat Kesehatan',
    ],
    'Makanan & Minuman': [
      'Makanan Instan',
      'Minuman Kemasan',
      'Makanan Camilan & Snack',
      'Bahan Makanan',
      'Makanan Hotel',
    ],
    'Rumah Tangga & Perabotan': [
      'Peralatan Dapur',
      'Furniture',
      'Dekorasi Rumah',
      'Alat Kebersihan',
    ],
    'Otomotif & Aksesoris': [
      'Suku Cadang Kendaraan',
      'Aksesoris Mobil & Motor',
      'Helm & Perlengkapan Berkendara',
    ],
    'Hobi & Koleksi': [
      'Buku & Majalah',
      'Alat Musik',
      'Action Figure & Koleksi',
      'Olahraga & Outdoor',
    ],
    'Bayi & Anak': [
      'Pakaian Bayi & Anak',
      'Mainan Anak',
      'Perlengkapan Bayi',
    ],
    'Keperluan Industri & Bisnis': [
      'Alat Teknik & Mesin',
      'Perlengkapan Kantor',
      'Peralatan Keamanan',
    ],
  };

  final RxString selectedMainCategory = ''.obs;
  final RxString selectedSubCategory = ''.obs;

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

  Future<void> saveProduct() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Tampilkan loading segera setelah tombol simpan ditekan
        if (Get.isDialogOpen != true) {
          Get.dialog(
            const Center(child: CircularProgressIndicator()),
            barrierDismissible: false,
          );
        }

        List<String> imageUrls = [];
        if (imagePaths.isNotEmpty) {
          imageUrls = await uploadImages(imagePaths);
        }

        // Konversi string harga yang berformat menjadi numeric untuk database
        final price =
            double.parse(priceController.text.replaceAll(RegExp(r'[^\d]'), ''));

        await supabase.from('products').insert({
          'seller_id': supabase.auth.currentUser!.id,
          'name': nameController.text,
          'description': descriptionController.text,
          'price': price, // nilai numerik murni untuk database
          'stock': int.parse(stockController.text),
          'category': categoryController.text,
          'image_url': imageUrls,
          'weight': int.parse(weightController.text),
          'length': int.parse(lengthController.text),
          'width': int.parse(widthController.text),
          'height': int.parse(heightController.text),
          'created_at': DateTime.now().toIso8601String(),
        });

        if (Get.isDialogOpen == true) Get.back(); // Tutup loading
        Get.back(); // Kembali ke halaman sebelumnya
        Get.snackbar(
          'Sukses',
          'Produk berhasil ditambahkan',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        if (Get.isDialogOpen == true) Get.back(); // Tutup loading
        Get.snackbar(
          'Error',
          'Gagal menambahkan produk: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
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
          'Tambah Produk',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Foto Produk',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Obx(() => imagePaths.isNotEmpty
                      ? Column(
                          children: [
                            Container(
                              height: 200,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: imagePaths.length < 4
                                    ? imagePaths.length + 1 // +1 tombol tambah
                                    : 4, // Tidak tampilkan tombol tambah jika sudah 4
                                itemBuilder: (context, index) {
                                  if (index == imagePaths.length && imagePaths.length < 4) {
                                    // Tombol tambah foto
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
                                  // Tampilan foto yang sudah dipilih
                                  return Stack(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          child: Image.file(
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
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: descriptionController,
                      label: 'Deskripsi',
                      hint: 'Masukkan deskripsi produk',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Deskripsi tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: priceController,
                      label: 'Harga',
                      hint: 'Masukkan harga produk',
                      icon: Icons.money,
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
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 10),
                    _buildCategoryDropdown(),
                    const SizedBox(height: 10),
                    Text(
                      'Dimensi & Berat',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: weightController,
                            label: 'Berat (gram)',
                            hint: 'Contoh: 100',
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
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Dimensi & Berat akan mempengaruhi biaya pengiriman. Pastikan data yang dimasukkan sudah benar.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          if (imagePaths.isEmpty || imagePaths.length < 2) {
                            Get.snackbar(
                              'Perhatian',
                              'Harap unggah minimal 2 foto produk',
                              backgroundColor: Colors.orange,
                              colorText: Colors.white,
                              icon: const Icon(Icons.warning_amber_rounded,
                                  color: Colors.white),
                            );
                            return;
                          }

                          try {
                            Get.dialog(
                              const Center(child: CircularProgressIndicator()),
                              barrierDismissible: false,
                            );

                            List<String> imageUrls = [];
                            if (imagePaths.isNotEmpty) {
                              imageUrls = await uploadImages(imagePaths);
                            }

                            // Konversi string harga yang berformat menjadi numeric untuk database
                            final price = double.parse(priceController.text
                                .replaceAll(RegExp(r'[^\d]'), ''));

                            await supabase.from('products').insert({
                              'seller_id': supabase.auth.currentUser!.id,
                              'name': nameController.text,
                              'description': descriptionController.text,
                              'price':
                                  price, // nilai numerik murni untuk database
                              'stock': int.parse(stockController.text),
                              'category': categoryController.text,
                              'image_url': imageUrls,
                              'weight': int.parse(weightController.text),
                              'length': int.parse(lengthController.text),
                              'width': int.parse(widthController.text),
                              'height': int.parse(heightController.text),
                              'created_at': DateTime.now().toIso8601String(),
                            });

                            Get.back(); // Tutup loading
                            Get.back(); // Kembali ke halaman sebelumnya
                            Get.snackbar(
                              'Sukses',
                              'Produk berhasil ditambahkan',
                              backgroundColor: Colors.green,
                              colorText: Colors.white,
                            );
                          } catch (e) {
                            Get.back(); // Tutup loading
                            Get.snackbar(
                              'Error',
                              'Gagal menambahkan produk: $e',
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Simpan Produk',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Unggah minimal 2 foto produk dari sudut yang berbeda',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
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
      margin: EdgeInsets.only(bottom: 20),
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

  Widget _buildCategoryDropdown() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 20),
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
          child: Obx(() => DropdownButtonFormField<String>(
                value: selectedMainCategory.value.isEmpty
                    ? null
                    : selectedMainCategory.value,
                decoration: InputDecoration(
                  labelText: 'Kategori Utama',
                  labelStyle: TextStyle(color: AppTheme.primary),
                  prefixIcon:
                      Icon(Icons.category_outlined, color: AppTheme.primary),
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
                items: categoryMap.keys.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    selectedMainCategory.value = newValue;
                    selectedSubCategory.value = '';
                    categoryController.text = '';
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Pilih kategori utama';
                  }
                  return null;
                },
              )),
        ),
        Obx(() => selectedMainCategory.value.isNotEmpty
            ? Container(
                margin: EdgeInsets.only(bottom: 20),
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
                child: DropdownButtonFormField<String>(
                  value: selectedSubCategory.value.isEmpty
                      ? null
                      : selectedSubCategory.value,
                  decoration: InputDecoration(
                    labelText: 'Sub Kategori',
                    labelStyle: TextStyle(color: AppTheme.primary),
                    prefixIcon: Icon(Icons.subdirectory_arrow_right,
                        color: AppTheme.primary),
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
                  items: categoryMap[selectedMainCategory.value]
                      ?.map((String subCategory) {
                    return DropdownMenuItem<String>(
                      value: subCategory,
                      child: Text(subCategory),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      selectedSubCategory.value = newValue;
                      categoryController.text = newValue;
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Pilih sub kategori';
                    }
                    return null;
                  },
                ),
              )
            : SizedBox()),
      ],
    );
  }
}
