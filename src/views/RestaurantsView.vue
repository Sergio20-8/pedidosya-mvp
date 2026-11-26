<script setup>
import { computed, onMounted, ref } from 'vue'
import { ArrowLeft, ChevronDown, Heart, List, Search, ShoppingCart, SlidersHorizontal, Star, X } from 'lucide-vue-next'
import { useRouter } from 'vue-router'
import { listRestaurants } from '../services/restaurantService'
import { useCartStore } from '../stores/cart'

const router = useRouter()
const cart = useCartStore()
const restaurants = ref([])
const loading = ref(true)
const error = ref('')
const query = ref('')
const sort = ref('name')
const minRating = ref(0)

const filteredRestaurants = computed(() => {
  const normalized = query.value.trim().toLowerCase()
  const result = restaurants.value.filter((restaurant) => restaurant.nombre.toLowerCase().includes(normalized) && Number(restaurant.calificacion || 0) >= minRating.value)
  return [...result].sort((a, b) => sort.value === 'products' ? b.productCount - a.productCount : a.nombre.localeCompare(b.nombre))
})

function clearSearch() { query.value = '' }
function toggleRating() { minRating.value = minRating.value ? 0 : 4.5 }

async function load() {
  loading.value = true
  error.value = ''
  try { restaurants.value = await listRestaurants() } catch (loadError) { error.value = loadError.message || 'No se pudieron cargar los restaurantes.' }
  finally { loading.value = false }
}

onMounted(load)
</script>

<template>
  <main class="catalog-page">
    <header class="catalog-header">
      <div class="catalog-topbar">
        <button class="icon-button" aria-label="Regresar" @click="router.push('/')"><ArrowLeft :size="26" /></button>
        <label class="catalog-search"><Search :size="20" /><input v-model="query" placeholder="Buscar locales y platos" aria-label="Buscar restaurantes" /><button v-if="query" class="search-clear" @click="clearSearch"><X :size="16" /></button></label>
        <button class="icon-button cart-link" aria-label="Carrito" @click="router.push('/carrito')"><ShoppingCart :size="25" /><b v-if="cart.count" class="cart-badge">{{ cart.count }}</b></button>
      </div>
      <div class="filter-scroller">
        <button class="filter-button"><SlidersHorizontal :size="18" /> Filtrar</button>
        <button class="filter-button" @click="sort = sort === 'name' ? 'products' : 'name'">Ordenar <ChevronDown :size="18" /></button>
        <button class="filter-button filter-button--disabled" disabled>Descuentos</button>
        <button class="filter-button" :class="{ 'filter-button--selected': minRating }" @click="toggleRating"><Star :size="18" :fill="minRating ? 'currentColor' : 'none'" /> 4.5 o más</button>
      </div>
    </header>

    <section class="catalog-content">
      <div class="catalog-heading"><h1>{{ filteredRestaurants.length }} {{ filteredRestaurants.length === 1 ? 'restaurante' : 'restaurantes' }}</h1><div class="view-toggle"><List :size="19" /><span></span></div></div>
      <div v-if="loading" class="restaurant-list restaurant-list--skeleton" aria-label="Cargando restaurantes" aria-busy="true">
        <article v-for="item in 3" :key="item" class="restaurant-card restaurant-card--skeleton">
          <div class="restaurant-card__image skeleton-block"></div>
          <div class="restaurant-card__body"><div class="restaurant-card__logo skeleton-block"></div><div class="restaurant-card__info"><div class="skeleton-line skeleton-line--title"></div><div class="skeleton-line skeleton-line--type"></div><div class="skeleton-line skeleton-line--meta"></div></div><div class="restaurant-card__actions"><div class="skeleton-circle"></div></div></div>
        </article>
      </div>
      <p v-else-if="error" class="catalog-state catalog-state--error">{{ error }}</p>
      <p v-else-if="!filteredRestaurants.length" class="catalog-state">No encontramos restaurantes con ese nombre.</p>
      <div v-else class="restaurant-list">
        <article v-for="restaurant in filteredRestaurants" :key="restaurant.id" class="restaurant-card" @click="router.push({ name: 'restaurant-detail', params: { id: restaurant.id } })">
          <img class="restaurant-card__image" :src="restaurant.banner_url || restaurant.image" :alt="restaurant.nombre" />
          <div class="restaurant-card__body"><div class="restaurant-card__logo"><img :src="restaurant.image" :alt="`Logotipo de ${restaurant.nombre}`" /></div><div class="restaurant-card__info"><h2>{{ restaurant.nombre }}</h2><p v-if="restaurant.tipo_comida || restaurant.categories.length" class="restaurant-cuisine">{{ restaurant.tipo_comida || restaurant.categories.join(' · ') }}</p><p v-if="restaurant.tiempo_preparacion_min" class="restaurant-meta">{{ restaurant.tiempo_preparacion_min }} min</p></div><div class="restaurant-card__actions"><span class="restaurant-rating"><Star :size="15" fill="currentColor" /> {{ Number(restaurant.calificacion || 0).toFixed(1) }} ({{ restaurant.cantidad_resenas || 0 }})</span><Heart :size="18" /></div></div>
        </article>
      </div>
    </section>
  </main>
</template>
