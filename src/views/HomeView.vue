<script setup>
import { onMounted, onUnmounted, ref } from 'vue'
import { Bell, ChevronDown, CirclePercent, Home, ReceiptText, Search, ShoppingCart, Store, UserRound } from 'lucide-vue-next'
import { images } from '../constants/images'
import { useCartStore } from '../stores/cart'

const promoScroller = ref(null)
const cart = useCartStore()
let promoTimer

function advancePromos() {
  const scroller = promoScroller.value
  if (!scroller) return
  const cards = [...scroller.querySelectorAll('.promo-card')]
  if (!cards.length) return
  const current = cards.reduce((closest, card, index) => {
    const distance = Math.abs(card.offsetLeft - scroller.scrollLeft - 17)
    return distance < closest.distance ? { index, distance } : closest
  }, { index: 0, distance: Infinity })
  const nextIndex = (current.index + 1) % cards.length
  const horizontalPadding = 17
  const target = nextIndex === 0 ? 0 : Math.max(0, cards[nextIndex].offsetLeft - horizontalPadding)
  scroller.scrollTo({ left: target, behavior: 'smooth' })
}

onMounted(() => { promoTimer = window.setInterval(advancePromos, 5000) })
onUnmounted(() => { window.clearInterval(promoTimer) })

const categories = [
  { name: 'Mercados', image: images.mercados },
  { name: 'Bebidas', image: images.bebidas },
  { name: 'Farmacias', image: images.farmacias },
  { name: 'Café', image: images.cafe }
]
</script>

<template>
  <main class="client-home">
    <section class="home-header">
      <div class="header-row">
        <button class="location-button" aria-label="Cambiar dirección"><span>Unnamed Road</span><ChevronDown :size="19" stroke-width="2.2" /></button>
        <div class="header-actions"><button aria-label="Notificaciones"><Bell :size="23" /></button><RouterLink class="cart-link" to="/carrito" aria-label="Carrito"><ShoppingCart :size="24" /><b v-if="cart.count" class="cart-badge">{{ cart.count }}</b></RouterLink></div>
      </div>
      <div class="search-bar"><span>Locales, platos y productos</span><button aria-label="Buscar"><Search :size="20" stroke-width="2.4" /></button></div>
    </section>

    <div class="home-content">
      <section class="main-food-banner" aria-label="Descubre algo delicioso">
        <div class="main-food-banner__decor"></div>
        <div class="main-food-banner__copy"><span>PARA HOY</span><strong>¡Tu comida favorita!</strong><p>Descubre algo delicioso</p></div>
        <img :src="images.bannerPrincipal" alt="Pizza con vegetales y carnes" />
      </section>

      <section class="feature-grid" aria-label="Explorar servicios">
        <RouterLink class="feature-card" to="/restaurantes"><img :src="images.restaurantes" alt="Hamburguesa" /><h2>Restaurantes</h2></RouterLink>
        <article class="feature-card"><img :src="images.market" alt="Productos de supermercado" /><h2>PedidosYa Market</h2></article>
      </section>

      <section class="category-scroller" aria-label="Categorías">
        <article v-for="category in categories" :key="category.name" class="category-card"><img :src="category.image" :alt="category.name" /><h2>{{ category.name }}</h2></article>
      </section>

      <section ref="promoScroller" class="promo-scroller" aria-label="Más opciones deliciosas">
        <a class="promo-card promo-card--pizzapizza" :href="images.bannerPrincipalPizzaPizzaUrl" target="_blank" rel="noopener noreferrer" aria-label="Abrir banner promocional">
          <img class="promo-card__full-image" :src="images.bannerPrincipalPizzaPizza" alt="Banner promocional de pizza" />
        </a>
        <article class="promo-card promo-card--pizza">
          <div class="promo-card__copy"><span>PARA COMPARTIR</span><strong>Un momento<br />delicioso</strong><small>Disfruta algo rico hoy</small></div>
          <div class="promo-card__visual"><img :src="images.bannerPizza" alt="Pizza recién horneada" /></div>
        </article>
        <article class="promo-card promo-card--lasana">
          <div class="promo-card__copy"><span>SABOR CASERO</span><strong>Algo rico<br />para hoy</strong><small>Una opción reconfortante</small></div>
          <div class="promo-card__visual"><img :src="images.bannerLasana" alt="Lasaña" /></div>
        </article>
      </section>
    </div>

    <nav class="bottom-nav" aria-label="Navegación principal">
      <RouterLink class="bottom-nav__item is-active" to="/"><Home :size="23" fill="currentColor" /><span>Inicio</span></RouterLink><RouterLink class="bottom-nav__item" to="/restaurantes"><Store :size="23" /><span>Mercados</span></RouterLink><a class="bottom-nav__item" href="#"><CirclePercent :size="23" /><span>Promociones</span></a><RouterLink class="bottom-nav__item" to="/cliente"><ReceiptText :size="23" /><span>Pedidos</span></RouterLink><RouterLink class="bottom-nav__item" to="/perfil"><UserRound :size="23" /><span>Mi perfil</span></RouterLink>
    </nav>
  </main>
</template>
