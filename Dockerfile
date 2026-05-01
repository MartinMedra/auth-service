FROM php:8.4-fpm

RUN apt-get update && apt-get install -y \
    git curl zip unzip libpq-dev libonig-dev libxml2-dev \
    && docker-php-ext-install pdo pdo_pgsql mbstring xml

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Clona el repo directamente desde GitHub
RUN git clone https://github.com/MartinMedra/auth-service /var/www

WORKDIR /var/www

RUN composer install --no-dev --optimize-autoloader \
    && cp .env.example .env \
    && php artisan key:generate

RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache

EXPOSE 8000

CMD php artisan migrate --force && php artisan db:seed --force && php artisan serve --host=0.0.0.0 --port=8000
