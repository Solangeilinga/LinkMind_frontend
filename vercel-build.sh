#!/bin/bash
set -e

# ─────────────────────────────────────────────────────────────────────────────
# Vercel n'a pas de plugin Flutter intégré (contrairement à Netlify avec
# netlify-plugin-flutter) — ce script reproduit manuellement les mêmes étapes :
# téléchargement du SDK Flutter, puis build web classique.
# ─────────────────────────────────────────────────────────────────────────────

echo "⚡️ Téléchargement du SDK Flutter (stable)..."
git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

echo "🚀 Configuration du canal stable..."
flutter channel stable
flutter --version

echo "📦 Récupération des dépendances..."
flutter pub get

echo "🔨 Build web (release)..."
flutter build web --release

echo "✅ Build terminé — sortie dans build/web"