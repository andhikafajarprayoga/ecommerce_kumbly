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
      default:
        return '#9E9E9E'; // Abu-abu
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Users'),
        backgroundColor: AppTheme.primary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => AddEditUserScreen())
            ?.then((value) => value == true ? fetchUsers() : null),
        child: Icon(Icons.add),
        backgroundColor: AppTheme.primary,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari user...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
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
                      FilterChip(
                        label: Text('Semua'),
                        selected: selectedRole == 'all',
                        onSelected: (bool selected) {
                          setState(() {
                            selectedRole = 'all';
                          });
                          fetchUsers();
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: AppTheme.primary.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: selectedRole == 'all'
                              ? AppTheme.primary
                              : Colors.black87,
                          fontWeight: selectedRole == 'all'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      SizedBox(width: 8),
                      FilterChip(
                        label: Text('Admin'),
                        selected: selectedRole == 'admin',
                        onSelected: (bool selected) {
                          setState(() {
                            selectedRole = 'admin';
                          });
                          fetchUsers();
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Colors.red.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: selectedRole == 'admin'
                              ? Colors.red
                              : Colors.black87,
                          fontWeight: selectedRole == 'admin'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      SizedBox(width: 8),
                      FilterChip(
                        label: Text('Seller'),
                        selected: selectedRole == 'seller',
                        onSelected: (bool selected) {
                          setState(() {
                            selectedRole = 'seller';
                          });
                          fetchUsers();
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Colors.green.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: selectedRole == 'seller'
                              ? Colors.green
                              : Colors.black87,
                          fontWeight: selectedRole == 'seller'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      SizedBox(width: 8),
                      FilterChip(
                        label: Text('Buyer'),
                        selected: selectedRole == 'buyer',
                        onSelected: (bool selected) {
                          setState(() {
                            selectedRole = 'buyer';
                          });
                          fetchUsers();
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Colors.blue.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: selectedRole == 'buyer'
                              ? Colors.blue
                              : Colors.black87,
                          fontWeight: selectedRole == 'buyer'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      SizedBox(width: 8),
                      FilterChip(
                        label: Text('Courier'),
                        selected: selectedRole == 'courier',
                        onSelected: (bool selected) {
                          setState(() {
                            selectedRole = 'courier';
                          });
                          fetchUsers();
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Colors.orange.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: selectedRole == 'courier'
                              ? Colors.orange
                              : Colors.black87,
                          fontWeight: selectedRole == 'courier'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
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
                    ? Center(child: Text('Tidak ada user'))
                    : ListView.builder(
                        itemCount: users.length,
                        padding: EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user['image_url'] != null
                                    ? NetworkImage(user['image_url'])
                                    : null,
                                child: user['image_url'] == null
                                    ? Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(
                                user['full_name'] ?? 'Tanpa Nama',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user['email']),
                                  Text('Telp: ${user['phone'] ?? '-'}'),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Color(int.parse(
                                              getRoleColor(user['role'])
                                                  .replaceAll('#', 'FF'),
                                              radix: 16))
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
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
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: ListTile(
                                      leading:
                                          Icon(Icons.edit, color: Colors.blue),
                                      title: Text('Edit'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    value: 'edit',
                                  ),
                                  if (user['role'] != 'admin')
                                    PopupMenuItem(
                                      child: ListTile(
                                        leading: Icon(Icons.delete,
                                            color: Colors.red),
                                        title: Text('Hapus'),
                                        contentPadding: EdgeInsets.zero,
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
                                        content: Text(
                                            'Yakin ingin menghapus user ini?'),
                                        actions: [
                                          TextButton(
                                            child: Text('Batal'),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                          ),
                                          TextButton(
                                            child: Text(
                                              'Hapus',
                                              style:
                                                  TextStyle(color: Colors.red),
                                            ),
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              try {
                                                await supabase.auth.admin
                                                    .deleteUser(user['id']);
                                                Get.snackbar(
                                                  'Sukses',
                                                  'User berhasil dihapus',
                                                  backgroundColor: Colors.green,
                                                  colorText: Colors.white,
                                                );
                                                fetchUsers();
                                              } catch (e) {
                                                print(
                                                    'Error deleting user: $e');
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
                              ),
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

  late TextEditingController emailController;
  late TextEditingController fullNameController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  String selectedRole = 'buyer';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: widget.user?['email'] ?? '');
    fullNameController =
        TextEditingController(text: widget.user?['full_name'] ?? '');
    phoneController = TextEditingController(text: widget.user?['phone'] ?? '');
    addressController =
        TextEditingController(text: widget.user?['address'] ?? '');
    if (widget.user != null) {
      selectedRole = widget.user!['role'];
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    fullNameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final data = {
        'email': emailController.text,
        'full_name': fullNameController.text,
        'phone': phoneController.text,
        'address': addressController.text,
        'role': selectedRole,
      };

      if (widget.user != null) {
        // Update existing user
        await supabase.from('users').update(data).eq('id', widget.user!['id']);
      } else {
        // Create new user
        // Note: In a real application, you would need to handle user authentication creation as well
        Get.snackbar(
          'Info',
          'Pembuatan user baru memerlukan proses pendaftaran',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      Get.back(result: true);
      Get.snackbar(
        'Sukses',
        'Data user berhasil disimpan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error saving user: $e');
      Get.snackbar(
        'Error',
        'Gagal menyimpan data user',
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
        title: Text(widget.user != null ? 'Edit User' : 'Tambah User'),
        backgroundColor: AppTheme.primary,
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
            TextFormField(
              controller: addressController,
              decoration: InputDecoration(
                labelText: 'Alamat',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: ['admin', 'seller', 'buyer', 'courier']
                  .map((role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedRole = value);
                }
              },
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : saveUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
