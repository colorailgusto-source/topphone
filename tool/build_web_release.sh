#!/bin/bash
# Build web release with all dart-define variables

set -e

# Load .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Check required vars
required_vars=("SUPABASE_URL" "SUPABASE_PUBLISHABLE_KEY" "STRIPE_PUBLISHABLE_KEY" "FUNCTIONS_BASE_URL" "FIREBASE_API_KEY" "FIREBASE_AUTH_DOMAIN" "FIREBASE_PROJECT_ID" "FIREBASE_STORAGE_BUCKET" "FIREBASE_MESSAGING_SENDER_ID" "FIREBASE_APP_ID")
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "❌ Missing env var: $var"
    exit 1
  fi
done

# Build with all dart-defines
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY" \
  --dart-define=STRIPE_PUBLISHABLE_KEY="$STRIPE_PUBLISHABLE_KEY" \
  --dart-define=FUNCTIONS_BASE_URL="$FUNCTIONS_BASE_URL" \
  --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_APP_ID="$FIREBASE_APP_ID"

echo "✅ Build completed successfully"
