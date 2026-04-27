#!/bin/bash
# =============================================================
# deploy.sh - Script de despliegue producción
# Backyard Bar Menu - Django + PostgreSQL + Nginx + Gunicorn
# Ubuntu 22.04 / Hostinger VPS
# =============================================================

set -e  # Detener si hay error

# ─────────────────────────────────────────────
# CONFIGURACIÓN - EDITAR ANTES DE EJECUTAR
# ─────────────────────────────────────────────
APP_NAME="menubrp"
DOMAIN="menu.backyardbar.fun"
REPO_URL="https://github.com/c010r/menubrp.git"
APP_DIR="/var/www/$APP_NAME"
PYTHON_VERSION="python3.11"

DB_NAME="menubrp_db"
DB_USER="menubrp_user"
DB_PASS="$(openssl rand -hex 16)"   # Se genera automáticamente
DJANGO_SECRET="$(openssl rand -hex 32)"

ADMIN_USER="admin"
ADMIN_EMAIL="admin@backyardbar.fun"
ADMIN_PASS="$(openssl rand -hex 12)"

# ─────────────────────────────────────────────
# COLORES
# ─────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${GREEN}══════════════════════════════════════${NC}"; echo -e "${GREEN}  $1${NC}"; echo -e "${GREEN}══════════════════════════════════════${NC}"; }

# ─────────────────────────────────────────────
# VERIFICAR ROOT
# ─────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root: sudo bash deploy.sh"
fi

section "1/9 - Actualizando sistema"
apt-get update -y && apt-get upgrade -y
apt-get install -y \
    python3.11 python3.11-venv python3.11-dev python3-pip \
    postgresql postgresql-contrib libpq-dev \
    nginx certbot python3-certbot-nginx \
    git curl build-essential \
    libssl-dev libffi-dev \
    libjpeg-dev zlib1g-dev   # Para Pillow (imágenes)
info "Sistema actualizado ✓"

section "2/9 - Configurando PostgreSQL"
systemctl start postgresql
systemctl enable postgresql

sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || warn "La base de datos ya existe, continuando..."
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" 2>/dev/null || warn "El usuario ya existe, actualizando contraseña..."
sudo -u postgres psql -c "ALTER USER $DB_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';"
sudo -u postgres psql -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';"
sudo -u postgres psql -c "ALTER ROLE $DB_USER SET timezone TO 'America/Argentina/Buenos_Aires';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
info "PostgreSQL configurado ✓"

section "3/9 - Clonando repositorio"
if [ -d "$APP_DIR" ]; then
    warn "Directorio ya existe. Actualizando código..."
    cd "$APP_DIR" && git pull origin main
else
    git clone "$REPO_URL" "$APP_DIR"
fi
cd "$APP_DIR"
info "Repositorio clonado ✓"

section "4/9 - Configurando entorno virtual"
$PYTHON_VERSION -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install \
    django gunicorn psycopg2-binary \
    pillow whitenoise \
    django-storages python-decouple
info "Entorno virtual configurado ✓"

section "5/9 - Creando archivo de entorno (.env)"
cat > "$APP_DIR/.env" << EOF
SECRET_KEY=$DJANGO_SECRET
DEBUG=False
ALLOWED_HOSTS=$DOMAIN,www.$DOMAIN,localhost,127.0.0.1
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASS
DB_HOST=localhost
DB_PORT=5432
MEDIA_URL=/media/
STATIC_ROOT=/var/www/$APP_NAME/staticfiles
EOF
chmod 600 "$APP_DIR/.env"
info "Archivo .env creado ✓"

section "6/9 - Configurando Django para producción"

# Crear settings de producción
cat > "$APP_DIR/config/settings_prod.py" << 'SETTINGS'
from .settings import *
from decouple import config

SECRET_KEY = config('SECRET_KEY')
DEBUG = False
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost').split(',')

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME'),
        'USER': config('DB_USER'),
        'PASSWORD': config('DB_PASSWORD'),
        'HOST': config('DB_HOST', default='localhost'),
        'PORT': config('DB_PORT', default='5432'),
    }
}

STATIC_URL = '/static/'
STATIC_ROOT = config('STATIC_ROOT', default='/var/www/menubrp/staticfiles')
STATICFILES_DIRS = []

MIDDLEWARE.insert(1, 'whitenoise.middleware.WhiteNoiseMiddleware')
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

MEDIA_URL = '/media/'
MEDIA_ROOT = '/var/www/menubrp/media'

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'file': {
            'level': 'ERROR',
            'class': 'logging.FileHandler',
            'filename': '/var/log/menubrp/django_error.log',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file'],
            'level': 'ERROR',
            'propagate': True,
        },
    },
}
SETTINGS

mkdir -p /var/log/$APP_NAME

export DJANGO_SETTINGS_MODULE=config.settings_prod
export $(cat "$APP_DIR/.env" | grep -v "^#" | xargs)

source venv/bin/activate
python manage.py migrate --settings=config.settings_prod
python manage.py collectstatic --noinput --settings=config.settings_prod

# Crear superusuario
DJANGO_SUPERUSER_PASSWORD=$ADMIN_PASS \
python manage.py createsuperuser \
    --username=$ADMIN_USER \
    --email=$ADMIN_EMAIL \
    --noinput \
    --settings=config.settings_prod 2>/dev/null || warn "Superusuario ya existe"

chown -R www-data:www-data "$APP_DIR"
chmod -R 755 "$APP_DIR"
chmod -R 755 "$APP_DIR/media"
info "Django configurado ✓"

section "7/9 - Configurando Gunicorn (systemd service)"
cat > /etc/systemd/system/$APP_NAME.service << EOF
[Unit]
Description=Gunicorn para $APP_NAME
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
Environment="DJANGO_SETTINGS_MODULE=config.settings_prod"
ExecStart=$APP_DIR/venv/bin/gunicorn \\
    --workers 3 \\
    --bind unix:/run/$APP_NAME.sock \\
    --access-logfile /var/log/$APP_NAME/gunicorn_access.log \\
    --error-logfile /var/log/$APP_NAME/gunicorn_error.log \\
    --capture-output \\
    config.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=on-failure
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $APP_NAME
systemctl start $APP_NAME
info "Gunicorn configurado ✓"

section "8/9 - Configurando Nginx"
cat > /etc/nginx/sites-available/$APP_NAME << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    client_max_body_size 10M;

    access_log /var/log/nginx/${APP_NAME}_access.log;
    error_log  /var/log/nginx/${APP_NAME}_error.log;

    location = /favicon.ico { access_log off; log_not_found off; }

    location /static/ {
        alias $APP_DIR/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    location /media/ {
        alias $APP_DIR/media/;
        expires 7d;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/$APP_NAME.sock;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
    }
}
EOF

ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx
info "Nginx configurado ✓"

section "9/9 - Instalando SSL con Let's Encrypt"
warn "Asegurate de que el DNS de $DOMAIN apunte a este servidor antes de continuar."
read -p "¿El DNS ya está configurado? (s/N): " dns_ready

if [[ "$dns_ready" =~ ^[sS]$ ]]; then
    certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" \
        --non-interactive --agree-tos -m "$ADMIN_EMAIL" \
        --redirect
    info "SSL instalado ✓"
else
    warn "SSL omitido. Ejecutar manualmente: certbot --nginx -d $DOMAIN"
fi

# ─────────────────────────────────────────────
# RESUMEN FINAL
# ─────────────────────────────────────────────
section "✅ DESPLIEGUE COMPLETADO"

echo ""
echo "┌─────────────────────────────────────────────────────┐"
echo "│              CREDENCIALES Y DATOS                   │"
echo "├─────────────────────────────────────────────────────┤"
printf "│  Sitio:          http://%-30s│\n" "$DOMAIN"
printf "│  Backend:        http://%s/backend/login/ \n" "$DOMAIN"
printf "│  Admin user:     %-35s│\n" "$ADMIN_USER"
printf "│  Admin pass:     %-35s│\n" "$ADMIN_PASS"
echo "│  ─────────────────────────────────────────────────  │"
printf "│  DB Name:        %-35s│\n" "$DB_NAME"
printf "│  DB User:        %-35s│\n" "$DB_USER"
printf "│  DB Pass:        %-35s│\n" "$DB_PASS"
echo "└─────────────────────────────────────────────────────┘"
echo ""
echo "  ⚠️  GUARDÁ ESTAS CREDENCIALES EN UN LUGAR SEGURO"
echo ""
echo "  Logs de Gunicorn: /var/log/$APP_NAME/gunicorn_error.log"
echo "  Logs de Nginx:    /var/log/nginx/${APP_NAME}_error.log"
echo ""
echo "  Comandos útiles:"
echo "    systemctl status $APP_NAME       # Estado del servicio"
echo "    systemctl restart $APP_NAME      # Reiniciar Gunicorn"
echo "    journalctl -u $APP_NAME -f       # Logs en tiempo real"
echo ""
