#!/bin/bash

# Global parameters
DB_NAME=mohtncdb
DB_USER=mohtuser
DB_PSWD='abcd1234!@#$'
INST_PATH=/usr/share

if [ $# == 0 ]; then
	echo "Usage: $0 nextcloud.tar.gz [port] [DNS] [IP]"
	echo "This will install nextcloud into the current directory, please goto install path first."
	exit 1
fi

if [ "`whoami`" != root ]; then
	echo "This script can only be run by root!"
	exit 1
fi

# check pre-requisite
if [ ! "`dpkg -l php7.3-fpm`" ]; then
	echo "Error: php7.3-fpm is not installed!"
	exit 1
elif [ ! "`which mariadb`" ]; then
	echo "Error: mariadb is not installed!"
	exit 1
elif [ ! "`which nginx`" ]; then
	echo "Error: nginx is not installed"
	exit 1
fi

set -e -x -o pipefail

# refresh all files
cd "$INST_PATH"
rm -rf nextcloud
tar -xf "$1"
chown -R www-data:www-data nextcloud


# init MySQL
set +e
mariadb -u root -e "drop database $DB_NAME;"
mariadb -u root -e "drop user $DB_USER@localhost;"

mariadb -u root -e "create database $DB_NAME;"
mariadb -u root -e "create user $DB_USER@localhost identified by '$DB_PSWD';"
mariadb -u root -e "grant all privileges on $DB_NAME.* to $DB_USER@localhost identified by '$DB_PSWD';"
mariadb -u root -e "flush privileges;"
set -e


# add nginx config files if absent
if [ ! -s /etc/nginx/conf.d/nextcloud.conf ] && [ $# -ge 4 ]; then
echo >/etc/nginx/conf.d/nextcloud.conf <<EOF
server {
    listen $2 ssl;
    server_name $3 $4;

    # Add headers to serve security related headers
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header X-Download-Options noopen;
    add_header X-Permitted-Cross-Domain-Policies none;
    add_header Referrer-Policy no-referrer;
	add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    #I found this header is needed on Ubuntu, but not on Arch Linux. 
    add_header X-Frame-Options "SAMEORIGIN";

    # Path to the root of your installation
    root /usr/share/nextcloud/;

    access_log /var/log/nginx/nextcloud.access;
    error_log /var/log/nginx/nextcloud.error;

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    # The following 2 rules are only needed for the user_webfinger app.
    # Uncomment it if you're planning to use this app.
    #rewrite ^/.well-known/host-meta /public.php?service=host-meta last;
    #rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json
    # last;

    location = /.well-known/carddav {
        return 301 \$scheme://\$host/remote.php/dav;
    }
    location = /.well-known/caldav {
       return 301 \$scheme://\$host/remote.php/dav;
    }

    location ~ /.well-known/acme-challenge {
      allow all;
    }

    # set max upload size
    client_max_body_size 512M;
    fastcgi_buffers 64 4K;

    # Disable gzip to avoid the removal of the ETag header
    gzip off;

    # Uncomment if your server is build with the ngx_pagespeed module
    # This module is currently not supported.
    #pagespeed off;

    error_page 403 /core/templates/403.php;
    error_page 404 /core/templates/404.php;

    location / {
       rewrite ^ /index.php\$uri;
    }

    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/ {
       deny all;
    }
    location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console) {
       deny all;
     }

    location ~ ^/(?:index|remote|public|cron|core/ajax/update|status|ocs/v[12]|updater/.+|ocs-provider/.+|core/templates/40[34])\.php(?:$|/) {
       include fastcgi_params;
       fastcgi_split_path_info ^(.+\.php)(/.*)$;
       fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
       fastcgi_param PATH_INFO \$fastcgi_path_info;
       #Avoid sending the security headers twice
       fastcgi_param modHeadersAvailable true;
       fastcgi_param front_controller_active true;
       fastcgi_pass unix:/run/php/php7.3-fpm.sock;
       fastcgi_intercept_errors on;
       fastcgi_request_buffering off;
    }

    location ~ ^/(?:updater|ocs-provider)(?:$|/) {
       try_files \$uri/ =404;
       index index.php;
    }

    # Adding the cache control header for js and css files
    # Make sure it is BELOW the PHP block
    location ~* \.(?:css|js)$ {
        try_files \$uri /index.php\$uri\$is_args\$args;
        add_header Cache-Control "public, max-age=7200";
        # Add headers to serve security related headers (It is intended to
        # have those duplicated to the ones above)
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header X-Robots-Tag none;
        add_header X-Download-Options noopen;
        add_header X-Permitted-Cross-Domain-Policies none;
        add_header Referrer-Policy no-referrer;
        # Optional: Don't log access to assets
        access_log off;
   }

   location ~* \.(?:svg|gif|png|html|ttf|woff|ico|jpg|jpeg)$ {
        try_files \$uri /index.php\$uri\$is_args\$args;
        # Optional: Don't log access to other assets
        access_log off;
   }
}
EOF


# restart system services
systemctl restart php7.3-fpm nginx mariadb

