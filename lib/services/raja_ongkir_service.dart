import 'package:http/http.dart' as http;
import 'dart:convert';

class RajaOngkirService {
  static const String _baseUrl = 'https://api.rajaongkir.com/starter';
  static const String _apiKey = 'hYek93nb587c44dfc2e07885SwcKLtlt';

  // Mendapatkan daftar provinsi
  static Future<List<dynamic>> getProvinces() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/province'),
        headers: {
          'key': _apiKey,
          'content-type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['rajaongkir']['results'];
      }
      throw Exception('Gagal mengambil data provinsi');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Mendapatkan daftar kota berdasarkan provinsi
  static Future<List<dynamic>> getCities(String provinceId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/city?province=$provinceId'),
        headers: {
          'key': _apiKey,
          'content-type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['rajaongkir']['results'];
      }
      throw Exception('Gagal mengambil data kota');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Menghitung ongkos kirim
  static Future<Map<String, dynamic>> checkShippingCost({
    required String origin, // ID kota asal
    required String destination, // ID kota tujuan
    required int weight, // Berat dalam gram
    required String courier, // jne, pos, tiki
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/cost'),
        headers: {
          'key': _apiKey,
          'content-type': 'application/json',
        },
        body: json.encode({
          'origin': origin,
          'destination': destination,
          'weight': weight,
          'courier': courier,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['rajaongkir']['results'][0];
      }
      throw Exception('Gagal menghitung ongkos kirim');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
