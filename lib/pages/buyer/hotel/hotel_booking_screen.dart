import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'hotel_booking_detail_screen.dart';

class HotelBookingScreen extends StatefulWidget {
  final Map<String, dynamic> hotel;
  final Map<String, dynamic> roomType;

  const HotelBookingScreen({
    Key? key,
    required this.hotel,
    required this.roomType,
  }) : super(key: key);

  @override
  _HotelBookingScreenState createState() => _HotelBookingScreenState();
}

class _HotelBookingScreenState extends State<HotelBookingScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  DateTime? _selectedCheckIn;
  DateTime? _selectedCheckOut;
  int _totalNights = 0;
  double _totalPrice = 0;
  double _adminFee = 0;
  double _appFee = 0;
  double _totalWithAdmin = 0;

  final _guestNameController = TextEditingController();
  final _guestPhoneController = TextEditingController();
  final _specialRequestController = TextEditingController();
  final _voucherController = TextEditingController();
  double _voucherDiscount = 0;
  bool _isCheckingVoucher = false;
  String? _voucherMessage;
  bool _isVoucherValid = false;

  bool _isLoading = false;
  int? selectedPaymentMethodId;
  List<Map<String, dynamic>> paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _selectedCheckIn = DateTime.now();
    _selectedCheckOut = DateTime.now().add(Duration(days: 1));
    _calculateTotal();
    fetchPaymentMethods();
    fetchAppFee();
  }

  void _calculateTotal() {
    if (_selectedCheckIn != null && _selectedCheckOut != null) {
      _totalNights = _selectedCheckOut!.difference(_selectedCheckIn!).inDays;
      _totalPrice =
          (_totalNights * widget.roomType['price_per_night']).toDouble();

      double roomPriceAfterDiscount = _totalPrice - _voucherDiscount;

      _totalWithAdmin = roomPriceAfterDiscount + _adminFee + _appFee;

      print('=== DETAIL PERHITUNGAN ===');
      print('Harga Kamar Original: $_totalPrice');
      print('Diskon Voucher: $_voucherDiscount');
      print('Harga Kamar Setelah Diskon: $roomPriceAfterDiscount');
      print('Biaya Admin: $_adminFee');
      print('Biaya Aplikasi: $_appFee');
      print('Total Pembayaran: $_totalWithAdmin');
      print('========================');
    }
  }

  Future<void> fetchPaymentMethods() async {
    try {
      final response = await supabase
          .from('payment_methods')
          .select('*, admin_fees(*)')
          .eq('is_active', true)
          .neq('name', 'COD')
          .order('name');

      setState(() {
        paymentMethods =
            (response as List<dynamic>).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      print('Error fetching payment methods: $e');
    }
  }

  Future<void> fetchAppFee() async {
    try {
      final response = await supabase
          .from('admin_fees')
          .select()
          .eq('is_active', true)
          .eq('name', 'Biaya Aplikasi')
          .maybeSingle();

      setState(() {
        _appFee = response != null ? (response['fee'] as num).toDouble() : 0;
        _calculateTotal();
      });
    } catch (e) {
      print('Error fetching app fee: $e');
      setState(() {
        _appFee = 0;
        _calculateTotal();
      });
    }
  }

  void _updateSelectedPaymentMethod(int? value) {
    if (value == null) return;

    setState(() {
      selectedPaymentMethodId = value;
      final selectedMethod =
          paymentMethods.firstWhere((method) => method['id'] == value);

      _adminFee = selectedMethod['admin'] != null
          ? (selectedMethod['admin'] as num).toDouble()
          : 0;

      _calculateTotal();
      print('Selected payment method: ${selectedMethod.toString()}');
      print('Admin fee from payment method: $_adminFee');
      print('App fee from admin_fees: $_appFee');
    });
  }

  Future<void> _checkVoucher() async {
    final voucherCode = _voucherController.text.trim();
    if (voucherCode.isEmpty) return;

    setState(() {
      _isCheckingVoucher = true;
      _voucherMessage = null;
    });

    try {
      final response = await supabase
          .from('shipping_vouchers')
          .select()
          .eq('code', voucherCode)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _voucherDiscount = (response['rate'] as num).toDouble();
          _isVoucherValid = true;
          _voucherMessage = 'Voucher berhasil digunakan!';
          _calculateTotal();
        });
      } else {
        setState(() {
          _voucherDiscount = 0;
          _isVoucherValid = false;
          _voucherMessage = 'Voucher tidak valid';
          _calculateTotal();
        });
      }
    } catch (e) {
      setState(() {
        _voucherMessage = 'Terjadi kesalahan saat mengecek voucher';
        _isVoucherValid = false;
        _voucherDiscount = 0;
        _calculateTotal();
      });
    } finally {
      setState(() => _isCheckingVoucher = false);
    }
  }

  void _showConfirmationDialog() {
    if (selectedPaymentMethodId == null) {
      Get.snackbar(
        'Error',
        'Silakan pilih metode pembayaran',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon dan Title
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hotel_rounded,
                  size: 48,
                  color: AppTheme.primary,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Konfirmasi Booking',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),

              // Rincian Booking
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildConfirmationRow(
                      'Hotel',
                      widget.hotel['name'],
                      Icons.business,
                    ),
                    Divider(height: 16),
                    _buildConfirmationRow(
                      'Tipe Kamar',
                      widget.roomType['type'],
                      Icons.hotel,
                    ),
                    Divider(height: 16),
                    _buildConfirmationRow(
                      'Total Pembayaran',
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(_totalWithAdmin),
                      Icons.payments,
                      isHighlighted: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        await _submitBooking();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Konfirmasi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Widget _buildConfirmationRow(String label, String value, IconData icon,
      {bool isHighlighted = false}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isHighlighted ? AppTheme.primary : Colors.grey[600],
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isHighlighted ? FontWeight.bold : FontWeight.normal,
                  color: isHighlighted ? AppTheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceDetails() {
    return Column(
      children: [
        // Total Malam
        _buildDetailRow('Total Malam', '$_totalNights malam'),

        // Harga Kamar dengan coret jika ada diskon
        _buildDetailRow(
          'Harga Kamar',
          _voucherDiscount > 0
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(_totalPrice),
                      style: TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(_totalPrice - _voucherDiscount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                )
              : NumberFormat.currency(
                  locale: 'id',
                  symbol: 'Rp ',
                  decimalDigits: 0,
                ).format(_totalPrice),
        ),

        // Biaya Admin
        _buildDetailRow(
          'Biaya Admin',
          NumberFormat.currency(
            locale: 'id',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(_adminFee),
        ),

        // Biaya Aplikasi
        _buildDetailRow(
          'Biaya Aplikasi',
          NumberFormat.currency(
            locale: 'id',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(_appFee),
        ),

        // Diskon Voucher jika ada
        if (_voucherDiscount > 0)
          _buildDetailRow(
            'Diskon Voucher',
            '- ${NumberFormat.currency(
              locale: 'id',
              symbol: 'Rp ',
              decimalDigits: 0,
            ).format(_voucherDiscount)}',
            valueColor: Colors.green,
          ),

        Divider(),

        // Total Pembayaran
        _buildDetailRow(
          'Total Pembayaran',
          NumberFormat.currency(
            locale: 'id',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(_totalWithAdmin),
          isTotal: true,
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, dynamic value,
      {bool isTotal = false, Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          value is Widget
              ? value
              : Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: isTotal ? 16 : 14,
                    fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                    color: valueColor ?? (isTotal ? AppTheme.primary : null),
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      // Hitung harga kamar setelah diskon
      double roomPriceAfterDiscount = _totalPrice - _voucherDiscount;

      final bookingData = {
        'hotel_id': widget.hotel['id'],
        'room_type': widget.roomType['type'],
        'user_id': supabase.auth.currentUser!.id,
        'check_in': _selectedCheckIn!.toIso8601String(),
        'check_out': _selectedCheckOut!.toIso8601String(),
        'total_nights': _totalNights,
        'total_price': roomPriceAfterDiscount,
        'admin_fee': _adminFee,
        'app_fee': _appFee,
        'payment_method_id': selectedPaymentMethodId,
        'guest_name': _guestNameController.text,
        'guest_phone': _guestPhoneController.text,
        'special_requests': _specialRequestController.text,
        'status': 'pending',
      };

      print('Final Booking Data to be sent:');
      print(bookingData);

      final response = await supabase
          .from('hotel_bookings')
          .insert(bookingData)
          .select()
          .single();

      print('Booking Response: ${response.toString()}');

      Get.to(() => HotelBookingDetailScreen(booking: response));
    } catch (e) {
      print('Error submitting booking: $e');
      Get.snackbar(
        'Error',
        'Gagal membuat booking: $e',
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
        title: Text('Booking Hotel',
            style: TextStyle(
              color: Colors.white,
            )),
        backgroundColor: AppTheme.primary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Hotel & Room Info
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.hotel['name'],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.hotel, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'Tipe Kamar: ${widget.roomType['type']}',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.money, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'Harga per malam: ${NumberFormat.currency(
                            locale: 'id',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(widget.roomType['price_per_night'])}',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Calendar
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Tanggal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    TableCalendar(
                      firstDay: DateTime.now(),
                      lastDay: DateTime.now().add(Duration(days: 365)),
                      focusedDay: _selectedCheckIn ?? DateTime.now(),
                      selectedDayPredicate: (day) {
                        if (_selectedCheckIn == null ||
                            _selectedCheckOut == null) return false;
                        return day.isAtSameMomentAs(_selectedCheckIn!) ||
                            day.isAtSameMomentAs(_selectedCheckOut!);
                      },
                      rangeStartDay: _selectedCheckIn,
                      rangeEndDay: _selectedCheckOut,
                      calendarFormat: CalendarFormat.month,
                      rangeSelectionMode: RangeSelectionMode.enforced,
                      onRangeSelected: (start, end, focusedDay) {
                        setState(() {
                          _selectedCheckIn = start;
                          _selectedCheckOut = end;
                          if (start != null && end != null) {
                            _calculateTotal();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Guest Info
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Tamu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _guestNameController,
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
                      controller: _guestPhoneController,
                      decoration: InputDecoration(
                        labelText: 'Nomor Telepon',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nomor telepon tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _specialRequestController,
                      decoration: InputDecoration(
                        labelText: 'Permintaan Khusus (Opsional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Payment Method Selection
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Metode Pembayaran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedPaymentMethodId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        hintText: 'Pilih metode pembayaran',
                      ),
                      items: paymentMethods.map((method) {
                        return DropdownMenuItem<int>(
                          value: method['id'],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(method['name']),
                              Text(
                                ' + ${NumberFormat.currency(
                                  locale: 'id',
                                  symbol: 'Rp ',
                                  decimalDigits: 0,
                                ).format(method['admin'])}',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _updateSelectedPaymentMethod,
                      validator: (value) =>
                          value == null ? 'Pilih metode pembayaran' : null,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 15),

            // Payment Details
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rincian Pembayaran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _voucherController,
                            decoration: InputDecoration(
                              labelText: 'Kode Voucher',
                              border: OutlineInputBorder(),
                              suffixIcon: _isCheckingVoucher
                                  ? Padding(
                                      padding: EdgeInsets.all(8),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isCheckingVoucher ? null : _checkVoucher,
                          child: Text('Cek',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                    if (_voucherMessage != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          _voucherMessage!,
                          style: TextStyle(
                            color: _isVoucherValid ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    SizedBox(height: 16),
                    _buildPriceDetails(),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isLoading ? null : _showConfirmationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Booking Sekarang',
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
    );
  }
}
