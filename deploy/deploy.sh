#!/usr/bin/env bash
# Uso na VPS (Ubuntu), como root: bash deploy/deploy.sh
set -euo pipefail
cd "$(dirname "$0")/../backend"

export COMPOSER_ALLOW_SUPERUSER=1
composer install --no-dev --optimize-autoloader --no-interaction

if [ ! -f .env ]; then
  cp .env.example .env
  php artisan key:generate --force
  echo ">> .env criado. Edite PAINEL_USER e PAINEL_PASSWORD (nano backend/.env) e rode este script de novo."
  exit 0
fi

touch database/database.sqlite
php artisan migrate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache
chown -R www-data:www-data storage bootstrap/cache database
chmod -R ug+rwX storage bootstrap/cache database
echo "OK"
