#!/bin/bash
set -e

# Suppress deprecation warnings
export COMPOSER_ALLOW_SUPERUSER=1
export PHP_INI_SCAN_DIR=/usr/local/etc/php/conf.d
export PHP_ERROR_REPORTING="E_ALL & ~E_DEPRECATED & ~E_STRICT"

echo "=========================================="
echo "Starting MalzCloset container..."
echo "=========================================="

# Generate APP_KEY if missing
php artisan key:generate --force

# Run database migrations
echo "Running migrations..."
php artisan migrate --force

# Check if database is seeded (using cms_pages table as indicator)
SEEDED=$(php artisan tinker --execute="echo DB::table('cms_pages')->count();")
if [ "$SEEDED" -eq 0 ]; then
    echo "Database empty, running seeders..."
    php artisan db:seed --force
else
    echo "Database already seeded, skipping seeders..."
fi

# Install Bagisto GraphQL only if package exists
if composer show | grep -q "bagisto/bagisto-graphql"; then
    echo "Installing Bagisto GraphQL..."
    php artisan bagisto-graphql:install || echo "Bagisto GraphQL already installed, skipping..."
else
    echo "Bagisto GraphQL package not installed, skipping..."
fi

# Cache config, routes, views
echo "Caching config and routes..."
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan storage:link


# Skip front-end build: use prebuilt assets
echo "Using prebuilt front-end assets. Skipping npm build."

# Set Apache port
PORT=${PORT:-8080}
echo "Setting Apache port to $PORT..."
sed -i "s/<VirtualHost \*:80>/<VirtualHost *:${PORT}>/g" /etc/apache2/sites-available/000-default.conf
sed -i "s/Listen 80/Listen ${PORT}/g" /etc/apache2/ports.conf

# Point Apache to Laravel public folder
sed -i "s#/var/www/html#/var/www/html/public#g" /etc/apache2/sites-available/000-default.conf

# Ensure correct permissions
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/themes

# Start Apache in foreground
echo "Starting Apache..."
apache2-foreground
