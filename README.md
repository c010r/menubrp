# Backyard Bar - Menú Digital

Sistema de menú digital con panel de administración personalizado, construido con **Django** y **Bootstrap 5**.

## Características

- 🍔 Menú público con diseño premium (dark mode + glassmorphism)
- 🔒 Backend propio sin Django Admin (`/backend/`)
- 📁 Categorías e ítems con imágenes
- ⭐ Marcado de ítems recomendados
- 📱 Responsive completo con Bootstrap 5

## Instalación

```bash
# Clonar repositorio
git clone https://github.com/c010r/menubrp.git
cd menubrp

# Instalar dependencias
pip install django pillow

# Migraciones
python manage.py migrate

# Crear superusuario
python manage.py createsuperuser

# Datos de ejemplo (opcional)
python seed.py

# Iniciar servidor
python manage.py runserver
```

## URLs

| URL | Descripción |
|-----|-------------|
| `/` | Menú público |
| `/backend/` | Panel de administración |
| `/backend/login/` | Login del backend |

## Modelos

- **Category**: Nombre, slug, icono (FontAwesome), orden, estado activo
- **MenuItem**: Nombre, descripción, precio, imagen, categoría, destacado

## Stack

- Python / Django 6
- Bootstrap 5
- SQLite (desarrollo)
- FontAwesome 6
- Google Fonts (Outfit)
