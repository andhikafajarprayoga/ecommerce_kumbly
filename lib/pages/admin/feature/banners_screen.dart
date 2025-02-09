import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../theme/app_theme.dart';
import 'package:path/path.dart' as path;

class BannersScreen extends StatefulWidget {
  @override
  _BannersScreenState createState() => _BannersScreenState();
}

class _BannersScreenState extends State<BannersScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> banners = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchBanners();
  }

  Future<void> fetchBanners() async {
    try {
      final response = await supabase
          .from('banners')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        banners = (response as List<dynamic>).cast<Map<String, dynamic>>();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching banners: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteBanner(int bannerId, String imageUrl) async {
    try {
      // Hapus gambar dari storage
      final uri = Uri.parse(imageUrl);
      final imagePath = uri.pathSegments.last;
      await supabase.storage.from('banner-images').remove([imagePath]);

      // Hapus record dari database
      await supabase.from('banners').delete().eq('id', bannerId);

      fetchBanners();
      Get.snackbar('Sukses', 'Banner berhasil dihapus');
    } catch (e) {
      print('Error deleting banner: $e');
      Get.snackbar('Error', 'Gagal menghapus banner');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kelola Banner',
          style: TextStyle(fontWeight: FontWeight.normal),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: const Color.fromARGB(221, 255, 255, 255),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Get.to(() => AddEditBannerScreen())?.then((_) => fetchBanners()),
        child: Icon(Icons.add),
        backgroundColor: AppTheme.primary,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : banners.isEmpty
              ? Center(child: Text('Tidak ada banner'))
              : ListView.builder(
                  itemCount: banners.length,
                  itemBuilder: (context, index) {
                    final banner = banners[index];
                    return Card(
                      margin: EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Image.network(
                            banner['image_url'],
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          ListTile(
                            title: Text(banner['title'] ?? 'Tanpa judul'),
                            subtitle: Text(
                                banner['description'] ?? 'Tanpa deskripsi'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit),
                                  onPressed: () => Get.to(() =>
                                          AddEditBannerScreen(banner: banner))
                                      ?.then((_) => fetchBanners()),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('Konfirmasi'),
                                      content: Text(
                                          'Yakin ingin menghapus banner ini?'),
                                      actions: [
                                        TextButton(
                                          child: Text('Batal'),
                                          onPressed: () =>
                                              Navigator.pop(context),
                                        ),
                                        TextButton(
                                          child: Text('Hapus'),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            deleteBanner(banner['id'],
                                                banner['image_url']);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class AddEditBannerScreen extends StatefulWidget {
  final Map<String, dynamic>? banner;

  AddEditBannerScreen({this.banner});

  @override
  _AddEditBannerScreenState createState() => _AddEditBannerScreenState();
}

class _AddEditBannerScreenState extends State<AddEditBannerScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  File? _imageFile;
  String? _imageUrl;
  bool isActive = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.banner != null) {
      titleController.text = widget.banner!['title'] ?? '';
      descriptionController.text = widget.banner!['description'] ?? '';
      _imageUrl = widget.banner!['image_url'];
      isActive = widget.banner!['is_active'] ?? true;
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _imageFile = File(image.path));
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}${path.extension(_imageFile!.path)}';
      await supabase.storage.from('banner-images').upload(
            fileName,
            _imageFile!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      return supabase.storage.from('banner-images').getPublicUrl(fileName);
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _saveBanner() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null && _imageUrl == null) {
      Get.snackbar('Error', 'Pilih gambar terlebih dahulu');
      return;
    }

    setState(() => isLoading = true);

    try {
      String? imageUrl = _imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImage();
        if (imageUrl == null) throw Exception('Failed to upload image');

        // Hapus gambar lama jika ada
        if (_imageUrl != null) {
          final uri = Uri.parse(_imageUrl!);
          final oldImagePath = uri.pathSegments.last;
          await supabase.storage.from('banner-images').remove([oldImagePath]);
        }
      }

      final data = {
        'title': titleController.text,
        'description': descriptionController.text,
        'image_url': imageUrl,
        'is_active': isActive,
      };

      if (widget.banner != null) {
        await supabase
            .from('banners')
            .update(data)
            .eq('id', widget.banner!['id']);
      } else {
        await supabase.from('banners').insert(data);
      }

      Get.back();
      Get.snackbar('Sukses', 'Banner berhasil disimpan');
    } catch (e) {
      print('Error saving banner: $e');
      Get.snackbar('Error', 'Gagal menyimpan banner');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.banner != null ? 'Edit Banner' : 'Tambah Banner'),
        backgroundColor: AppTheme.primary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : _imageUrl != null
                        ? Image.network(_imageUrl!, fit: BoxFit.cover)
                        : Icon(Icons.add_photo_alternate, size: 50),
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Judul',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Judul tidak boleh kosong';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Deskripsi',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            SwitchListTile(
              title: Text('Status Aktif'),
              value: isActive,
              onChanged: (bool value) {
                setState(() => isActive = value);
              },
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : _saveBanner,
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Simpan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
