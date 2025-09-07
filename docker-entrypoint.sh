#!/bin/bash
set -e

echo "=========================================="
echo "Starting MalzCloset container..."
echo "=========================================="

# Ensure APP_KEY exists
if [ -z "$APP_KEY" ]; then
    echo "Generating APP_KEY..."
    php artisan key:generate --force
fi

# Run database migrations
echo "Running migrations..."
php artisan migrate --force

# Seed the database
echo "Seeding database..."
php artisan db:seed --force

# Install Bagisto GraphQL
echo "Installing Bagisto GraphQL..."
php artisan bagisto-graphql:install || true

# Cache config, routes, views
echo "Caching config and routes..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Replace Apache port with Railway $PORT
echo "Setting Apache port to $PORT..."
sed -i "s/80/${PORT}/g" /etc/apache2/sites-available/000-default.conf

# Start Apache
echo "Starting Apache..."
apache2-foreground
