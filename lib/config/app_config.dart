// ============================================================
// CONFIGURAZIONE CENTRALIZZATA — NON ESPORRE CHIAVI SECRET
// Le chiavi secret (Stripe sk_*) devono stare SOLO sul server
// (Supabase Edge Functions), mai nel codice Flutter.
// ============================================================

class AppConfig {
  // ── Supabase ──────────────────────────────────────────────
  static const supabaseUrl = 'https://ehjcqxjspwedqihjjkjf.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVoamNxeGpzcHdlZHFpaGpqa2pmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1OTAwMjMsImV4cCI6MjA5NjE2NjAyM30'
      '.XLebw0DH33-HFhkPOwnBg7v06sBTl_uQ6uistj5Sg6s';

  // ── Stripe (solo chiave PUBBLICA nel client) ───────────────
  // La chiave SECRET (sk_*) deve stare SOLO nella Edge Function
  // create-checkout-session su Supabase. Non aggiungerla mai qui.
  static const stripePublishableKey =
      'pk_test_51S3PnZ2HVMlh4j78UQRBj4UW759TjIzV2icwrFrO08hZqbGqP4wk6rtW4bmk7ovW0lLpI3dRwyspaYoiX65FFq8C00K7WBwa0T';

  // ── Supabase Functions base URL ───────────────────────────
  static const functionsBaseUrl = '$supabaseUrl/functions/v1';
}
