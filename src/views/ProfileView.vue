<script setup>
import { onMounted, ref } from 'vue'
import { ArrowLeft, Bike, ChevronRight, CircleHelp, CirclePercent, Home, House, LogOut, Package, ReceiptText, Store, UserRound } from 'lucide-vue-next'
import { useRoute, useRouter } from 'vue-router'
import { useSessionStore } from '../stores/session'
import { getMyCourierRequest } from '../services/courierRegistrationService'

const router = useRouter(); const route = useRoute(); const session = useSessionStore(); const loading = ref(true); const courierSoon = ref(false); const courierRequest = ref(null)
const initials = () => (session.profile?.nombre || session.user?.email || '?').split(/\s+/).map((part) => part[0]).slice(0, 2).join('').toUpperCase()
async function load() { await session.initialize(); if (session.isAuthenticated && session.role === 'CLIENTE') { try { courierRequest.value = await getMyCourierRequest(session.user.id) } catch { /* El perfil sigue disponible aunque la solicitud no cargue. */ } } loading.value = false }
function courierLabel() { if (session.role === 'REPARTIDOR') return 'Ir a mi panel de repartidor'; if (courierRequest.value?.estado === 'PENDIENTE') return 'Solicitud en revisión'; if (courierRequest.value?.estado === 'RECHAZADA') return 'Solicitud rechazada'; return 'Quiero ser repartidor' }
function openCourier() { if (session.role === 'REPARTIDOR') router.push('/repartidor'); else router.push('/registro/repartidor') }
async function logout() { if (!window.confirm('¿Quieres cerrar sesión?')) return; await session.signOut(); router.replace('/') }
onMounted(load)
</script>

<template>
  <main class="profile-page">
    <header class="profile-header"><button @click="router.back"><ArrowLeft :size="22" /></button><h1>Mi perfil</h1><span /></header>
    <section v-if="loading" class="profile-empty">Cargando perfil…</section>
    <template v-else-if="!session.isAuthenticated"><section class="profile-guest"><span class="profile-guest-icon"><UserRound :size="38" /></span><h2>Inicia sesión para acceder a tu perfil</h2><button class="profile-primary" @click="router.push('/login')">Iniciar sesión</button><button class="profile-secondary" @click="router.push('/registro')">Crear cuenta</button></section></template>
    <template v-else>
      <section class="profile-identity"><span class="profile-avatar">{{ initials() }}</span><div><h2>{{ session.profile?.nombre || 'Usuario' }}</h2><p>{{ session.user?.email }}</p></div></section>
      <div class="profile-options">
        <button @click="router.push({ name: 'profile-data' })"><UserRound :size="20" /><span><strong>Mis datos personales</strong><small>Nombre, teléfono y correo</small></span><ChevronRight :size="18" /></button>
        <button @click="router.push({ name: 'address-select', query: { from: 'profile' } })"><House :size="20" /><span><strong>Mis direcciones</strong><small>Consulta y edita tus ubicaciones</small></span><ChevronRight :size="18" /></button>
        <button @click="router.push('/cliente')"><Package :size="20" /><span><strong>Mis pedidos</strong><small>Ir a la sección de pedidos</small></span><ChevronRight :size="18" /></button>
        <button @click="openCourier"><Bike :size="20" /><span><strong>{{ courierLabel() }}</strong><small>{{ courierRequest?.estado === 'RECHAZADA' ? (courierRequest.motivo_rechazo || 'Consulta el motivo') : 'Registro y disponibilidad' }}</small></span><ChevronRight :size="18" /></button>
        <button @click="router.push({ name: 'profile-help' })"><CircleHelp :size="20" /><span><strong>Ayuda y soporte</strong><small>Preguntas frecuentes</small></span><ChevronRight :size="18" /></button>
      </div>
      <section v-if="courierSoon" class="profile-info"><strong>Accede a la opción de repartidor desde este menú.</strong></section>
      <button class="profile-logout" @click="logout"><LogOut :size="18" /> Cerrar sesión</button>
    </template>
    <nav class="bottom-nav" aria-label="Navegación principal"><RouterLink class="bottom-nav__item" :class="{ 'is-active': route.path === '/' }" to="/"><Home :size="23" fill="currentColor" /><span>Inicio</span></RouterLink><RouterLink class="bottom-nav__item" :class="{ 'is-active': route.path === '/restaurantes' }" to="/restaurantes"><Store :size="23" /><span>Mercados</span></RouterLink><a class="bottom-nav__item" href="#"><CirclePercent :size="23" /><span>Promociones</span></a><RouterLink class="bottom-nav__item" :class="{ 'is-active': route.path === '/cliente' }" to="/cliente"><ReceiptText :size="23" /><span>Pedidos</span></RouterLink><RouterLink class="bottom-nav__item" :class="{ 'is-active': route.path === '/perfil' }" to="/perfil"><UserRound :size="23" /><span>Mi perfil</span></RouterLink></nav>
  </main>
</template>
