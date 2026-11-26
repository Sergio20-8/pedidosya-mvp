<script setup>
import { computed, onMounted, ref } from 'vue'
import { ArrowLeft, Heart, Minus, Plus, Star } from 'lucide-vue-next'
import { useRoute, useRouter } from 'vue-router'
import { images } from '../constants/images'
import { getRestaurantDetail } from '../services/restaurantService'
import { useCartStore } from '../stores/cart'

const route = useRoute()
const router = useRouter()
const cart = useCartStore()
const restaurant = ref(null)
const product = ref(null)
const loading = ref(true)
const error = ref('')
const quantity = ref(1)
const notice = ref('')

const total = computed(() => Number(product.value?.precio || 0) * quantity.value)
const isRestaurant = computed(() => restaurant.value?.tipo_establecimiento === 'RESTAURANTE')

async function load() {
  try {
    const data = await getRestaurantDetail(route.params.restaurantId)
    restaurant.value = data
    product.value = data?.products.find((item) => item.id === route.params.productId) || null
    if (!product.value) error.value = 'Producto no encontrado.'
  } catch (loadError) {
    error.value = loadError.message || 'No se pudo cargar el producto.'
  } finally {
    loading.value = false
  }
}

function changeQuantity(amount) {
  quantity.value = Math.max(1, quantity.value + amount)
}

function addProduct() {
  cart.addItem(product.value, restaurant.value, quantity.value)
  notice.value = `${cart.count} ${cart.count === 1 ? 'producto' : 'productos'} en tu carrito.`
  window.setTimeout(() => { notice.value = '' }, 2600)
}

function handleImageError(event) { event.target.src = images.productoDefault }

onMounted(load)
</script>

<template>
  <main class="product-detail-page">
    <template v-if="!loading && product">
      <section class="product-detail-hero">
        <img :src="product.imagen_url || images.productoDefault" :alt="product.nombre" @error="handleImageError" />
        <button class="product-detail-icon product-detail-icon--back" aria-label="Regresar" @click="router.back()"><ArrowLeft :size="22" /></button>
        <button class="product-detail-icon product-detail-icon--favorite" aria-label="Agregar a favoritos"><Heart :size="21" /></button>
        <div class="product-detail-rating"><Star :size="14" fill="currentColor" /> {{ Number(restaurant?.calificacion || 0).toFixed(1) }} <small>({{ restaurant?.cantidad_resenas || 0 }})</small><span>Buen sabor</span></div>
      </section>
      <section class="product-detail-content">
        <h1>{{ product.nombre }}</h1>
        <p class="product-detail-description">{{ product.descripcion || 'Una opción deliciosa para disfrutar.' }}</p>
        <strong class="product-detail-price">${{ Number(product.precio).toFixed(2) }}</strong>
        <div class="product-detail-store"><img :src="restaurant?.image || restaurant?.imagen_url || images.productoDefault" :alt="`Logotipo de ${restaurant?.nombre}`" /><span>Vendido por <b>{{ restaurant?.nombre }}</b></span></div>
        <template v-if="isRestaurant"><div class="product-detail-offer"><strong>Paga ${{ Number(product.precio).toFixed(2) }}</strong><span>con <b>plus</b></span><small>Suscribirme</small></div><div class="product-option"><div><h2>Elige una opción</h2><p>Selecciona los complementos disponibles</p></div><span>Opcional</span></div><div class="product-option-row"><span>Sin complemento</span><span>$0.00 <i></i></span></div><h2 class="product-opinions">Opiniones del plato <small>Mostrar todas</small></h2></template>
      </section>
      <footer class="product-detail-footer"><div><span>Tu producto</span><strong>${{ total.toFixed(2) }}</strong></div><div class="product-detail-actions"><div class="quantity-control"><button aria-label="Reducir cantidad" @click="changeQuantity(-1)"><Minus :size="16" /></button><span>{{ quantity }}</span><button aria-label="Aumentar cantidad" @click="changeQuantity(1)"><Plus :size="16" /></button></div><button class="product-add-button" @click="addProduct">Agregar</button></div></footer>
    </template>
    <p v-else-if="loading" class="catalog-state">Cargando producto…</p>
    <p v-else class="catalog-state catalog-state--error">{{ error }}</p>
    <Transition name="notice"><div v-if="notice" class="cart-notice"><span>✓ {{ notice }}</span><button @click="router.push('/carrito')">Ver carrito</button></div></Transition>
  </main>
</template>
