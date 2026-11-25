#!/usr/bin/env bash
# Uso na VPS (Ubuntu): bash deploy/deploy.sh
set -euo pipefail
cd "$(dirname "$0")/../backend"

[ -f .env ] || { cp .env.example .env; php artisan key:generate; echo ">> Edite backend/.env (PAINEL_USER/PAINEL_PASSWORD) e rode de novo."; exit 0; }

composer install --no-dev --optimize-autoloader
touch database/database.sqlite
php artisan migrate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache
chown -R www-data:www-data storage bootstrap/cache database
echo "OK"
