# Use PHP 8.4 with Apache
FROM php:8.4-apache

# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    git unzip libpng-dev libjpeg-dev libfreetype6-dev libonig-dev libxml2-dev \
    libwebp-dev \
    zip curl mariadb-client libicu-dev libzip-dev g++ \
    && docker-php-ext-configure gd --with-jpeg --with-freetype --with-webp \
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

# Copy prebuilt theme assets (avoid npm build in container)
COPY public/themes/shop/default/build /var/www/html/themes/shop/default/build
COPY public/themes/admin/default/build /var/www/html/themes/admin/default/build

# Install PHP dependencies
RUN composer install --no-dev --optimize-autoloader --working-dir=/var/www/html \
    && chown -R www-data:www-data storage bootstrap/cache vendor themes \
    && chmod -R 775 storage bootstrap/cache

# Install Bagisto GraphQL package (only if not already installed)
RUN if ! composer show | grep -q "bagisto/graphql-api"; then \
      composer require bagisto/graphql-api:^2.3 --working-dir=/var/www/html --no-interaction --optimize-autoloader; \
    fi

# Ensure storage directory exists for symlinks
RUN mkdir -p storage/app/public

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose container port
EXPOSE 8080

# Use entrypoint script to start container
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
