FROM php:8.1-apache

# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    git unzip libpng-dev libonig-dev libxml2-dev zip curl mariadb-client libicu-dev libzip-dev g++ \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd intl zip \
    && docker-php-ext-enable intl zip

# Try enabling calendar, ignore if not available
RUN docker-php-ext-install calendar || true

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Install Composer
COPY --from=composer:2.6 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy project files
COPY . .

# Install PHP dependencies (at build time)
RUN composer install --no-interaction --prefer-dist --optimize-autoloader || true

# Permissions
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 8080

# Entrypoint script to run migrations before Apache
CMD php artisan key:generate --force && \
    php artisan migrate --force && \
    php artisan db:seed --force && \
    php artisan bagisto-graphql:install && \
    apache2-foreground
