# Use PHP 8.4 with Apache
FROM php:8.4-apache

# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    git unzip libpng-dev libonig-dev libxml2-dev zip curl mariadb-client libicu-dev libzip-dev g++ \
    nodejs npm \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd intl zip calendar \
    && a2enmod rewrite

# Set Apache ServerName globally to suppress warning
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Install Composer
COPY --from=composer:2.6 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy project files
COPY . .

# Install PHP dependencies as www-data to avoid permission issues
RUN composer install --no-dev --optimize-autoloader --working-dir=/var/www/html \
    && chown -R www-data:www-data storage bootstrap/cache vendor \
    && chmod -R 775 storage bootstrap/cache

# Install Node dependencies and build front-end assets
RUN npm install --prefix themes/shop/default \
    && npm run production --prefix themes/shop/default \
    && npm install --prefix themes/admin/default \
    && npm run production --prefix themes/admin/default

# Install Bagisto GraphQL package (if not present)
RUN composer require bagisto/bagisto-graphql --working-dir=/var/www/html --no-interaction --optimize-autoloader || echo "GraphQL package already installed"

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose container port
EXPOSE 8080

# Use entrypoint script to start container
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
