from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib.auth import login, authenticate, logout
from django.contrib.auth.forms import AuthenticationForm
from .models import Category, MenuItem
from .forms import CategoryForm, MenuItemForm

def menu_view(request):
    categories = Category.objects.filter(is_active=True).prefetch_related('items')
    return render(request, 'core/menu.html', {'categories': categories})

def login_view(request):
    if request.method == 'POST':
        form = AuthenticationForm(request, data=request.POST)
        if form.is_valid():
            user = form.get_user()
            login(request, user)
            return redirect('backend_dashboard')
    else:
        form = AuthenticationForm()
    return render(request, 'core/backend/login.html', {'form': form})

@login_required(login_url='login')
def backend_dashboard(request):
    categories = Category.objects.all()
    items = MenuItem.objects.all()
    return render(request, 'core/backend/dashboard.html', {
        'categories': categories,
        'items': items
    })

@login_required(login_url='login')
def category_upsert(request, pk=None):
    category = get_object_or_404(Category, pk=pk) if pk else None
    if request.method == 'POST':
        form = CategoryForm(request.POST, instance=category)
        if form.is_valid():
            form.save()
            return redirect('backend_dashboard')
    else:
        form = CategoryForm(instance=category)
    return render(request, 'core/backend/form.html', {'form': form, 'title': 'Categoría'})

@login_required(login_url='login')
def item_upsert(request, pk=None):
    item = get_object_or_404(MenuItem, pk=pk) if pk else None
    if request.method == 'POST':
        form = MenuItemForm(request.POST, request.FILES, instance=item)
        if form.is_valid():
            form.save()
            return redirect('backend_dashboard')
    else:
        form = MenuItemForm(instance=item)
    return render(request, 'core/backend/form.html', {'form': form, 'title': 'Ítem de Menú'})

@login_required(login_url='login')
def delete_item(request, model_type, pk):
    model = Category if model_type == 'category' else MenuItem
    obj = get_object_or_404(model, pk=pk)
    obj.delete()
    return redirect('backend_dashboard')

def logout_view(request):
    logout(request)
    return redirect('menu')
