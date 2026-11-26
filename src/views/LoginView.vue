<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useSessionStore } from '../stores/session'
import { loadCheckoutData } from '../services/orderService'
const session = useSessionStore(); const router = useRouter(); const route = useRoute()
const email = ref(''); const password = ref(''); const busy = ref(false); const message = ref('')
function roleHome(role) { return { ADMIN: '/admin', REPARTIDOR: '/repartidor', CLIENTE: '/cliente' }[role] || '/' }
function destination() { const queryRedirect = route.query.redirect; const savedRedirect = sessionStorage.getItem('pedidosya-pending-redirect'); const redirect = typeof queryRedirect === 'string' ? queryRedirect : savedRedirect; sessionStorage.removeItem('pedidosya-pending-redirect'); return typeof redirect === 'string' && redirect.startsWith('/') ? redirect : roleHome(session.role) }
async function submit() {
  busy.value = true; message.value = ''
  try { await session.signIn(email.value, password.value); await session.refreshProfile(); const queryRedirect = typeof route.query.redirect === 'string' ? route.query.redirect : sessionStorage.getItem('pedidosya-pending-redirect'); sessionStorage.removeItem('pedidosya-pending-redirect'); if (session.role === 'CLIENTE' && queryRedirect?.startsWith('/checkout')) { const { addresses } = await loadCheckoutData(session.user.id); const validAddress = addresses.find((address) => address.latitud != null && address.longitud != null && address.detalle?.trim()); if (!validAddress) { router.replace({ name: 'address-new', query: { from: 'checkout', redirect: '/checkout', gps: '1' } }); return } } router.replace(queryRedirect?.startsWith('/') ? queryRedirect : roleHome(session.role)) }
  catch (error) { message.value = error.message || 'No se pudo iniciar sesión.' }
  finally { busy.value = false }
}
</script>

<template>
  <main class="auth-page"><form class="auth-form" @submit.prevent="submit">
    <p class="eyebrow">Acceso</p><h1>Iniciar sesión</h1>
    <label>Correo<input v-model="email" type="email" autocomplete="email" required /></label>
    <label>Contraseña<input v-model="password" type="password" autocomplete="current-password" required /></label>
    <p v-if="message" class="error">{{ message }}</p><button class="primary" :disabled="busy">{{ busy ? 'Ingresando…' : 'Ingresar' }}</button>
    <p class="auth-link">¿No tienes cuenta? <RouterLink :to="{ name: 'register', query: route.query.redirect ? { redirect: route.query.redirect } : {} }">Regístrate como cliente</RouterLink></p>
    <RouterLink class="courier-login-link" :to="{ name: 'register', query: { redirect: '/registro/repartidor' } }">¿Quieres repartir? Crea tu cuenta de repartidor</RouterLink>
  </form></main>
</template>
