import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AddEditHotelScreen extends StatefulWidget {
  final Map<String, dynamic>? hotel;

  const AddEditHotelScreen({Key? key, this.hotel}) : super(key: key);

  @override
  _AddEditHotelScreenState createState() => _AddEditHotelScreenState();
}

class _AddEditHotelScreenState extends State<AddEditHotelScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _facilitiesController = TextEditingController();

  List<String> _imageUrls = [];
  List<File> _newImages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.hotel != null) {
      _nameController.text = widget.hotel!['name'];
      _descriptionController.text = widget.hotel!['description'] ?? '';
      _addressController.text = widget.hotel!['address'] ?? '';
      _facilitiesController.text =
          (widget.hotel!['facilities'] as List).join(', ');
      _imageUrls = List<String>.from(widget.hotel!['image_url'] ?? []);
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      setState(() {
        _newImages.addAll(images.map((image) => File(image.path)));
      });
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> uploadedUrls = [];

    for (File image in _newImages) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';
      final response =
          await supabase.storage.from('hotel_images').upload(fileName, image);

      if (response.isNotEmpty) {
        final url =
            supabase.storage.from('hotel_images').getPublicUrl(fileName);
        uploadedUrls.add(url);
      }
    }

    return uploadedUrls;
  }

  Future<void> _saveHotel() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      // Upload new images
      final List<String> newImageUrls = await _uploadImages();
      final allImageUrls = [..._imageUrls, ...newImageUrls];

      final hotelData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'address': _addressController.text,
        'facilities':
            _facilitiesController.text.split(',').map((e) => e.trim()).toList(),
        'image_url': allImageUrls,
        'merchant_id': supabase.auth.currentUser!.id,
      };

      if (widget.hotel == null) {
        // Create new hotel
        await supabase.from('hotels').insert(hotelData);
      } else {
        // Update existing hotel
        await supabase
            .from('hotels')
            .update(hotelData)
            .eq('id', widget.hotel!['id']);
      }

      Get.back();
      Get.snackbar(
        'Sukses',
        widget.hotel == null
            ? 'Hotel berhasil ditambahkan'
            : 'Hotel berhasil diupdate',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal menyimpan hotel: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hotel == null ? 'Tambah Hotel' : 'Edit Hotel'),
        backgroundColor: AppTheme.primary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nama Hotel',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama hotel tidak boleh kosong';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Deskripsi',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Alamat',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Alamat tidak boleh kosong';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            TextFormField(
              controller: _facilitiesController,
              decoration: InputDecoration(
                labelText: 'Fasilitas (pisahkan dengan koma)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Image Preview
            if (_imageUrls.isNotEmpty || _newImages.isNotEmpty) ...[
              Text('Preview Gambar:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Container(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._imageUrls.map((url) => Padding(
                          padding: EdgeInsets.only(right: 8),
                          child:
                              Image.network(url, width: 100, fit: BoxFit.cover),
                        )),
                    ..._newImages.map((file) => Padding(
                          padding: EdgeInsets.only(right: 8),
                          child:
                              Image.file(file, width: 100, fit: BoxFit.cover),
                        )),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],

            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: Icon(Icons.add_photo_alternate),
              label: Text('Tambah Gambar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
            ),
            SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveHotel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.hotel == null ? 'Tambah Hotel' : 'Update Hotel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
