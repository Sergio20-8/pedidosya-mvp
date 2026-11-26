<script setup>
import { computed, ref } from 'vue'
import { ArrowLeft, Check, Clock3, LocateFixed, MapPin, Navigation, Truck } from 'lucide-vue-next'
import CourierRequestMap from './CourierRequestMap.vue'
import DeliveryLocationPicker from './DeliveryLocationPicker.vue'
const props = defineProps({ order: { type: Object, required: true }, updating: { type: Boolean, default: false }, locationUpdating: { type: Boolean, default: false } })
const emit = defineEmits(['advance', 'back', 'update-location'])
const pickerOpen = ref(false)
const destination = computed(() => props.order.direcciones || null)
const courier = computed(() => props.order.repartidor_ubicacion || null)
const restaurantNavigation = computed(() => props.order.restaurantes?.pos_y != null && props.order.restaurantes?.pos_x != null ? `https://www.google.com/maps/dir/?api=1&destination=${props.order.restaurantes.pos_y},${props.order.restaurantes.pos_x}` : null)
const clientNavigation = computed(() => destination.value?.latitud != null && destination.value?.longitud != null ? `https://www.google.com/maps/dir/?api=1&destination=${destination.value.latitud},${destination.value.longitud}` : null)
const canUpdateLocation = computed(() => ['ASIGNADO', 'RECOGIDO', 'EN_CAMINO'].includes(props.order.estado))
function confirmLocation(point) { emit('update-location', point) }
</script>
<template>
  <section class="courier-active-delivery">
    <header class="courier-detail-header"><button @click="emit('back')"><ArrowLeft :size="20" /></button><div><span>ENTREGA ACTIVA · #{{ order.numero }}</span><h2>{{ order.restaurantes?.nombre }}</h2></div></header>
    <p class="courier-order-state">{{ order.estado }}</p>
    <CourierRequestMap :restaurant="order.restaurantes" :destination="destination" :courier="courier" :state="order.estado" />
    <div class="courier-delivery-info"><div><MapPin :size="18" /><span><b>Recogida</b><strong>{{ order.restaurantes?.nombre }}</strong><small>Ubicación del restaurante</small></span><a v-if="restaurantNavigation" :href="restaurantNavigation" target="_blank" rel="noopener"><Navigation :size="18" /></a></div><div><MapPin :size="18" /><span><b>Entrega</b><strong>{{ destination?.detalle || order.direccion_snapshot }}</strong><small>{{ destination?.referencia || destination?.zonas?.nombre || 'Dirección del cliente' }}</small></span><a v-if="clientNavigation" :href="clientNavigation" target="_blank" rel="noopener"><Navigation :size="18" /></a></div></div>
    <div class="courier-detail-section"><h3>Productos</h3><div v-for="line in order.pedido_detalles || []" :key="line.id" class="courier-product-line"><img v-if="line.productos?.imagen_url" :src="line.productos.imagen_url" :alt="line.nombre_producto_snapshot" /><div><strong>{{ line.cantidad }} × {{ line.nombre_producto_snapshot }}</strong><small>{{ line.observaciones || 'Sin instrucciones adicionales' }}</small></div></div></div>
    <div v-if="canUpdateLocation" class="courier-location-card"><div class="courier-location-card__icon"><LocateFixed :size="20" /></div><div><strong>Tu ubicación</strong><small v-if="courier?.actualizada_en"><Clock3 :size="13" /> Actualizada {{ new Date(courier.actualizada_en).toLocaleTimeString('es-SV', { hour: '2-digit', minute: '2-digit' }) }}</small><small v-else>Selecciona tu punto de partida</small></div><button class="courier-location-update" :disabled="locationUpdating" @click="pickerOpen = true"><LocateFixed :size="16" /> {{ locationUpdating ? 'Guardando…' : 'Actualizar' }}</button></div>
    <div class="courier-active-action"><button v-if="order.estado === 'ASIGNADO'" class="courier-accept" :disabled="updating" @click="emit('advance', 'RECOGIDO')"><Check :size="18" /> Confirmar recogida</button><button v-else-if="order.estado === 'RECOGIDO'" class="courier-accept" :disabled="updating" @click="emit('advance', 'EN_CAMINO')"><Truck :size="18" /> Iniciar entrega</button><button v-else-if="order.estado === 'EN_CAMINO'" class="courier-accept" :disabled="updating" @click="emit('advance', 'ENTREGADO')"><Check :size="18" /> Marcar como entregado</button><div v-else class="courier-delivered-message">¡Entrega completada!</div></div>
    <DeliveryLocationPicker v-if="pickerOpen" mode="courier" :saving="locationUpdating" :latitud="courier?.pos_y" :longitud="courier?.pos_x" :restaurant="order.restaurantes" :destination="destination" :state="order.estado" @cancel="pickerOpen = false" @confirm="confirmLocation" />
  </section>
</template>

