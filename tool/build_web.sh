#!/bin/bash
# Build script for web - processes template with env vars
# Usage: ./tool/build_web.sh

set -e

# Load .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Check required vars
required_vars=("FIREBASE_API_KEY" "FIREBASE_AUTH_DOMAIN" "FIREBASE_PROJECT_ID" "FIREBASE_STORAGE_BUCKET" "FIREBASE_MESSAGING_SENDER_ID" "FIREBASE_APP_ID")
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "❌ Missing env var: $var"
    exit 1
  fi
done

# Process template
sed \
  -e "s/{{FIREBASE_API_KEY}}/$FIREBASE_API_KEY/g" \
  -e "s/{{FIREBASE_AUTH_DOMAIN}}/$FIREBASE_AUTH_DOMAIN/g" \
  -e "s/{{FIREBASE_PROJECT_ID}}/$FIREBASE_PROJECT_ID/g" \
  -e "s/{{FIREBASE_STORAGE_BUCKET}}/$FIREBASE_STORAGE_BUCKET/g" \
  -e "s/{{FIREBASE_MESSAGING_SENDER_ID}}/$FIREBASE_MESSAGING_SENDER_ID/g" \
  -e "s/{{FIREBASE_APP_ID}}/$FIREBASE_APP_ID/g" \
  web/index.html.template > web/index.html

echo "✅ Generated web/index.html from template"