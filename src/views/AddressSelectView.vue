<script setup>
import { onMounted, ref } from 'vue'
import { ArrowLeft, BriefcaseBusiness, Crosshair, House, MapPin, Pencil, Plus } from 'lucide-vue-next'
import { useRoute, useRouter } from 'vue-router'
import { loadCheckoutData } from '../services/orderService'
import { useSessionStore } from '../stores/session'
import '../assets/address.css'
const router = useRouter(); const route = useRoute(); const session = useSessionStore(); const addresses = ref([]); const loading = ref(true); const error = ref('')
async function load() { try { addresses.value = (await loadCheckoutData(session.user.id)).addresses } catch (e) { error.value = e.message || 'No se pudieron cargar tus direcciones.' } finally { loading.value = false } }
function choose(address) { router.replace({ name: 'checkout', query: { address: address.id, from: route.query.from || 'checkout' } }) }
function icon(address) { return (address.alias || '').toLowerCase().includes('trab') ? BriefcaseBusiness : address.alias?.toLowerCase().includes('casa') ? House : MapPin }
onMounted(load)
</script>
<template><main class="addresses-page"><header class="addresses-header"><button @click="router.back"><ArrowLeft :size="22" /></button><h1>¿Dónde recibes tu pedido?</h1><span /></header><section><button class="address-gps-button" @click="router.push({ name: 'address-new', query: { from: 'select', gps: '1' } })"><span class="address-gps-button__icon"><Crosshair :size="20" /></span><span><strong>Usar mi ubicación actual</strong><small>El navegador te pedirá permiso para usar el GPS</small></span></button><div v-if="loading" class="address-empty">Cargando direcciones…</div><div v-else-if="error" class="address-empty address-empty--error">{{ error }}</div><div v-else-if="!addresses.length" class="address-empty"><MapPin :size="42" /><h2>Aún no tienes direcciones</h2><p>Agrega tu primera ubicación de entrega.</p></div><div v-else class="saved-addresses"><button v-for="address in addresses" :key="address.id" class="saved-address" @click="choose(address)"><component :is="icon(address)" :size="21" /><span><strong>{{ address.alias || 'Ubicación' }}</strong><small>{{ address.detalle }}</small><small v-if="address.referencia">{{ address.referencia }}</small><small>{{ address.zonas?.nombre }}</small></span><RouterLink :to="{ name: 'address-edit', params: { id: address.id }, query: { from: 'select' } }" @click.stop><Pencil :size="17" /></RouterLink></button></div><button class="address-add-button" @click="router.push({ name: 'address-new', query: { from: 'select' } })"><Plus :size="18" /> Agregar nueva dirección</button></section></main></template>
