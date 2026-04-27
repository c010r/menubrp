from django.urls import path
from django.conf import settings
from django.conf.urls.static import static
from core import views

urlpatterns = [
    # Public
    path('', views.menu_view, name='menu'),
    
    # Backend
    path('backend/', views.backend_dashboard, name='backend_dashboard'),
    path('backend/login/', views.login_view, name='login'),
    path('backend/logout/', views.logout_view, name='logout'),
    
    # CRUD Categorías
    path('backend/category/new/', views.category_upsert, name='category_create'),
    path('backend/category/edit/<int:pk>/', views.category_upsert, name='category_edit'),
    
    # CRUD Ítems
    path('backend/item/new/', views.item_upsert, name='item_create'),
    path('backend/item/edit/<int:pk>/', views.item_upsert, name='item_edit'),
    
    # Delete
    path('backend/delete/<str:model_type>/<int:pk>/', views.delete_item, name='delete_item'),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
