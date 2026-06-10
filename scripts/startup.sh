#!/bin/bash
###############################################################################
# Startup Script - Instalación y Configuración de WordPress
# Proyecto: EDUFIS - WordPress en GCP
#
# Este script se ejecuta automaticamente al crear la VM.
# Instala: Apache, PHP 8.1, MySQL 8.0, WordPress (ultima version)
#
# Las variables son reemplazadas por Terraform via templatefile()
###############################################################################

set -euo pipefail

# ─── Variables de entorno (inyectadas por Terraform) ─────────────────────────
PROJECT_ID="${project_id}"
DB_NAME="${db_name}"
DB_USER="${db_user}"
DB_PASSWORD_SECRET_ID="${db_password_secret_id}"
DB_PASS=""
WP_ADMIN_EMAIL="${wp_admin_email}"
WP_DOMAIN="${wp_domain}"
WP_TABLE_PREFIX="${wp_table_prefix}"
WP_SOURCE_URL="${wp_source_url}"
WP_TARGET_URL="${wp_target_url}"
WP_SOURCE_GCS_URI="${wordpress_source_gcs_uri}"
WP_DB_DUMP_GCS_URI="${wordpress_db_dump_gcs_uri}"
GCS_ACCESS_DEPENDENCY="${gcs_access_dependency}"
SECRET_ACCESS_DEPENDENCY="${secret_access_dependency}"

# ─── Logging ─────────────────────────────────────────────────────────────────
LOG_FILE="/var/log/startup-script.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=========================================="
echo "Inicio del startup script: $(date)"
echo "=========================================="

# ─── Función de utilidad ─────────────────────────────────────────────────────
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

empty_dir() {
  local target_dir="$1"

  rm -rf "$target_dir"/* "$target_dir"/.[!.]* "$target_dir"/..?*
}

gcs_cp() {
  local source="$1"
  local destination="$2"

  if command -v gcloud >/dev/null 2>&1; then
    gcloud storage cp "$source" "$destination"
  elif command -v gsutil >/dev/null 2>&1; then
    gsutil cp "$source" "$destination"
  else
    log "No se encontro gcloud ni gsutil para copiar desde GCS."
    return 1
  fi
}

load_db_password() {
  if [ -z "$DB_PASSWORD_SECRET_ID" ]; then
    log "No se configuro db_password_secret_id. No se puede configurar MySQL."
    return 1
  fi

  if ! command -v gcloud >/dev/null 2>&1; then
    log "No se encontro gcloud para leer la contraseña desde Secret Manager."
    return 1
  fi

  DB_PASS="$(gcloud secrets versions access latest --secret="$DB_PASSWORD_SECRET_ID" --project="$PROJECT_ID")"
  if [ -z "$DB_PASS" ]; then
    log "El secreto $DB_PASSWORD_SECRET_ID no devolvio una contraseña valida."
    return 1
  fi
}

gcs_cp_prefix_preserve_paths() {
  local source="$1"
  local destination="$2"
  local normalized_source="$${source%/}/"
  local object
  local relative_path
  local target_path

  gcloud storage ls --recursive "$${normalized_source}**" | while IFS= read -r object; do
    case "$object" in
      ""|*:)
        continue
        ;;
      */)
        continue
        ;;
    esac

    relative_path="$${object#$normalized_source}"
    if [ "$relative_path" = "$object" ] || [ -z "$relative_path" ]; then
      continue
    fi

    target_path="$destination/$relative_path"
    mkdir -p "$(dirname "$target_path")"
    gcloud storage cp "$object" "$target_path"
  done
}

gcs_cp_dir() {
  local source="$1"
  local destination="$2"

  if command -v gsutil >/dev/null 2>&1; then
    gsutil -m cp -r "$source" "$destination"
  elif command -v gcloud >/dev/null 2>&1; then
    gcloud storage cp --recursive "$source" "$destination"
  else
    log "No se encontro gcloud ni gsutil para copiar directorios desde GCS."
    return 1
  fi
}

gcs_copy_wordpress_tree() {
  local source="$1"
  local target_dir="$2"
  local normalized_source="$${source%/}"

  if command -v gsutil >/dev/null 2>&1; then
    log "Sincronizando WordPress con gsutil rsync desde GCS. Esto preserva estructura y paraleliza la copia."
    gsutil -m rsync -r -d -x '.*\.sql(\.gz)?$' "$normalized_source" "$target_dir"
  elif command -v gcloud >/dev/null 2>&1; then
    log "gsutil no esta disponible. Usando gcloud storage rsync como respaldo."
    gcloud storage rsync --recursive --delete-unmatched-destination-objects "$normalized_source" "$target_dir"
  else
    log "No se encontro gcloud ni gsutil para sincronizar WordPress desde GCS."
    return 1
  fi

  log "Sincronizacion de WordPress desde GCS completada."
}

remove_database_dumps_from_webroot() {
  local target_dir="$1"

  find "$target_dir" -type f \( -iname '*.sql' -o -iname '*.sql.gz' -o -iname '*.sql.zip' \) -delete
}

ensure_wordpress_core() {
  local target_dir="$1"

  if [ -d "$target_dir/wp-admin" ] && [ -d "$target_dir/wp-includes" ] && [ -f "$target_dir/wp-config-sample.php" ]; then
    return
  fi

  log "El core de WordPress esta incompleto. Descargando core oficial para completar wp-admin/wp-includes."
  download_latest_wordpress "$target_dir"
}

validate_wordpress_files() {
  local target_dir="$1"

  if [ ! -d "$target_dir/wp-admin" ]; then
    log "Falta wp-admin en $target_dir."
    return 1
  fi

  if [ ! -d "$target_dir/wp-content" ]; then
    log "Falta wp-content en $target_dir."
    return 1
  fi

  if [ ! -d "$target_dir/wp-includes" ]; then
    log "Falta wp-includes en $target_dir."
    return 1
  fi

  if [ ! -f "$target_dir/wp-config-sample.php" ]; then
    log "Falta wp-config-sample.php en $target_dir."
    return 1
  fi
}

gcs_rsync() {
  local source="$1"
  local destination="$2"

  if command -v gsutil >/dev/null 2>&1; then
    gsutil -m rsync -r "$source" "$destination"
    return
  fi

  if command -v gcloud >/dev/null 2>&1; then
    if gcloud storage rsync --recursive "$source" "$destination"; then
      return 0
    fi

    # Some buckets contain a zero-byte object with the same name as the
    # directory prefix, for example gs://bucket/wordpress/. In that case
    # gcloud storage rsync can match both the object and the prefix.
    log "No se pudo sincronizar con rsync. Reintentando con copia recursiva desde el prefijo GCS."
    gcs_cp_prefix_preserve_paths "$source" "$destination"
  else
    log "No se encontro gcloud ni gsutil para sincronizar desde GCS."
    return 1
  fi
}

install_wordpress_from_archive() {
  local archive="$1"
  local target_dir="$2"
  local extract_dir="/tmp/wordpress-source"
  local source_dir

  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"

  case "$archive" in
    *.zip)
      unzip -q "$archive" -d "$extract_dir"
      ;;
    *.tar.gz|*.tgz)
      tar -xzf "$archive" -C "$extract_dir"
      ;;
    *)
      log "El archivo $archive no es un ZIP/TAR soportado."
      return 1
      ;;
  esac

  source_dir="$(find_wordpress_source_dir "$extract_dir")"

  if [ -d "$source_dir/wp-admin" ] && [ -d "$source_dir/wp-includes" ]; then
    empty_dir "$target_dir"
    cp -a "$source_dir"/. "$target_dir"/
  elif [ -d "$source_dir/wp-content" ]; then
    log "El archivo contiene wp-content. Descargando core oficial y aplicando contenido migrado."
    empty_dir "$target_dir"
    download_latest_wordpress "$target_dir"
    rm -rf "$target_dir/wp-content"
    cp -a "$source_dir/wp-content" "$target_dir/"
  else
    log "El archivo indicado no contiene una instalacion reconocible de WordPress."
    return 1
  fi
}

download_latest_wordpress() {
  local target_dir="$1"

  cd /tmp
  rm -rf /tmp/wordpress /tmp/latest.tar.gz
  wget -q https://wordpress.org/latest.tar.gz
  tar -xzf latest.tar.gz
  cp -a wordpress/. "$target_dir/"
  rm -rf /tmp/wordpress /tmp/latest.tar.gz
}

find_wordpress_source_dir() {
  local extract_dir="$1"
  local source_dir="$extract_dir"

  if [ ! -d "$source_dir/wp-content" ]; then
    local wp_content_dir
    wp_content_dir="$(find "$extract_dir" -mindepth 1 -maxdepth 4 -type d -name wp-content | head -n 1 || true)"
    if [ -n "$wp_content_dir" ]; then
      source_dir="$(dirname "$wp_content_dir")"
    fi
  fi

  echo "$source_dir"
}

install_wordpress_files() {
  local target_dir="$1"

  if [ -z "$WP_SOURCE_GCS_URI" ]; then
    log "No se configuro fuente GCS. Descargando WordPress oficial."
    download_latest_wordpress "$target_dir"
    return
  fi

  log "Instalando WordPress desde GCS: $WP_SOURCE_GCS_URI"
  empty_dir "$target_dir"

  case "$WP_SOURCE_GCS_URI" in
    *.zip)
      local archive="/tmp/wordpress-source.zip"

      rm -f "$archive"
      gcs_cp "$WP_SOURCE_GCS_URI" "$archive"
      install_wordpress_from_archive "$archive" "$target_dir"
      ;;
    *.tar.gz|*.tgz)
      local archive="/tmp/wordpress-source.tar.gz"

      rm -f "$archive"
      gcs_cp "$WP_SOURCE_GCS_URI" "$archive"
      install_wordpress_from_archive "$archive" "$target_dir"
      ;;
    *)
      gcs_copy_wordpress_tree "$WP_SOURCE_GCS_URI" "$target_dir"

      if [ ! -d "$target_dir/wp-admin" ] && [ -d "$target_dir/wordpress/wp-admin" ]; then
        cp -a "$target_dir/wordpress"/. "$target_dir"/
        rm -rf "$target_dir/wordpress"
      fi

      if [ ! -d "$target_dir/wp-admin" ] && [ -d "$target_dir/wp-content" ]; then
        log "La fuente GCS contiene wp-content sin core. Descargando core oficial."
        local tmp_content="/tmp/wp-content-migrated"
        rm -rf "$tmp_content"
        mv "$target_dir/wp-content" "$tmp_content"
        empty_dir "$target_dir"
        download_latest_wordpress "$target_dir"
        rm -rf "$target_dir/wp-content"
        mv "$tmp_content" "$target_dir/wp-content"
      fi

      if [ ! -d "$target_dir/wp-content" ]; then
        log "La fuente GCS indicada no contiene archivos reconocibles de WordPress."
        return 1
      fi
      ;;
  esac

  ensure_wordpress_core "$target_dir"
  validate_wordpress_files "$target_dir"
  remove_database_dumps_from_webroot "$target_dir"
}

import_wordpress_database() {
  if [ -z "$WP_DB_DUMP_GCS_URI" ]; then
    log "No se configuro dump SQL en GCS. Se deja la base vacia para instalacion inicial."
    return
  fi

  log "Importando dump de base de datos desde GCS: $WP_DB_DUMP_GCS_URI"
  local dump_file="/tmp/wordpress-db-dump"

  rm -f "$dump_file"
  gcs_cp "$WP_DB_DUMP_GCS_URI" "$dump_file"

  log "Recreando base de datos destino antes de importar el dump."
  mysql -u root <<MYSQL_RESET_DB
DROP DATABASE IF EXISTS \`$DB_NAME\`;
CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_RESET_DB

  case "$WP_DB_DUMP_GCS_URI" in
    *.gz)
      local sql_file="/tmp/wordpress-db-dump.sql"

      rm -f "$sql_file"
      gzip -dc "$dump_file" > "$sql_file"
      import_sql_file "$sql_file" "$DB_NAME"
      ;;
    *.zip)
      local sql_entry
      local sql_file="/tmp/wordpress-db-dump.sql"

      sql_entry="$(unzip -Z1 "$dump_file" | grep -Ei '\\.sql$' | head -n 1 || true)"
      if [ -z "$sql_entry" ]; then
        log "El ZIP de base de datos no contiene un archivo .sql."
        return 1
      fi
      rm -f "$sql_file"
      unzip -p "$dump_file" "$sql_entry" > "$sql_file"
      import_sql_file "$sql_file" "$DB_NAME"
      ;;
    *)
      import_sql_file "$dump_file" "$DB_NAME"
      ;;
  esac
}

import_sql_file() {
  local sql_file="$1"
  local database="$2"
  local first_bytes
  local file_info

  first_bytes="$(od -An -tx1 -N2 "$sql_file" | tr -d ' \n')"
  file_info="$(file -bi "$sql_file" 2>/dev/null || true)"

  case "$first_bytes" in
    fffe)
      log "El dump SQL esta en UTF-16LE. Convirtiendo a UTF-8 antes de importar."
      iconv -f UTF-16LE -t UTF-8 "$sql_file" | mysql --default-character-set=utf8mb4 -u root "$database"
      ;;
    feff)
      log "El dump SQL esta en UTF-16BE. Convirtiendo a UTF-8 antes de importar."
      iconv -f UTF-16BE -t UTF-8 "$sql_file" | mysql --default-character-set=utf8mb4 -u root "$database"
      ;;
    *)
      if printf '%s' "$file_info" | grep -qi 'utf-16'; then
        log "El dump SQL fue detectado como UTF-16. Convirtiendo a UTF-8 antes de importar."
        iconv -f UTF-16 -t UTF-8 "$sql_file" | mysql --default-character-set=utf8mb4 -u root "$database"
      else
        mysql --default-character-set=utf8mb4 -u root "$database" < "$sql_file"
      fi
      ;;
  esac
}

install_wp_cli() {
  if command -v wp >/dev/null 2>&1; then
    return
  fi

  log "Instalando WP-CLI..."
  curl -fsS -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x /usr/local/bin/wp
}

replace_wordpress_urls() {
  local wp_dir="$1"

  local target_url="$WP_TARGET_URL"
  if [ -z "$target_url" ]; then
    target_url="https://$WP_DOMAIN"
  fi

  install_wp_cli
  log "Configurando URL publica de WordPress: $target_url"
  wp --path="$wp_dir" config set WP_HOME "$target_url" --type=constant --allow-root
  wp --path="$wp_dir" config set WP_SITEURL "$target_url" --type=constant --allow-root
  wp --path="$wp_dir" option update home "$target_url" --allow-root
  wp --path="$wp_dir" option update siteurl "$target_url" --allow-root

  if [ -z "$WP_SOURCE_URL" ]; then
    log "No se configuro URL origen. Se omite search-replace de WordPress."
    return
  fi

  if [ "$WP_SOURCE_URL" = "$target_url" ]; then
    log "La URL origen y destino son iguales. Se omite search-replace."
    return
  fi

  log "Reemplazando URL de WordPress: $WP_SOURCE_URL -> $target_url"
  wp --path="$wp_dir" search-replace "$WP_SOURCE_URL" "$target_url" \
    --all-tables-with-prefix \
    --precise \
    --skip-columns=guid \
    --allow-root
  wp --path="$wp_dir" cache flush --allow-root || true
  wp --path="$wp_dir" rewrite flush --allow-root || true
  wp --path="$wp_dir" elementor flush_css --allow-root || true
}

# ─── Verificar si ya se ejecutó ──────────────────────────────────────────────
if [ -f /opt/wordpress-installed ]; then
  log "WordPress ya está instalado. Verificando servicios..."
  systemctl start apache2 || true
  systemctl start mysql || true
  log "Servicios verificados. Saliendo."
  exit 0
fi

# ─── Actualizar sistema ─────────────────────────────────────────────────────
log "Actualizando paquetes del sistema..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

# ─── Instalar dependencias ──────────────────────────────────────────────────
log "Instalando Apache, PHP, MySQL y dependencias..."

# Apache
apt-get install -y -qq apache2

# PHP 8.1 y extensiones necesarias para WordPress
apt-get install -y -qq \
  libapache2-mod-php8.1 \
  php8.1-mysql \
  php8.1-curl \
  php8.1-gd \
  php8.1-intl \
  php8.1-mbstring \
  php8.1-soap \
  php8.1-xml \
  php8.1-zip \
  php8.1-imagick \
  php8.1-opcache \
  php8.1-redis

# MySQL 8.0
apt-get install -y -qq mysql-server

# Herramientas adicionales
apt-get install -y -qq \
  unzip \
  curl \
  wget \
  htop \
  nfs-common

# ─── Configurar MySQL ───────────────────────────────────────────────────────
log "Configurando MySQL..."

systemctl start mysql
systemctl enable mysql
load_db_password

# Crear base de datos y usuario para WordPress
mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Configuración de seguridad básica de MySQL
mysql -u root <<MYSQL_SECURE
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
MYSQL_SECURE

# Optimización de MySQL para WordPress
cat > /etc/mysql/mysql.conf.d/wordpress.cnf <<'MYSQL_CNF'
[mysqld]
# Performance
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT

# Connections
max_connections = 150
wait_timeout = 600
interactive_timeout = 600

# Logging
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow-query.log
long_query_time = 2

# Character set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
MYSQL_CNF

systemctl restart mysql

# ─── Configurar PHP ──────────────────────────────────────────────────────────
log "Configurando PHP para Apache..."

# Ajustar php.ini para WordPress
cat > /etc/php/8.1/apache2/conf.d/99-wordpress.ini <<'PHP_INI'
; Optimización para WordPress
upload_max_filesize = 64M
post_max_size = 64M
memory_limit = 256M
max_execution_time = 300
max_input_time = 300
max_input_vars = 5000

; OPcache
opcache.enable = 1
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 2
opcache.save_comments = 1
PHP_INI

mkdir -p /var/log/php
chown www-data:www-data /var/log/php

# ─── Instalar WordPress ─────────────────────────────────────────────────────
log "Descargando e instalando WordPress..."

WP_DIR="/var/www/html"
mkdir -p "$WP_DIR"

# Descargar WordPress oficial o sincronizar el contenido migrado desde GCS
install_wordpress_files "$WP_DIR"

# Configurar wp-config.php
cp "$WP_DIR/wp-config-sample.php" "$WP_DIR/wp-config.php"

# Generar salts únicos
SALTS=$(curl -sS https://api.wordpress.org/secret-key/1.1/salt/)

# Reemplazar configuración de base de datos
sed -i "s/database_name_here/$DB_NAME/" "$WP_DIR/wp-config.php"
sed -i "s/username_here/$DB_USER/" "$WP_DIR/wp-config.php"
sed -i "s/password_here/$DB_PASS/" "$WP_DIR/wp-config.php"
sed -i "s/localhost/127.0.0.1/" "$WP_DIR/wp-config.php"
sed -i 's/^\$table_prefix = .*/$table_prefix = '\'''"$WP_TABLE_PREFIX"'\'';/' "$WP_DIR/wp-config.php"

# Reemplazar salts
sed -i "/AUTH_KEY/d" "$WP_DIR/wp-config.php"
sed -i "/SECURE_AUTH_KEY/d" "$WP_DIR/wp-config.php"
sed -i "/LOGGED_IN_KEY/d" "$WP_DIR/wp-config.php"
sed -i "/NONCE_KEY/d" "$WP_DIR/wp-config.php"
sed -i "/AUTH_SALT/d" "$WP_DIR/wp-config.php"
sed -i "/SECURE_AUTH_SALT/d" "$WP_DIR/wp-config.php"
sed -i "/LOGGED_IN_SALT/d" "$WP_DIR/wp-config.php"
sed -i "/NONCE_SALT/d" "$WP_DIR/wp-config.php"

# Insertar salts después de la línea del prefijo de tabla
sed -i "/table_prefix/a\\
$SALTS" "$WP_DIR/wp-config.php" 2>/dev/null || true

# Configuraciones adicionales de WordPress
WP_EXTRA_FILE="/tmp/wp-extra-config.php"
cat > "$WP_EXTRA_FILE" <<'WP_EXTRA'

/* ─── Configuraciones adicionales para GCP ─── */

// Forzar HTTPS (detrás del Load Balancer)
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}

// Deshabilitar edición de archivos desde el admin
define('DISALLOW_FILE_EDIT', true);

// Limitar revisiones de posts
define('WP_POST_REVISIONS', 5);

// Auto-save interval (segundos)
define('AUTOSAVE_INTERVAL', 120);

// Vaciar papelera cada 15 días
define('EMPTY_TRASH_DAYS', 15);

// Deshabilitar CRON de WordPress (usar cron del sistema)
define('DISABLE_WP_CRON', true);

// Memoria
define('WP_MEMORY_LIMIT', '256M');
define('WP_MAX_MEMORY_LIMIT', '512M');

// Debug (desactivar en producción)
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', false);
define('WP_DEBUG_DISPLAY', false);
WP_EXTRA

awk -v extra_file="$WP_EXTRA_FILE" '
  /stop editing/ && inserted == 0 {
    while ((getline line < extra_file) > 0) print line
    close(extra_file)
    inserted = 1
  }
  { print }
  END {
    if (inserted == 0) {
      while ((getline line < extra_file) > 0) print line
      close(extra_file)
    }
  }
' "$WP_DIR/wp-config.php" > "$WP_DIR/wp-config.php.tmp"
mv "$WP_DIR/wp-config.php.tmp" "$WP_DIR/wp-config.php"
rm -f "$WP_EXTRA_FILE"

# Importar dump de base de datos, si se definio una fuente GCS
import_wordpress_database

# Permisos
chown -R www-data:www-data "$WP_DIR"
find "$WP_DIR" -type d -exec chmod 755 {} \;
find "$WP_DIR" -type f -exec chmod 644 {} \;
chmod 640 "$WP_DIR/wp-config.php"

# Reemplazar URL local/origen por el dominio configurado
replace_wordpress_urls "$WP_DIR"

# ─── Configurar Apache ───────────────────────────────────────────────────────
log "Configurando Apache..."

a2dismod mpm_event mpm_worker >/dev/null 2>&1 || true
a2enmod mpm_prefork php8.1 rewrite headers expires remoteip setenvif status >/dev/null

cat > /etc/apache2/conf-available/z-security-hardening.conf <<'APACHE_SECURITY'
ServerTokens Prod
ServerSignature Off
TraceEnable Off
FileETag None

Header always unset X-Powered-By
Header always set X-Content-Type-Options "nosniff"
Header always set X-Frame-Options "SAMEORIGIN"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Permissions-Policy "geolocation=(), microphone=(), camera=()"
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
APACHE_SECURITY

a2disconf security-hardening >/dev/null 2>&1 || true
a2enconf z-security-hardening >/dev/null

echo "OK" > "$WP_DIR/health"
chown www-data:www-data "$WP_DIR/health"
chmod 644 "$WP_DIR/health"

cat > /etc/apache2/sites-available/wordpress.conf <<'APACHE_VHOST'
<VirtualHost *:80>
    ServerName _
    DocumentRoot /var/www/html

    ErrorLog $${APACHE_LOG_DIR}/error.log
    CustomLog $${APACHE_LOG_DIR}/access.log combined

    RemoteIPHeader X-Forwarded-For
    SetEnvIf X-Forwarded-Proto "^https$" HTTPS=on

    <Directory /var/www/html>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php index.html
    </Directory>

    <FilesMatch "^(\.ht|wp-config\.php|readme\.html)$">
        Require all denied
    </FilesMatch>

    <Files "xmlrpc.php">
        Require all denied
    </Files>

    <DirectoryMatch "^/var/www/html/wp-content/uploads/.*">
        <FilesMatch "\.php$">
            Require all denied
        </FilesMatch>
    </DirectoryMatch>

    <Location "/server-status">
        SetHandler server-status
        Require local
    </Location>
</VirtualHost>
APACHE_VHOST

cat > "$WP_DIR/.htaccess" <<'HTACCESS'
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %%{REQUEST_FILENAME} !-f
RewriteCond %%{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
HTACCESS

chown www-data:www-data "$WP_DIR/.htaccess"
chmod 644 "$WP_DIR/.htaccess"

a2dissite 000-default >/dev/null
a2ensite wordpress >/dev/null

apache2ctl configtest

systemctl restart apache2
systemctl enable apache2

# ─── Configurar WP-Cron via sistema ─────────────────────────────────────────
log "Configurando WP-Cron del sistema..."

cat > /etc/cron.d/wordpress <<'WP_CRON'
# Ejecutar WP-Cron cada 5 minutos
*/5 * * * * www-data /usr/bin/php /var/www/html/wp-cron.php > /dev/null 2>&1
WP_CRON

# ─── Configurar Ops Agent (Logging & Monitoring) ────────────────────────────
log "Configurando Google Cloud Ops Agent..."

if ! command -v google-cloud-ops-agent >/dev/null 2>&1; then
  curl -fsS -o /tmp/add-google-cloud-ops-agent-repo.sh \
    https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
  bash /tmp/add-google-cloud-ops-agent-repo.sh --also-install || log "No se pudo instalar Ops Agent; WordPress queda funcionando sin agente."
fi

mkdir -p /etc/google-cloud-ops-agent

cat > /etc/google-cloud-ops-agent/config.yaml <<'OPS_AGENT'
logging:
  receivers:
    apache_access:
      type: apache_access
    apache_error:
      type: apache_error
    mysql_error:
      type: mysql_error
      include_paths:
        - /var/log/mysql/error.log
    mysql_slow:
      type: mysql_slow
      include_paths:
        - /var/log/mysql/slow-query.log
    syslog:
      type: files
      include_paths:
        - /var/log/syslog
  service:
    pipelines:
      default_pipeline:
        receivers:
          - apache_access
          - apache_error
          - mysql_error
          - mysql_slow
          - syslog

metrics:
  receivers:
    apache:
      type: apache
    mysql:
      type: mysql
      endpoint: localhost:3306
      username: root
  service:
    pipelines:
      default_pipeline:
        receivers:
          - apache
          - mysql
OPS_AGENT

systemctl restart google-cloud-ops-agent || true

# ─── Marcar como instalado ──────────────────────────────────────────────────
touch /opt/wordpress-installed

log "=========================================="
log "Instalación completada exitosamente"
log "=========================================="
log "WordPress: /var/www/html"
log "Apache config: /etc/apache2/sites-available/wordpress.conf"
log "MySQL DB: $DB_NAME"
log "Health check: http://localhost/health"
log "=========================================="
