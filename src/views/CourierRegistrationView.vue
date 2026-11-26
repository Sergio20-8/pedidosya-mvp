<script setup>
import { onMounted, reactive, ref } from 'vue'
import { ArrowLeft, Bike, Car, Check, CircleHelp, LoaderCircle, Motorbike } from 'lucide-vue-next'
import { useRouter } from 'vue-router'
import { useSessionStore } from '../stores/session'
import { getMyCourierRequest, listActiveZones, submitCourierRequest } from '../services/courierRegistrationService'

const router = useRouter(); const session = useSessionStore(); const loading = ref(true); const sending = ref(false); const error = ref(''); const sent = ref(false); const zones = ref([]); const existing = ref(null); const form = reactive({ zona_id: '', tipo_vehiculo: 'MOTOCICLETA' })
const vehicles = [{ value: 'MOTOCICLETA', label: 'Motocicleta', icon: Motorbike }, { value: 'BICICLETA', label: 'Bicicleta', icon: Bike }, { value: 'AUTOMOVIL', label: 'Automóvil', icon: Car }]
async function load() { await session.initialize(); if (!session.isAuthenticated) { loading.value = false; return } try { zones.value = await listActiveZones(); existing.value = await getMyCourierRequest(session.user.id) } catch (e) { error.value = e.message || 'No se pudo cargar el registro.' } finally { loading.value = false } }
async function submit() {
  error.value = ''
  if (!session.isAuthenticated || !session.user?.id) { error.value = 'Tu sesión expiró. Inicia sesión nuevamente.'; return }
  if (!form.zona_id) { error.value = 'Selecciona una zona de trabajo.'; return }
  sending.value = true
  try { await session.refreshProfile(); if (session.role !== 'CLIENTE') throw new Error('Solo los clientes pueden enviar una solicitud nueva.'); await submitCourierRequest(form.zona_id, form.tipo_vehiculo); existing.value = { estado: 'PENDIENTE' }; sent.value = true }
  catch (e) { const message = e?.message || ''; error.value = message.includes('SOLICITUD_PENDIENTE_EXISTENTE') ? 'Ya tienes una solicitud pendiente.' : message.includes('ZONA_NO_DISPONIBLE') ? 'La zona seleccionada ya no está disponible.' : message || 'No se pudo enviar la solicitud.' }
  finally { sending.value = false }
}
onMounted(load)
</script>

<template>
  <main class="courier-registration-page">
    <header class="profile-header"><button @click="router.back"><ArrowLeft :size="22" /></button><h1>Ser repartidor</h1><span /></header>
    <section v-if="loading" class="profile-empty">Cargando formulario…</section>
    <section v-else-if="!session.isAuthenticated" class="profile-guest"><span class="profile-guest-icon"><CircleHelp :size="38" /></span><h2>Inicia sesión para solicitar tu registro</h2><button class="profile-primary" @click="router.push({ name: 'login', query: { redirect: '/registro/repartidor' } })">Iniciar sesión</button><button class="profile-secondary" @click="router.push({ name: 'register', query: { redirect: '/registro/repartidor' } })">Crear cuenta</button></section>
    <section v-else-if="sent || existing?.estado === 'PENDIENTE'" class="courier-registration-card courier-registration-success"><span class="courier-success-icon"><Check :size="28" /></span><h2>¡Tu solicitud fue enviada!</h2><p>Estamos revisando tu registro como repartidor.</p><small>Te avisaremos cuando el administrador revise la solicitud.</small></section>
    <section v-else-if="existing?.estado === 'APROBADA'" class="courier-registration-card courier-registration-success"><span class="courier-success-icon"><Check :size="28" /></span><h2>Solicitud aprobada</h2><p>Ya puedes acceder a tu panel de repartidor.</p><button class="profile-primary" @click="router.push('/repartidor')">Ir a mi panel</button></section>
    <section v-else class="courier-registration-card"><span class="profile-eyebrow">NUEVO REPARTIDOR</span><h2>Completa tu solicitud</h2><p class="courier-registration-intro">Usaremos estos datos para revisar tu registro.</p><div class="courier-readonly"><strong>{{ session.profile?.nombre || 'Sin nombre' }}</strong><span>{{ session.user?.email }}</span><span>{{ session.profile?.telefono || 'Teléfono no registrado' }}</span></div><label class="courier-field">Zona donde deseas trabajar<select v-model="form.zona_id"><option value="" disabled>Selecciona una zona</option><option v-for="zone in zones" :key="zone.id" :value="zone.id">{{ zone.nombre }}</option></select></label><fieldset class="courier-vehicle"><legend>Tipo de vehículo</legend><button v-for="vehicle in vehicles" :key="vehicle.value" type="button" :class="{ active: form.tipo_vehiculo === vehicle.value }" @click="form.tipo_vehiculo = vehicle.value"><component :is="vehicle.icon" :size="20" /><span>{{ vehicle.label }}</span></button></fieldset><p v-if="error" class="profile-error">{{ error }}</p><button class="profile-primary courier-submit" type="button" :disabled="sending" @click="submit"><LoaderCircle v-if="sending" class="spin" :size="18" />{{ sending ? 'Enviando…' : 'Enviar solicitud' }}</button><small class="courier-registration-note">No solicitamos documentos ni fotografías en esta versión.</small></section>
  </main>
</template>
