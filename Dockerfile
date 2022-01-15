FROM php:7.4-fpm-alpine3.14 as base

RUN apk update && apk add g++ make wget ca-certificates openssl openssh bzip2-dev zlib-dev libpng-dev tzdata fcgi cyrus-sasl-dev

RUN \
	# Install git and zip used by composer when fetching dependencies.
	apk add git unzip \
	\
	# Install bash.
	&& apk add bash \
	\
	# Install patch utility that may be usefull to patch dependencies.
	&& apk add patch

# install php packages
# possible options in `docker-php-exe-install'
# bcmath   |fileinfo |json      |pdo_firebird |readline   |standard   |zend_test
# bz2      |filter   |ldap      |pdo_mysql    |reflection |sysvmsg    |zip
# calendar |ftp      |mbstring  |pdo_oci      |session    |sysvsem
# ctype    |gd       |mysqli    |pdo_odbc     |shmop      |sysvshm
# curl     |gettext  |oci8      |pdo_pgsql    |simplexml  |tidy
# dba      |gmp      |odbc      |pdo_sqlite   |snmp       |tokenizer
# dom      |hash     |opcache   |pgsql        |soap       |xml
# enchant  |iconv    |pcntl     |phar         |sockets    |xmlreader
# exif     |imap     |pdo       |posix        |sodium     |xmlwriter
# ffi      |intl     |pdo_dblib |pspell       |spl        |xsl

RUN docker-php-ext-install gd

## Install Memcache and redis
ENV MEMCACHE_DEPS zlib-dev cyrus-sasl-dev php7-dev g++ make git
RUN apk add --no-cache -t .phpize-deps $PHPIZE_DEPS && \
	apk add --no-cache -t .memcache-deps $MEMCACHE_DEPS && \
	## Prepare php for extensions
	apk add --no-cache -u \
	# Install timezone util
	tzdata \
	## fpm healthcheck status check dep
	fcgi \
	zlib-dev \
	&& \
	# Install php-redis
	pecl install redis -y && \
	docker-php-ext-enable redis && \
	# Install memcache
	cd /tmp && git clone https://github.com/websupport-sk/pecl-memcache && \
	cd pecl-memcache && \
	phpize && \
	./configure && \
	make && \
	make install && \
	docker-php-ext-enable memcache && \
	## PHP extensions
	docker-php-ext-install -j$(nproc) bcmath && \
	# Install pcntl
	docker-php-ext-install pcntl && \
	apk del .phpize-deps && \
	apk del .memcache-deps

# install the PHP extensions we need
RUN set -eux; \
	\
	apk add --no-cache --virtual .build-deps \
		coreutils \
		freetype-dev \
		libjpeg-turbo-dev \
		libpng-dev \
		libzip-dev \
# postgresql-dev is needed for https://bugs.alpinelinux.org/issues/3642
		postgresql-dev \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype \
		--with-jpeg=/usr/include \
	; \
	\
	docker-php-ext-install -j "$(nproc)" \
		gd \
		opcache \
		pdo_mysql \
		pdo_pgsql \
		zip \
	; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-network --virtual .drupal-phpexts-rundeps $runDeps; \
	apk del --no-network .build-deps

RUN cp /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini && \
    sed -i "s|^;date.timezone =.*$|date.timezone = Europe/Paris|" /usr/local/etc/php/php.ini && \
    sed -i "s|display_startup_errors =.*$|display_startup_errors = On|" /usr/local/etc/php/php.ini && \
    sed -i "s|display_errors =.*$|display_errors = On|" /usr/local/etc/php/php.ini && \
    sed -i "s|^;error_log =.*$|error_log = /var/log/php/php-error.log|" /usr/local/etc/php/php.ini

RUN curl -LkSso /usr/bin/mhsendmail 'https://github.com/mailhog/mhsendmail/releases/download/v0.2.0/mhsendmail_linux_amd64'&& \
    chmod 0755 /usr/bin/mhsendmail && \
    echo 'sendmail_path = "/usr/bin/mhsendmail --from=nobody@7bd822a2c191 --smtp-addr=mailhog:1025"' >> /usr/local/etc/php/php.ini;

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# PHP Xdebug
FROM base as dev
ENV XDEBUG_CONF=/usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
RUN apk add --no-cache -t .deps $PHPIZE_DEPS && \
    pecl install xdebug && \
    docker-php-ext-enable xdebug

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/

WORKDIR /var/www/html

ENV PATH=${PATH}:/var/www/html/vendor/bin
