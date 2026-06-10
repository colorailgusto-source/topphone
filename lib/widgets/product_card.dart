import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/product_model.dart';
import '../theme/app_theme.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final String? badge;
  final Color? badgeColor;
  final List<Map<String, dynamic>>? variants;
  const ProductCard({super.key, required this.product, this.badge, this.badgeColor, this.variants});

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
                    decoration: BoxDecoration(color: badgeColor ?? AppTheme.success, borderRadius: BorderRadius.circular(8)),
                    child: Text(badge ?? 'NEW', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  )),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(product.marca, style: const TextStyle(color: AppTheme.grey, fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(product.nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textDark), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Flexible(child: Text('€${product.prezzo.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.primary),
                  ),
                ]),
                if (variants != null && variants!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(spacing: 4, runSpacing: 2, children: variants!.map((v) {
                    final ram = (v['ram'] ?? '').toString();
                    final mem = (v['memoria'] ?? '').toString();
                    final extra = (v['prezzo_extra'] as num?)?.toDouble() ?? 0;
                    final prezzo = (product.prezzo + extra).toStringAsFixed(0);
                    final label = ram.isNotEmpty ? '$ram/$mem €$prezzo' : '$mem €$prezzo';
                    return Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)), child: Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.primary, fontWeight: FontWeight.w500)));
                  }).toList()),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
