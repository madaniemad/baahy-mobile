import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart.dart';

class ReorderSession {
  final List<CartItem> items;
  final Map<String, dynamic>? address;
  final String? paymentMethod;

  const ReorderSession({
    required this.items,
    this.address,
    this.paymentMethod,
  });

  double get subtotal => items.fold(0.0, (s, i) => s + i.total);
}

final reorderSessionProvider = StateProvider<ReorderSession?>((ref) => null);
