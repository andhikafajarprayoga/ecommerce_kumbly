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
      print('DEBUG: Memulai proses hapus banner');
      print('DEBUG: Banner ID: $bannerId');
      print('DEBUG: Image URL: $imageUrl');

      // Hapus gambar dari storage
      final uri = Uri.parse(imageUrl);
      final imagePath = uri.pathSegments.last;
      print('DEBUG: Menghapus file: $imagePath');

      await supabase.storage.from('banner-images').remove([imagePath]);
      print('DEBUG: File berhasil dihapus dari storage');

      // Hapus record dari database
      await supabase.from('banners').delete().eq('id', bannerId);
      print('DEBUG: Record berhasil dihapus dari database');

      fetchBanners();
      Get.snackbar('Sukses', 'Banner berhasil dihapus');
    } catch (e) {
      print('Error deleting banner: $e');
      if (e.toString().contains('row-level security policy')) {
        Get.snackbar(
          'Error',
          'Anda tidak memiliki izin untuk menghapus banner. Pastikan Anda memiliki role admin.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 5),
        );
      } else {
        Get.snackbar(
          'Error',
          'Gagal menghapus banner',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
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
    _checkAdminRole();
    if (widget.banner != null) {
      titleController.text = widget.banner!['title'] ?? '';
      descriptionController.text = widget.banner!['description'] ?? '';
      _imageUrl = widget.banner!['image_url'];
      isActive = widget.banner!['is_active'] ?? true;
    }
  }

  Future<void> _checkAdminRole() async {
    try {
      print('DEBUG: Checking admin role...');
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('DEBUG: User not logged in');
        Get.offAllNamed('/login');
        return;
      }

      // Ambil data user dari tabel users
      final userData = await supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      print('DEBUG: User data: $userData');

      if (userData == null || userData['role'] != 'admin') {
        print('DEBUG: User is not admin');
        Get.snackbar(
          'Error',
          'Anda tidak memiliki akses admin',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Get.back();
        return;
      }

      // Update user metadata dengan role
      await supabase.auth.updateUser(UserAttributes(data: {'role': 'admin'}));

      print('DEBUG: Admin role confirmed and metadata updated');
    } catch (e) {
      print('DEBUG: Error checking admin role: $e');
      Get.snackbar(
        'Error',
        'Gagal memverifikasi role admin',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      Get.back();
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
      print('DEBUG: Memulai upload gambar');

      // Periksa user dan role
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User tidak terautentikasi');
      }

      // Periksa role di database
      final userData = await supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      print('DEBUG: User role from database: ${userData['role']}');

      if (userData['role'] != 'admin') {
        throw Exception('User bukan admin');
      }

      // Tambahkan header authorization khusus
      final fileOptions = FileOptions(
        cacheControl: '3600',
        upsert: false,
        contentType:
            'image/${path.extension(_imageFile!.path).replaceAll('.', '')}',
      );

      final fileName =
          'banner-${DateTime.now().millisecondsSinceEpoch}${path.extension(_imageFile!.path)}';
      print('DEBUG: Attempting to upload file: $fileName');
      print('DEBUG: User ID: ${user.id}');
      print('DEBUG: File size: ${await _imageFile!.length()} bytes');

      // Coba upload
      final response = await supabase.storage.from('banner-images').upload(
            fileName,
            _imageFile!,
            fileOptions: fileOptions,
          );

      print('DEBUG: Upload response: $response');

      // Dapatkan URL publik
      final imageUrl =
          supabase.storage.from('banner-images').getPublicUrl(fileName);

      print('DEBUG: Generated public URL: $imageUrl');

      return imageUrl;
    } catch (e) {
      print('DEBUG: Detailed error during upload: $e');
      if (e.toString().contains('row-level security policy')) {
        Get.snackbar(
          'Error',
          'Izin storage tidak valid. Hubungi administrator.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 5),
        );
      } else if (e.toString().contains('User bukan admin')) {
        Get.snackbar(
          'Error',
          'Anda tidak memiliki role admin yang valid.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 5),
        );
      } else {
        Get.snackbar(
          'Error',
          'Gagal mengupload gambar: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 5),
        );
      }
      return null;
    }
  }

  Future<bool> _verifyAdminRole() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      final userData = await supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      return userData['role'] == 'admin';
    } catch (e) {
      print('DEBUG: Error verifying admin role: $e');
      return false;
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
