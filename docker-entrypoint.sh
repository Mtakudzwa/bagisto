#!/bin/bash
set -e

echo "=========================================="
echo "Starting MalzCloset container..."
echo "=========================================="

# Generate APP_KEY if missing
if [ -f /var/www/html/.env ]; then
    CURRENT_KEY=$(grep APP_KEY /var/www/html/.env | cut -d '=' -f2)
    if [ -z "$CURRENT_KEY" ]; then
        echo "Generating APP_KEY..."
        php artisan key:generate --force
    else
        echo "APP_KEY already set"
    fi
else
    echo ".env not found, skipping key generation"
fi

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

# Set Apache port to Railway $PORT
PORT=${PORT:-8080}  # Default to 8080 if $PORT is empty
echo "Setting Apache port to $PORT..."
sed -i "s/<VirtualHost \*:80>/<VirtualHost *:${PORT}>/g" /etc/apache2/sites-available/000-default.conf
sed -i "s/Listen 80/Listen ${PORT}/g" /etc/apache2/ports.conf

# Start Apache in foreground
echo "Starting Apache..."
apache2-foreground
