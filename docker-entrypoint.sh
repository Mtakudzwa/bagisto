#!/bin/bash
set -e

# Suppress deprecation warnings
export COMPOSER_ALLOW_SUPERUSER=1
export PHP_INI_SCAN_DIR=/usr/local/etc/php/conf.d
export PHP_ERROR_REPORTING="E_ALL & ~E_DEPRECATED & ~E_STRICT"

echo "=========================================="
echo " Starting MalzCloset container..."
echo "=========================================="

# Generate APP_KEY if missing
php artisan key:generate --force

# Run database migrations
echo "Running migrations..."
php artisan migrate --force

# Seed database if empty
SEEDED=$(php artisan tinker --execute="echo DB::table('cms_pages')->count();" || echo 0)
if [ "$SEEDED" -eq 0 ]; then
    echo "Database empty, running seeders..."
    php artisan db:seed --force
else
    echo "Database already seeded, skipping seeders..."
fi

# Install Bagisto GraphQL only if not already configured
if [ ! -f config/lighthouse.php ]; then
    echo "Installing Bagisto GraphQL..."
    php artisan bagisto-graphql:install --no-interaction || echo "GraphQL already installed, skipping..."
else
    echo "GraphQL already installed, skipping..."
fi

# Ensure storage directories exist
mkdir -p storage/app/public

# Create storage symlink (ignore error if already exists)
php artisan storage:link || true

# Cache config, routes, views
echo "Caching config and routes..."
php artisan config:clear
php artisan route:clear
php artisan view:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Use prebuilt assets
echo "Using prebuilt front-end assets. Skipping npm build."

# Set Apache port
PORT=${PORT:-8080}
echo "Setting Apache port to $PORT..."
sed -i "s/<VirtualHost \*:80>/<VirtualHost *:${PORT}>/g" /etc/apache2/sites-available/000-default.conf
sed -i "s/Listen 80/Listen ${PORT}/g" /etc/apache2/ports.conf

# Point Apache to Laravel public folder
sed -i "s#/var/www/html#/var/www/html/public#g" /etc/apache2/sites-available/000-default.conf

# Fix permissions
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/themes

# Start Apache in foreground
echo "Starting Apache..."
exec apache2-foreground
