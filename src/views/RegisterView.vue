<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useSessionStore } from '../stores/session'
const session = useSessionStore(); const router = useRouter(); const route = useRoute()
const form = ref({ nombre: '', telefono: '', email: '', password: '', confirmation: '' }); const busy = ref(false); const message = ref(''); const success = ref(false); const step = ref(1)
async function submit() {
  message.value = ''
  if (form.value.password !== form.value.confirmation) { message.value = 'Las contraseñas no coinciden.'; return }
  busy.value = true
  try { const data = await session.signUp(form.value); success.value = !data.session; if (data.session) { await session.refreshProfile(); step.value = 2; const savedRedirect = sessionStorage.getItem('pedidosya-pending-redirect'); const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : savedRedirect; router.replace({ name: 'address-new', query: { from: 'register', redirect: typeof redirect === 'string' && redirect.startsWith('/') ? redirect : '/cliente', gps: '1' } }) } }
  catch (error) { message.value = error.message || 'No se pudo crear la cuenta.' }
  finally { busy.value = false }
}
</script>

<template>
  <main class="page centered"><form class="card auth-card" @submit.prevent="submit">
    <p class="eyebrow">Paso 1 de 2 · Cuenta</p><h1>Crear cuenta</h1><p class="muted">{{ route.query.redirect === '/registro/repartidor' ? 'Primero crea tu cuenta. Después podrás enviar tu solicitud como repartidor.' : 'Crea tu cuenta y después registra tu primera dirección de entrega.' }}</p><div class="auth-step-indicator"><span class="active">1. Cuenta</span><span>2. Dirección</span></div>
    <p v-if="success" class="success">Cuenta creada. Revisa tu correo para confirmar el acceso.</p>
    <label>Nombre<input v-model="form.nombre" autocomplete="name" required /></label><label>Teléfono<input v-model="form.telefono" type="tel" autocomplete="tel" /></label>
    <label>Correo<input v-model="form.email" type="email" autocomplete="email" required /></label><label>Contraseña<input v-model="form.password" type="password" minlength="6" autocomplete="new-password" required /></label>
    <label>Confirmar contraseña<input v-model="form.confirmation" type="password" minlength="6" autocomplete="new-password" required /></label>
    <p v-if="message" class="error">{{ message }}</p><button class="primary" :disabled="busy">{{ busy ? 'Creando…' : 'Crear cuenta' }}</button>
    <p class="auth-link"><RouterLink :to="{ name: 'login', query: route.query.redirect ? { redirect: route.query.redirect } : {} }">Ya tengo una cuenta</RouterLink></p>
  </form></main>
</template>
