<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { ArrowLeft, Clock3, Plus, Trash2 } from 'lucide-vue-next'
import { useRouter } from 'vue-router'
import { images } from '../constants/images'
import { getRestaurantDetail } from '../services/restaurantService'
import { loadCheckoutData } from '../services/orderService'
import { calculateDeliveryEstimate, formatDeliveryEstimate } from '../services/deliveryEstimateService'
import { getCheckoutCapacity } from '../services/logisticsService'
import LogisticsCapacityNotice from '../components/LogisticsCapacityNotice.vue'
import { useSessionStore } from '../stores/session'
import { useCartStore } from '../stores/cart'

const router = useRouter()
const cart = useCartStore()
const session = useSessionStore()
const suggestions = ref([])
const notice = ref('')
const deliveryEstimate = ref(null)
const deliveryStatus = ref('loading')
const capacity = ref(null)
let capacityRequest = 0
let capacityTimer
let estimateRequest = 0
const cartItemsIds = computed(() => new Set(cart.items.map((item) => item.id)))

async function loadSuggestions() {
  if (!cart.restaurant?.id) return
  try {
    const data = await getRestaurantDetail(cart.restaurant.id)
    if (data?.image && !cart.restaurant.image) cart.restaurant.image = data.image
    suggestions.value = data?.products.filter((product) => !cartItemsIds.value.has(product.id)).slice(0, 5) || []
  } catch { suggestions.value = [] }
}

async function refreshDeliveryEstimate() {
  const request = ++estimateRequest
  deliveryEstimate.value = null
  deliveryStatus.value = 'loading'
  if (!cart.restaurant?.id || !session.user) { deliveryStatus.value = 'no-address'; return }
  try {
    const [{ addresses }, restaurantData] = await Promise.all([loadCheckoutData(session.user.id), getRestaurantDetail(cart.restaurant.id)])
    const address = addresses.find((item) => item.predeterminada && item.latitud != null && item.longitud != null) || addresses.find((item) => item.latitud != null && item.longitud != null)
    if (!address) { deliveryStatus.value = 'no-address'; return }
    const estimate = await calculateDeliveryEstimate({ restaurant: restaurantData, address })
    if (request !== estimateRequest) return
    deliveryEstimate.value = estimate
    deliveryStatus.value = 'ready'
  } catch {
    if (request === estimateRequest) deliveryStatus.value = 'unavailable'
  }
}

const deliveryLabel = computed(() => deliveryStatus.value === 'ready' ? formatDeliveryEstimate(deliveryEstimate.value) : deliveryStatus.value === 'no-address' ? 'Tiempo de entrega por calcular' : deliveryStatus.value === 'unavailable' ? 'Tiempo estimado no disponible' : 'Calculando…')

async function refreshCapacity() {
  const request = ++capacityRequest
  if (!cart.restaurant?.id || !session.user?.id) { capacity.value = null; return }
  try {
    const { addresses } = await loadCheckoutData(session.user.id)
    const address = addresses.find((item) => item.predeterminada) || addresses[0]
    if (!address) { capacity.value = null; return }
    const result = await getCheckoutCapacity(cart.restaurant.id, address.id)
    if (request === capacityRequest) capacity.value = result
  } catch { /* El carrito conserva su flujo si la consulta no está disponible. */ }
}

function showCheckoutNotice() { router.push('/checkout') }

function addSuggestion(product) {
  cart.addItem(product, cart.restaurant)
  suggestions.value = suggestions.value.filter((item) => item.id !== product.id)
}

onMounted(() => { loadSuggestions(); refreshDeliveryEstimate(); refreshCapacity(); capacityTimer = window.setInterval(refreshCapacity, 10000) })
onBeforeUnmount(() => window.clearInterval(capacityTimer))
watch(() => [cart.restaurant?.id, session.user?.id], () => { refreshDeliveryEstimate(); refreshCapacity() })
</script>

<template>
  <main class="cart-page">
    <header class="cart-header"><button class="icon-button" aria-label="Regresar" @click="router.back()"><ArrowLeft :size="24" /></button><h1>Tu carrito</h1><span class="cart-header-spacer" aria-hidden="true"></span></header>
    <template v-if="cart.items.length">
      <section class="cart-restaurant"><div class="cart-restaurant__identity"><img v-if="cart.restaurant?.image" :src="cart.restaurant.image" :alt="cart.restaurant.nombre" /><strong>{{ cart.restaurant?.nombre }}</strong></div><button>Ir al local</button></section>
      <div class="cart-delivery-switch"><button class="active">Delivery</button><button>Retiro en el local</button></div>
      <section class="cart-delivery-info"><span><Clock3 :size="14" /> Recibes en <b>{{ deliveryLabel }}</b></span><button>Programar</button><span>Envío <b>$1.94</b> · <strong>Gratis con plus</strong></span><LogisticsCapacityNotice :capacity="capacity" :estimate-label="deliveryLabel" compact /></section>
      <section class="cart-items"><article v-for="item in cart.items" :key="item.id" class="cart-item"><img :src="item.imagen_url || images.productoDefault" :alt="item.nombre" /><div class="cart-item__info"><strong>{{ item.nombre }}</strong><b>${{ Number(item.precio).toFixed(2) }}</b><span>{{ item.descripcion || 'Sin complemento' }}</span><button>Editar</button></div><div class="cart-item__quantity"><button aria-label="Disminuir cantidad" @click="cart.updateQuantity(item.id, -1)"><Trash2 :size="14" /></button><span>{{ item.quantity }}</span><button aria-label="Aumentar cantidad" @click="cart.updateQuantity(item.id, 1)"><Plus :size="16" /></button></div></article></section>
      <section v-if="suggestions.length" class="cart-suggestions"><h2>¿Te tienta algo más?</h2><div class="cart-suggestions__scroller"><article v-for="product in suggestions" :key="product.id" class="cart-suggestion"><img :src="product.imagen_url || images.productoDefault" :alt="product.nombre" /><button aria-label="Agregar producto" @click="addSuggestion(product)"><Plus :size="18" /></button><strong>{{ product.nombre }}</strong><span>${{ Number(product.precio).toFixed(2) }}</span></article></div></section>
      <section class="cart-more-space"><h2>Recomendaciones</h2></section>
      <footer class="cart-footer"><div><span>Subtotal</span><strong>${{ cart.subtotal.toFixed(2) }}</strong></div><button @click="showCheckoutNotice">Ir a pagar</button></footer>
    </template>
    <section v-else class="cart-empty"><ShoppingCart :size="42" /><h2>Tu carrito está vacío</h2><p>Agrega productos desde un restaurante para verlos aquí.</p><button @click="router.push('/restaurantes')">Explorar restaurantes</button></section>
    <Transition name="notice"><p v-if="notice" class="cart-notice">{{ notice }}</p></Transition>
  </main>
</template>
