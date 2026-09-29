FROM php:8.3-apache

# Instalar PDO MySQL y activar mod_rewrite
RUN docker-php-ext-install pdo_mysql \
    && a2enmod rewrite

# Copiar proyecto
COPY . /var/www/html/

# Permitir .htaccess
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' \
    /etc/apache2/apache2.conf

# Permisos
RUN chown -R www-data:www-data /var/www/html

# Puerto de Render
ENV PORT=10000

# Configurar Apache para Render
RUN sed -i 's/Listen 80/Listen 10000/' /etc/apache2/ports.conf && \
    sed -i 's/:80>/:10000>/' /etc/apache2/sites-available/000-default.conf

EXPOSE 10000

CMD ["apache2-foreground"]
