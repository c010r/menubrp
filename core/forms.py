from django import forms
from .models import Category, MenuItem

class CategoryForm(forms.ModelForm):
    class Meta:
        model = Category
        fields = ['name', 'icon', 'order', 'is_active']
        widgets = {
            'name': forms.TextInput(attrs={'class': 'form-control bg-dark text-white border-secondary'}),
            'icon': forms.TextInput(attrs={'class': 'form-control bg-dark text-white border-secondary', 'placeholder': 'fa-pizza-slice'}),
            'order': forms.NumberInput(attrs={'class': 'form-control bg-dark text-white border-secondary'}),
            'is_active': forms.CheckboxInput(attrs={'class': 'form-check-input'}),
        }

class MenuItemForm(forms.ModelForm):
    class Meta:
        model = MenuItem
        fields = ['category', 'name', 'description', 'price', 'image', 'is_active', 'is_featured']
        widgets = {
            'category': forms.Select(attrs={'class': 'form-select bg-dark text-white border-secondary'}),
            'name': forms.TextInput(attrs={'class': 'form-control bg-dark text-white border-secondary'}),
            'description': forms.Textarea(attrs={'class': 'form-control bg-dark text-white border-secondary', 'rows': 3}),
            'price': forms.NumberInput(attrs={'class': 'form-control bg-dark text-white border-secondary'}),
            'image': forms.FileInput(attrs={'class': 'form-control bg-dark text-white border-secondary'}),
            'is_active': forms.CheckboxInput(attrs={'class': 'form-check-input'}),
            'is_featured': forms.CheckboxInput(attrs={'class': 'form-check-input'}),
        }
