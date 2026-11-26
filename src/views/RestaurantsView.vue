<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { ArrowLeft, ChevronDown, Heart, List, Search, ShoppingCart, SlidersHorizontal, Star, X } from 'lucide-vue-next'
import { useRoute, useRouter } from 'vue-router'
import { listRestaurants } from '../services/restaurantService'
import { useCartStore } from '../stores/cart'

const router = useRouter()
const route = useRoute()
const cart = useCartStore()
const restaurants = ref([])
const loading = ref(true)
const error = ref('')
const query = ref(String(route.query.buscar || ''))
const sort = ref('name')
const minRating = ref(0)
const establishmentType = computed(() => String(route.query.tipo || (route.path === '/buscar' ? 'TODOS' : route.path === '/supermercados' ? 'SUPERMERCADO' : route.path === '/farmacias' ? 'FARMACIA' : 'RESTAURANTE')).toUpperCase())
const sectionLabel = computed(() => establishmentType.value === 'SUPERMERCADO' ? 'supermercado' : establishmentType.value === 'FARMACIA' ? 'farmacia' : establishmentType.value === 'TODOS' ? 'resultado' : 'restaurante')
function normalizeSearch(value) { return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim() }
function editDistance(a, b) { const row = Array.from({ length: b.length + 1 }, (_, index) => index); for (let i = 1; i <= a.length; i += 1) { let previous = row[0]; row[0] = i; for (let j = 1; j <= b.length; j += 1) { const current = row[j]; row[j] = Math.min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] === b[j - 1] ? 0 : 1)); previous = current } } return row[b.length] }
function matchesSearch(value, queryValue) { const text = normalizeSearch(value); const term = normalizeSearch(queryValue); if (!term || text.includes(term)) return true; return term.split(/\s+/).every((part) => text.split(/\s+/).some((word) => editDistance(part, word) <= (part.length <= 4 ? 1 : Math.max(1, Math.floor(part.length * 0.3))))) }

const filteredRestaurants = computed(() => {
  const result = restaurants.value.filter((restaurant) => (matchesSearch(restaurant.nombre, query.value) || restaurant.productNames?.some((name) => matchesSearch(name, query.value))) && Number(restaurant.calificacion || 0) >= minRating.value)
  return [...result].sort((a, b) => sort.value === 'products' ? b.productCount - a.productCount : a.nombre.localeCompare(b.nombre))
})

function clearSearch() { query.value = '' }
function toggleRating() { minRating.value = minRating.value ? 0 : 4.5 }

async function load() {
  loading.value = true
  error.value = ''
  try { restaurants.value = await listRestaurants(establishmentType.value) } catch (loadError) { error.value = loadError.message || `No se pudieron cargar los ${sectionLabel.value}s.` }
  finally { loading.value = false }
}

onMounted(load)
watch(() => route.query.buscar, (value) => { query.value = String(value || '') })
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
      <div class="catalog-heading"><h1>{{ filteredRestaurants.length }} {{ filteredRestaurants.length === 1 ? sectionLabel : `${sectionLabel}s` }}</h1><div class="view-toggle"><List :size="19" /><span></span></div></div>
      <div v-if="loading" class="restaurant-list restaurant-list--skeleton" aria-label="Cargando restaurantes" aria-busy="true">
        <article v-for="item in 3" :key="item" class="restaurant-card restaurant-card--skeleton">
          <div class="restaurant-card__image skeleton-block"></div>
          <div class="restaurant-card__body"><div class="restaurant-card__logo skeleton-block"></div><div class="restaurant-card__info"><div class="skeleton-line skeleton-line--title"></div><div class="skeleton-line skeleton-line--type"></div><div class="skeleton-line skeleton-line--meta"></div></div><div class="restaurant-card__actions"><div class="skeleton-circle"></div></div></div>
        </article>
      </div>
      <p v-else-if="error" class="catalog-state catalog-state--error">{{ error }}</p>
      <p v-else-if="!filteredRestaurants.length" class="catalog-state">No encontramos {{ sectionLabel }}s con ese nombre.</p>
      <div v-else class="restaurant-list">
        <article v-for="restaurant in filteredRestaurants" :key="restaurant.id" class="restaurant-card" @click="router.push({ name: 'restaurant-detail', params: { id: restaurant.id }, query: { tipo: establishmentType } })">
          <img class="restaurant-card__image" :src="restaurant.banner_url || restaurant.image" :alt="restaurant.nombre" />
          <div class="restaurant-card__body"><div class="restaurant-card__logo"><img :src="restaurant.image" :alt="`Logotipo de ${restaurant.nombre}`" /></div><div class="restaurant-card__info"><h2>{{ restaurant.nombre }}</h2><p v-if="restaurant.tipo_comida || restaurant.categories.length" class="restaurant-cuisine">{{ restaurant.tipo_comida || restaurant.categories.join(' · ') }}</p><p v-if="restaurant.tiempo_preparacion_min" class="restaurant-meta">{{ restaurant.tiempo_preparacion_min }} min</p></div><div class="restaurant-card__actions"><span class="restaurant-rating"><Star :size="15" fill="currentColor" /> {{ Number(restaurant.calificacion || 0).toFixed(1) }} ({{ restaurant.cantidad_resenas || 0 }})</span><Heart :size="18" /></div></div>
        </article>
      </div>
    </section>
  </main>
</template>
