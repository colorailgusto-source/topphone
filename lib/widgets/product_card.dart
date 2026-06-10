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
                if (variants == null || variants!.isEmpty)
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Flexible(child: Text('€\${product.prezzo.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.primary),
                    ),
                  ]),
                if (variants != null && variants!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Builder(builder: (ctx) {
                    // Raggruppa per prezzo unico
                    final seen = <String>{};
                    final unique = variants!.where((v) {
                      final key = '${v['ram'] ?? ''}|${v['prezzo_extra']}';
                      return seen.add(key);
                    }).toList();
                    // Se nessuna RAM → mostra solo memoria sotto il prezzo
                    final hasRam = unique.any((v) => (v['ram'] ?? '').toString().isNotEmpty);
                    if (!hasRam) {
                      final mem = (unique[0]['memoria'] ?? '').toString();
                      return Text(mem, style: const TextStyle(fontSize: 11, color: AppTheme.grey, fontWeight: FontWeight.w500));
                    }
                    // Se solo 1 variante con RAM → mostra prezzo normale (già mostrato sopra)
                    if (unique.length == 1) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: unique.map((v) {
                        final ram = (v['ram'] ?? '').toString();
                        final mem = (v['memoria'] ?? '').toString();
                        final extra = (v['prezzo_extra'] as num?)?.toDouble() ?? 0;
                        final prezzo = (product.prezzo + extra).toStringAsFixed(0);
                        final label = ram.isNotEmpty ? '$ram/$mem' : mem;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: GestureDetector(
                            onTap: () => context.push('/product/\${product.id}', extra: ram),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.grey, fontWeight: FontWeight.w500)),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text('€\$prezzo', style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.arrow_forward_ios, size: 8, color: AppTheme.primary),
                                ]),
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
