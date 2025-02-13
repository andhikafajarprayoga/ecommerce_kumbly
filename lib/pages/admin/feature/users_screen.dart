import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class UsersScreen extends StatefulWidget {
  @override
  _UsersScreenState createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> users = [];
  bool isLoading = true;
  final searchController = TextEditingController();
  String selectedRole = 'all';

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    try {
      var query = supabase.from('users').select();

      if (selectedRole != 'all') {
        query = query.eq('role', selectedRole);
      }

      final response = await query.order('created_at', ascending: false);

      setState(() {
        users = (response as List<dynamic>).cast<Map<String, dynamic>>();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching users: $e');
      setState(() => isLoading = false);
    }
  }

  void searchUsers(String query) async {
    try {
      final response = await supabase
          .from('users')
          .select()
          .eq(selectedRole != 'all' ? 'role' : 'id',
              selectedRole != 'all' ? selectedRole : users[0]['id'])
          .or('email.ilike.%$query%,full_name.ilike.%$query%')
          .order('created_at', ascending: false);

      setState(() {
        users = (response as List<dynamic>).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      print('Error searching users: $e');
    }
  }

  String getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return '#FF0000'; // Merah
      case 'seller':
        return '#4CAF50'; // Hijau
      case 'buyer':
        return '#2196F3'; // Biru
      case 'courier':
        return '#FF9800'; // Orange
      case 'branch':
        return '#9C27B0'; // Ungu
      default:
        return '#9E9E9E'; // Abu-abu
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Users', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.to(() => AddEditUserScreen())
            ?.then((value) => value == true ? fetchUsers() : null),
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('Tambah User', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari user...',
                    prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: AppTheme.primary),
                            onPressed: () {
                              searchController.clear();
                              fetchUsers();
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      fetchUsers();
                    } else {
                      searchUsers(value);
                    }
                  },
                ),
                SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Semua', 'all', AppTheme.primary),
                      SizedBox(width: 8),
                      _buildFilterChip('Admin', 'admin', Colors.red),
                      SizedBox(width: 8),
                      _buildFilterChip('Seller', 'seller', Colors.green),
                      SizedBox(width: 8),
                      _buildFilterChip('Buyer', 'buyer', Colors.blue),
                      SizedBox(width: 8),
                      _buildFilterChip('Courier', 'courier', Colors.orange),
                      SizedBox(width: 8),
                      _buildFilterChip('Branch', 'branch', Colors.purple),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Tidak ada user',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: users.length,
                        padding: EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return Card(
                            elevation: 2,
                            margin: EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(16),
                              leading: CircleAvatar(
                                radius: 30,
                                backgroundColor:
                                    AppTheme.primary.withOpacity(0.1),
                                backgroundImage: user['image_url'] != null
                                    ? NetworkImage(user['image_url'])
                                    : null,
                                child: user['image_url'] == null
                                    ? Icon(Icons.person,
                                        color: AppTheme.primary, size: 30)
                                    : null,
                              ),
                              title: Text(
                                user['full_name'] ?? 'Tanpa Nama',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.email,
                                          size: 16, color: Colors.grey),
                                      SizedBox(width: 4),
                                      Expanded(child: Text(user['email'])),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.phone,
                                          size: 16, color: Colors.grey),
                                      SizedBox(width: 4),
                                      Text('${user['phone'] ?? '-'}'),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(int.parse(
                                              getRoleColor(user['role'])
                                                  .replaceAll('#', 'FF'),
                                              radix: 16))
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      user['role'].toUpperCase(),
                                      style: TextStyle(
                                        color: Color(int.parse(
                                            getRoleColor(user['role'])
                                                .replaceAll('#', 'FF'),
                                            radix: 16)),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: _buildPopupMenu(user, context),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String role, Color color) {
    return FilterChip(
      label: Text(label),
      selected: selectedRole == role,
      onSelected: (bool selected) {
        setState(() {
          selectedRole = role;
        });
        fetchUsers();
      },
      backgroundColor: Colors.white,
      selectedColor: color.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selectedRole == role ? color : Colors.black87,
        fontWeight: selectedRole == role ? FontWeight.bold : FontWeight.normal,
      ),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selectedRole == role ? color : Colors.grey[300]!,
        ),
      ),
    );
  }

  Widget _buildPopupMenu(Map<String, dynamic> user, BuildContext context) {
    return PopupMenuButton(
      icon: Icon(Icons.more_vert, color: Colors.grey[600]),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.edit, color: Colors.blue),
            title: Text('Edit'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          value: 'edit',
        ),
        if (user['role'] != 'admin')
          PopupMenuItem(
            child: ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Hapus'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            value: 'delete',
          ),
      ],
      onSelected: (value) async {
        if (value == 'edit') {
          final result = await Get.to(
            () => AddEditUserScreen(user: user),
          );
          if (result == true) {
            fetchUsers();
          }
        } else if (value == 'delete') {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Konfirmasi'),
              content: Text('Yakin ingin menghapus user ini?'),
              actions: [
                TextButton(
                  child: Text('Batal'),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: Text(
                    'Hapus',
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await supabase.auth.admin.deleteUser(user['id']);
                      Get.snackbar(
                        'Sukses',
                        'User berhasil dihapus',
                        backgroundColor: Colors.green,
                        colorText: Colors.white,
                      );
                      fetchUsers();
                    } catch (e) {
                      print('Error deleting user: $e');
                      Get.snackbar(
                        'Error',
                        'Gagal menghapus user',
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                    }
                  },
                ),
              ],
            ),
          );
        }
      },
    );
  }
}

class AddEditUserScreen extends StatefulWidget {
  final Map<String, dynamic>? user;

  AddEditUserScreen({this.user});

  @override
  _AddEditUserScreenState createState() => _AddEditUserScreenState();
}

class _AddEditUserScreenState extends State<AddEditUserScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  String? selectedRole;

  late TextEditingController emailController;
  late TextEditingController fullNameController;
  late TextEditingController phoneController;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: widget.user?['email'] ?? '');
    fullNameController =
        TextEditingController(text: widget.user?['full_name'] ?? '');
    phoneController = TextEditingController(text: widget.user?['phone'] ?? '');
    if (widget.user != null) {
      selectedRole = widget.user!['role'];
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    fullNameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      print('DEBUG: Memulai proses simpan user');

      if (widget.user != null) {
        print('DEBUG: Attempting to update user ID: ${widget.user!['id']}');

        // Verifikasi role admin terlebih dahulu
        final currentUser = supabase.auth.currentUser;
        if (currentUser?.id == null) throw Exception('User tidak ditemukan');

        final adminCheck = await supabase
            .from('users')
            .select('role')
            .eq('id', currentUser!.id)
            .single();

        print('DEBUG: Admin check result: $adminCheck');

        if (adminCheck['role'] != 'admin') {
          throw Exception('Anda tidak memiliki akses admin');
        }

        // Update hanya role, full_name, dan phone
        final response = await supabase
            .from('users')
            .update({
              'role': selectedRole,
              'full_name': fullNameController.text,
              'phone': phoneController.text,
            })
            .eq('id', widget.user!['id'])
            .select()
            .single();

        print('DEBUG: Update response: $response');
      }

      Get.back(result: true);
      Get.snackbar(
        'Sukses',
        'Data user berhasil disimpan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('DEBUG: Error saving user: $e');
      Get.snackbar(
        'Error',
        'Gagal menyimpan data user: ${e.toString()}',
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
        title: Text(
          widget.user != null ? 'Edit User' : 'Tambah User',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              enabled: widget.user == null,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email tidak boleh kosong';
                }
                if (!value.contains('@')) {
                  return 'Email tidak valid';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: fullNameController,
              decoration: InputDecoration(
                labelText: 'Nama Lengkap',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama tidak boleh kosong';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Nomor Telepon',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'seller', child: Text('Seller')),
                DropdownMenuItem(value: 'buyer', child: Text('Buyer')),
                DropdownMenuItem(value: 'courier', child: Text('Courier')),
                DropdownMenuItem(value: 'branch', child: Text('Branch')),
              ],
              onChanged: (value) {
                setState(() => selectedRole = value);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Pilih role user';
                }
                return null;
              },
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : _saveUser,
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Simpan',
                      style: TextStyle(color: Colors.white),
                    ),
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
