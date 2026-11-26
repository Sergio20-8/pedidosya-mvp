<script setup>
import { computed, nextTick, onMounted, ref } from 'vue'
import { ArrowLeft, Check, Plus, Search, ShoppingCart, Star, X } from 'lucide-vue-next'
import { useRoute, useRouter } from 'vue-router'
import { images } from '../constants/images'
import { getRestaurantDetail } from '../services/restaurantService'
import { useCartStore } from '../stores/cart'

const route = useRoute(); const router = useRouter()
const cart = useCartStore()
const restaurant = ref(null); const loading = ref(true); const error = ref(''); const query = ref(''); const activeCategory = ref(''); const notice = ref('')
const categorySections = computed(() => {
  const grouped = new Map()
  for (const product of restaurant.value?.products || []) {
    const category = product.categorias?.nombre || 'Menú'
    if (!grouped.has(category)) grouped.set(category, [])
    grouped.get(category).push(product)
  }
  return [...grouped.entries()].map(([name, products]) => ({ name, products }))
})
const filteredSections = computed(() => categorySections.value.map((section) => ({ ...section, products: section.products.filter((product) => `${product.nombre} ${product.descripcion || ''}`.toLowerCase().includes(query.value.trim().toLowerCase())) })).filter((section) => section.products.length))

async function load() {
  loading.value = true; error.value = ''
  try { restaurant.value = await getRestaurantDetail(route.params.id); activeCategory.value = categorySections.value[0]?.name || '' }
  catch (loadError) { error.value = loadError.message || 'No se pudo cargar el restaurante.' }
  finally { loading.value = false }
}
function showCartNotice(product) { cart.addItem(product, restaurant.value); notice.value = `${cart.count} ${cart.count === 1 ? 'producto' : 'productos'} en tu carrito.`; window.setTimeout(() => { notice.value = '' }, 3200) }
function handleImageError(event) { event.target.src = images.productoDefault }
async function selectCategory(name) { activeCategory.value = name; await nextTick(); document.getElementById(`category-${slug(name)}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' }) }
function slug(value) { return value.toLowerCase().replace(/[^a-z0-9]+/g, '-') }
onMounted(load)
</script>

<template>
  <main class="detail-page">
    <header class="detail-header"><button class="icon-button" aria-label="Regresar" @click="router.push('/restaurantes')"><ArrowLeft :size="26" /></button><h1>{{ restaurant?.nombre || 'Restaurante' }}</h1><div class="detail-header__actions"><button class="icon-button" aria-label="Buscar productos"><Search :size="23" /></button><button class="icon-button cart-link" aria-label="Carrito" @click="router.push('/carrito')"><ShoppingCart :size="23" /><b v-if="cart.count" class="cart-badge">{{ cart.count }}</b></button></div></header>
    <template v-if="!loading && restaurant">
      <section class="restaurant-detail-hero"><img :src="restaurant.banner_url || restaurant.image" :alt="restaurant.nombre" /><div class="restaurant-detail-info"><div class="restaurant-detail-logo"><img :src="restaurant.image" :alt="restaurant.nombre" /></div><div><h2>{{ restaurant.nombre }}</h2><p><Star :size="17" fill="currentColor" /> {{ Number(restaurant.calificacion || 0).toFixed(1) }} ({{ restaurant.cantidad_resenas || 0 }})</p><span>{{ restaurant.tiempo_preparacion_min || '—' }} min de entrega</span></div></div></section>
      <div class="detail-filters"><button>Descuentos</button><button>Más vendidos</button><button>Precio más bajo primero</button></div>
      <nav class="menu-categories" aria-label="Categorías del menú"><button v-for="section in categorySections" :key="section.name" :class="{ active: activeCategory === section.name }" @click="selectCategory(section.name)">{{ section.name }}</button></nav>
      <label class="detail-search"><Search :size="19" /><input v-model="query" placeholder="Buscar en este menú" /><X v-if="query" :size="17" @click="query = ''" /></label>
      <section class="detail-content"><h2 class="restaurant-description">{{ restaurant.descripcion || 'Descubre el menú de este restaurante.' }}</h2><div v-for="section in filteredSections" :id="`category-${slug(section.name)}`" :key="section.name" class="menu-section"><h2>{{ section.name }}</h2><article v-for="product in section.products" :key="product.id" class="product-row" @click="router.push({ name: 'product-detail', params: { restaurantId: restaurant.id, productId: product.id } })"><div class="product-info"><h3>{{ product.nombre }}</h3><p>{{ product.descripcion || 'Una opción deliciosa para disfrutar.' }}</p><strong>${{ Number(product.precio).toFixed(2) }}</strong></div><div class="product-image-wrap"><img :src="product.imagen_url || images.productoDefault" :alt="product.nombre" @error="handleImageError" /><button class="add-product" aria-label="Agregar producto" @click.stop="showCartNotice(product)"><Plus :size="22" /></button></div></article></div></section>
    </template>
    <p v-else-if="loading" class="catalog-state">Cargando menú…</p><p v-else class="catalog-state catalog-state--error">{{ error || 'Restaurante no encontrado.' }}</p>
    <div v-if="cart.count" class="restaurant-cart-bar"><div><span>{{ cart.count }} {{ cart.count === 1 ? 'producto' : 'productos' }}</span><strong>${{ cart.subtotal.toFixed(2) }}</strong></div><button @click="router.push('/carrito')">Ver carrito</button></div>
    <Transition name="notice"><div v-if="notice" class="cart-notice"><span><Check :size="17" /> {{ notice }}</span><button @click="router.push('/carrito')">Ver carrito</button></div></Transition>
  </main>
</template>
