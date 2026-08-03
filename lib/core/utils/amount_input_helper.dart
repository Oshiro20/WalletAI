import 'package:flutter/material.dart';

/// Helper para auto-limpiar campos de texto de monto cuando tienen valor 0 o 0.00 al recibir tap/enfoque.
void clearAmountIfZero(TextEditingController controller) {
  final text = controller.text.trim().replaceAll(',', '.');
  if (text.isEmpty) return;
  final num = double.tryParse(text);
  if (num != null && num == 0) {
    controller.clear();
  }
}
