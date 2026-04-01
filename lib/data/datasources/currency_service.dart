import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  static const String _baseUrl = 'https://api.frankfurter.app';
  static const String _cacheKey = 'currency_rates_cache';
  static const String _lastFetchKey = 'currency_last_fetch';
  
  Map<String, double>? _ratesCache;
  DateTime? _lastFetch;

  Future<void> _loadCache() async {
    if (_ratesCache != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheStr = prefs.getString(_cacheKey);
      final lastFetchStr = prefs.getString(_lastFetchKey);
      
      if (cacheStr != null && lastFetchStr != null) {
        final decoded = json.decode(cacheStr) as Map<String, dynamic>;
        _ratesCache = decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
        _lastFetch = DateTime.parse(lastFetchStr);
      }
    } catch (_) {
      _ratesCache = null;
      _lastFetch = null;
    }
  }

  Future<void> _saveCache() async {
    if (_ratesCache == null || _lastFetch == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(_ratesCache));
      await prefs.setString(_lastFetchKey, _lastFetch!.toIso8601String());
    } catch (_) {}
  }

  // Tasas aproximadas de respaldo (Base USD) para monedas no soportadas por la API gratuita
  // Actualizadas a feb 2026 (aproximado)
  static const Map<String, double> _fallbackRatesUSD = {
    'USD': 1.0,
    'EUR': 0.92,
    'PEN': 3.75, // Peru
    'ARS': 1100.0, // Argentina (Blue/Oficial mix - volátil)
    'BOB': 6.96, // Bolivia
    'CLP': 960.0, // Chile
    'COP': 3950.0, // Colombia
    'CRC': 515.0, // Costa Rica
    'DOP': 59.0, // Republica Dominicana
    'GTQ': 7.8, // Guatemala
    'HNL': 24.7, // Honduras
    'MXN': 17.5, // Mexico
    'NIO': 36.8, // Nicaragua
    'PAB': 1.0, // Panamá (Pegged to USD)
    'PYG': 7300.0, // Paraguay
    'UYU': 39.5, // Uruguay
    'VES': 36.5, // Venezuela
    'BRL': 5.0, // Brasil
  };

  /// Obtiene la lista de monedas soportadas y sus nombres
  Future<Map<String, String>> getCurrencies() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/currencies'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final apiCurrencies = data.map((key, value) => MapEntry(key, value.toString()));
        
        // Combinar con nuestra lista manual para asegurar que aparezcan todas las de LATAM
        // aunque la API no las devuelva en /currencies (pero sí soporte conversión)
        final allCurrencies = Map<String, String>.from(apiCurrencies);
        
        // Agregar las que falten desde nuestra lista local kCurrencyDetails
        // (Esto requiere importar currency_data.dart, pero para no romper arquitectura
        //  simplemente hardcodeamos las claves importantes aquí o asumimos que la UI
        //  usará kCurrencyDetails para enriquecer).
        // Mejor estrategia: Retornamos lo de la API y en la UI (CurrencyConverterScreen)
        // ya estamos iterando sobre _currencies.keys.
        // Haremos que getCurrencies retorne TODAS las claves que nos interesan.
        
        final interestingKeys = [
          'ARS', 'BOB', 'CLP', 'COP', 'CRC', 'DOP', 'GTQ', 'HNL', 'NIO', 
          'PAB', 'PEN', 'PYG', 'UYU', 'VES', 'USD', 'EUR'
        ];
        
        for (final key in interestingKeys) {
            if (!allCurrencies.containsKey(key)) {
                allCurrencies[key] = key; // El nombre real se sacará de kCurrencyDetails en UI
            }
        }
        
        return allCurrencies;
      }
      throw Exception('Error al cargar monedas');
    } catch (e) {
      // Fallback: usar una lista estática amplia si la API falla
      // Esto asegura que al menos las monedas comunes y LATAM estén disponibles
      return {
        'USD': 'Dólar Estadounidense',
        'EUR': 'Euro',
        'PEN': 'Sol Peruano',
        'ARS': 'Peso Argentino',
        'BOB': 'Boliviano',
        'BRL': 'Real Brasileño',
        'CLP': 'Peso Chileno',
        'COP': 'Peso Colombiano',
        'CRC': 'Colón Costarricense',
        'DOP': 'Peso Dominicano',
        'GTQ': 'Quetzal',
        'HNL': 'Lempira',
        'MXN': 'Peso Mexicano',
        'NIO': 'Córdoba',
        'PAB': 'Balboa',
        'PYG': 'Guaraní',
        'UYU': 'Peso Uruguayo',
        'VES': 'Bolívar',
        'GBP': 'Libra Esterlina',
        'JPY': 'Yen Japonés',
        'CAD': 'Dólar Canadiense',
      };
    }
  }

  /// Convierte un monto de una moneda a otra
  /// Retorna el monto convertido
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
  }) async {
    if (from == to) return amount;

    await _loadCache();

    // Intentar usar cache si es reciente (menos de 24 horas para offline extendido)
    if (_ratesCache != null && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!).inHours < 24) {
      final rateFrom = _ratesCache![from] ?? 0.0;
      final rateTo = _ratesCache![to] ?? 0.0;
      if (rateFrom != 0 && rateTo != 0) {
        // base PEN a rateFrom = rateFrom
        // target: rateTo
        return amount * (rateTo / rateFrom);
      }
    }

    try {
      // Pedimos tasas con base 'from' para facilitar
      final response = await http.get(
        Uri.parse('$_baseUrl/latest?amount=$amount&from=$from&to=$to'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;
        final rate = (rates[to] as num).toDouble();
        
        // Refrescar caché integral si la llamada individual falla el caché principal
        // De manera asíncrona para no bloquear esta respuesta
        getRatesBasePEN().catchError((_) => <String, double>{});
        
        return rate;
      }
      throw Exception('Error en conversión');
    } catch (e) {
      // Intentar fallback si estamos offline o la API falla
      if (_ratesCache != null && _ratesCache!.containsKey(from) && _ratesCache!.containsKey(to)) {
        final rateFrom = _ratesCache![from]!;
        final rateTo = _ratesCache![to]!;
        if (rateFrom != 0 && rateTo != 0) {
          return amount * (rateTo / rateFrom);
        }
      }
      // Intentar fallback local si la API falla
      if (_fallbackRatesUSD.containsKey(from) && _fallbackRatesUSD.containsKey(to)) {
        final rateFrom = _fallbackRatesUSD[from]!;
        final rateTo = _fallbackRatesUSD[to]!;
        // Convertir: Amount * (TargetRate / SourceRate)
        // Ej: 100 PEN a USD -> 100 * (1.0 / 3.75) = 26.66 USD
        return amount * (rateTo / rateFrom);
      }
      throw Exception('No se pudo convertir: $e');
    }
  }

  /// Obtiene tasas de cambio actuales con base en PEN (para mostrar en dashboard o cachear)
  Future<Map<String, double>> getRatesBasePEN() async {
    await _loadCache();

    if (_ratesCache != null && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!).inHours < 12) {
      return _ratesCache!;
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/latest?base=PEN'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;
        
        _ratesCache = rates.map((key, value) => MapEntry(key, (value as num).toDouble()));
        // Agregamos PEN = 1.0
        _ratesCache!['PEN'] = 1.0;
        _lastFetch = DateTime.now();
        
        await _saveCache();
        
        return _ratesCache!;
      }
      throw Exception('Error al obtener tasas');
    } catch (e) {
      // Fallback a caché antiguo si hay error (offline)
      if (_ratesCache != null && _ratesCache!.isNotEmpty) {
        return _ratesCache!;
      }
      // Fallback para getRatesBasePEN
      if (_fallbackRatesUSD.containsKey('PEN')) {
         final penRate = _fallbackRatesUSD['PEN']!;
         return _fallbackRatesUSD.map((key, value) => 
            MapEntry(key, value / penRate)); // Convertir base USD a base PEN
      }
      return {};
    }
  }
}
