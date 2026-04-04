import 'package:flutter/material.dart';

class AppIcons {
  // Mapa de nombres a IconData de Material
  static const Map<String, IconData> materialIcons = {
    // Finanzas
    'attach_money': Icons.attach_money,
    'money_off': Icons.money_off,
    'account_balance': Icons.account_balance,
    'account_balance_wallet': Icons.account_balance_wallet,
    'credit_card': Icons.credit_card,
    'savings': Icons.savings,
    'receipt': Icons.receipt,
    'receipt_long': Icons.receipt_long,
    'pie_chart': Icons.pie_chart,
    'bar_chart': Icons.bar_chart,
    'show_chart': Icons.show_chart,
    'calculate': Icons.calculate,
    'currency_exchange': Icons.currency_exchange,

    // Transporte
    'directions_car': Icons.directions_car,
    'directions_bus': Icons.directions_bus,
    'directions_bike': Icons.directions_bike,
    'directions_walk': Icons.directions_walk,
    'local_taxi': Icons.local_taxi,
    'local_gas_station': Icons.local_gas_station,
    'local_parking': Icons.local_parking,
    'train': Icons.train,
    'flight': Icons.flight,

    // Hogar
    'home': Icons.home,
    'apartment': Icons.apartment,
    'cottage': Icons.cottage,
    'chair': Icons.chair,
    'bed': Icons.bed,
    'lightbulb': Icons.lightbulb,
    'water_drop': Icons.water_drop,
    'electrical_services': Icons.electrical_services,
    'router': Icons.router, // Wifi/Internet
    'cleaning_services': Icons.cleaning_services,

    // Comida
    'restaurant': Icons.restaurant,
    'restaurant_menu': Icons.restaurant_menu,
    'lunch_dining': Icons.lunch_dining,
    'local_cafe': Icons.local_cafe,
    'local_bar': Icons.local_bar,
    'local_pizza': Icons.local_pizza,
    'bakery_dining': Icons.bakery_dining,
    'icecream': Icons.icecream,
    'kitchen': Icons.kitchen,

    // Salud
    'medical_services': Icons.medical_services,
    'local_hospital': Icons.local_hospital,
    'local_pharmacy': Icons.local_pharmacy,
    'medication': Icons.medication,
    'healing': Icons.healing,
    'monitor_heart': Icons.monitor_heart,
    'fitness_center': Icons.fitness_center,
    'spa': Icons.spa,

    // Entretenimiento
    'movie': Icons.movie,
    'theaters': Icons.theaters,
    'music_note': Icons.music_note,
    'headphones': Icons.headphones,
    'sports_esports': Icons.sports_esports,
    'sports_soccer': Icons.sports_soccer,
    'pool': Icons.pool,
    'beach_access': Icons.beach_access,
    'book': Icons.book,
    'palette': Icons.palette,

    // Compras
    'shopping_cart': Icons.shopping_cart,
    'shopping_bag': Icons.shopping_bag,
    'local_mall': Icons.local_mall,
    'store': Icons.store,
    'card_giftcard': Icons.card_giftcard,
    'checkroom': Icons.checkroom, // Ropa
    // Educación
    'school': Icons.school,
    'menu_book': Icons.menu_book,
    'auto_stories': Icons.auto_stories,
    'science': Icons.science,

    // Tecnología
    'computer': Icons.computer,
    'smartphone': Icons.smartphone,
    'laptop': Icons.laptop,
    'devices': Icons.devices,
    'print': Icons.print,

    // Otros
    'pets': Icons.pets,
    'child_care': Icons.child_care,
    'work': Icons.work,
    'construction': Icons.construction,
    'category': Icons.category,
    'label': Icons.label,
    'star': Icons.star,
    'favorite': Icons.favorite,
    'public': Icons.public,
    'lock': Icons.lock,
    'warning': Icons.warning,
    'info': Icons.info,
    'help': Icons.help,
  };

  /// Obtiene un Widget de Icono basado en el nombre (puede ser key material o emoji)
  static Widget getIcon(String name, {double size = 24, Color? color}) {
    // 1. Check if it's a known Material Icon key
    if (materialIcons.containsKey(name)) {
      return Icon(materialIcons[name], size: size, color: color);
    }

    // 2. Check if it looks like a Material Icon name but not in our map (fallback to generic)
    // Or if it's a default drift value like 'account_balance_wallet' that matches
    // NOTE: The map above covers most used ones.

    // 3. Assume it's an Emoji or unknown string -> Render as Text
    return Text(
      name,
      style: TextStyle(
        fontSize: size,
        color: color,
        // Ensure emojis render correctly without forced color if not needed
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Verifica si una cadena es un nombre de icono Material conocido
  static bool isMaterialIcon(String name) {
    return materialIcons.containsKey(name);
  }
}
