import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 80),
              ),
              const SizedBox(height: 32),
              const Text('Ordine Completato!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
              const SizedBox(height: 12),
              const Text('Grazie per il tuo acquisto!\nRiceverai una notifica quando il tuo ordine sarà pronto.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.grey, fontSize: 15)),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
                ),
                child: const Column(children: [
                  Row(children: [
                    Icon(Icons.store, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text('Top Phone Torre', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                  ]),
                  SizedBox(height: 8),
                  Text('Via Nazionale 68, Torre del Greco', style: TextStyle(color: AppTheme.grey)),
                  Text('081 341 7717', style: TextStyle(color: AppTheme.grey)),
                ]),
              ),
              const SizedBox(height: 32),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () => context.go('/orders'),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Vedi i miei ordini'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              )),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home),
                label: const Text('Torna alla Home'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
