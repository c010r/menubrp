import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from core.models import Category, MenuItem

def populate():
    # Categories
    burgers = Category.objects.create(name="Hamburguesas", slug="hamburguesas", order=1, icon="fa-hamburger")
    drinks = Category.objects.create(name="Bebidas", slug="bebidas", order=2, icon="fa-glass-cheers")
    pizzas = Category.objects.create(name="Pizzas", slug="pizzas", order=3, icon="fa-pizza-slice")

    # Menu Items
    MenuItem.objects.create(
        category=burgers,
        name="Clásica Backyard",
        description="Medallón de 180g, queso cheddar, lechuga, tomate y salsa secreta.",
        price=1200.00,
        is_featured=True
    )
    MenuItem.objects.create(
        category=burgers,
        name="Doble Bacon",
        description="Doble carne, doble cheddar, mucho bacon y cebolla caramelizada.",
        price=1500.00
    )

    MenuItem.objects.create(
        category=pizzas,
        name="Muzzarella",
        description="Salsa de tomate casera, mucha muzzarella y aceitunas verdes.",
        price=2200.00
    )
    MenuItem.objects.create(
        category=pizzas,
        name="Pepperoni",
        description="Muzzarella y rodajas de pepperoni crocante.",
        price=2500.00,
        is_featured=True
    )

    MenuItem.objects.create(
        category=drinks,
        name="Cerveza Artesanal IPA",
        description="Pinta de IPA de la casa, notas cítricas y amargor equilibrado.",
        price=800.00
    )
    MenuItem.objects.create(
        category=drinks,
        name="Limonada con Menta",
        description="Fresca limonada natural con menta y jengibre.",
        price=600.00
    )

    print("Sample data populated successfully!")

if __name__ == '__main__':
    populate()
