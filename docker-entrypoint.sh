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

# Run database migrations only if table doesn't exist to avoid duplicates
echo "Running migrations..."
php artisan migrate --force || true

# Seed database only if not already seeded
echo "Seeding database..."
php artisan db:seed --force || echo "Database already seeded, skipping..."

# Install Bagisto GraphQL (ignore errors if already installed)
echo "Installing Bagisto GraphQL..."
php artisan bagisto-graphql:install || true

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
