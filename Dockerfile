# =============================================================================
#  Medicard — single Dockerfile
#  Stages:  vendor → runtime (PHP)  |  node (Vue dev)
#  Использование в docker-compose через: target: runtime / target: node
# =============================================================================

# ── Stage 1: Composer зависимости ────────────────────────────────────────────
FROM composer:2.8 AS vendor

WORKDIR /app

COPY backend/composer.json backend/composer.lock ./

RUN composer install \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --ignore-platform-reqs

COPY backend/ .

RUN composer dump-autoload --optimize --no-dev

# ── Stage 2: PHP runtime (Laravel 12) ────────────────────────────────────────
FROM php:8.3-fpm-alpine AS runtime

RUN apk add --no-cache \
        libpq-dev \
        libzip-dev \
        oniguruma-dev \
        icu-dev \
    && docker-php-ext-install -j$(nproc) \
        pdo_pgsql \
        zip \
        bcmath \
        mbstring \
        pcntl \
        intl \
    && docker-php-ext-enable opcache \
    && rm -rf /tmp/* /var/cache/apk/*

COPY docker/php/php.ini /usr/local/etc/php/conf.d/custom.ini

WORKDIR /var/www

COPY --from=vendor /app .

RUN chown -R www-data:www-data /var/www \
    && chmod -R 755 /var/www/storage

EXPOSE 9000
CMD ["php-fpm"]

# ── Stage 3: Vue.js 3.5 dev (hot reload) ─────────────────────────────────────
FROM node:22-alpine AS node

WORKDIR /app

COPY frontend/package.json frontend/package-lock.json* ./

RUN npm ci --prefer-offline

COPY frontend/ .

EXPOSE 5173
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]