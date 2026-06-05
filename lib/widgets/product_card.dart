import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/product_model.dart';
import '../theme/app_theme.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/product/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 130,
                    width: double.infinity,
                    child: product.immagine.isNotEmpty
                      ? Image.network(
                          product.immagine,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => Container(
                            color: AppTheme.background,
                            child: const Center(child: Icon(Icons.phone_android, size: 60, color: AppTheme.primary)),
                          ),
                        )
                      : Container(
                          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
                          child: const Center(child: Icon(Icons.phone_android, size: 60, color: Colors.white)),
                        ),
                  ),
                  Positioned(top: 8, right: 8, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(8)),
                    child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  )),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.marca, style: const TextStyle(color: AppTheme.grey, fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(product.nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textDark), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('€${product.prezzo.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 16)),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.primary),
                  ),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
