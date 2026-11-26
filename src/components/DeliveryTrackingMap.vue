<script setup>
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
const props = defineProps({ restaurant: Object, destination: Object, courier: Object })
const mapElement = ref(null); const hasCoordinates = ref(false); let map; let markers = []
function valid(point) { return Number.isFinite(Number(point?.pos_x)) && Number.isFinite(Number(point?.pos_y)) }
function redraw() { if (!map) return; markers.forEach((marker) => marker.remove()); markers = []; const points = [props.restaurant, props.destination, props.courier].filter(valid).map((point) => [Number(point.pos_y), Number(point.pos_x)]); hasCoordinates.value = points.length >= 2; if (!points.length) return; const labels = ['Restaurante', 'Destino', 'Repartidor']; [props.restaurant, props.destination, props.courier].forEach((point, index) => { if (valid(point)) markers.push(L.marker([Number(point.pos_y), Number(point.pos_x)]).addTo(map).bindPopup(labels[index])) }); if (points.length >= 2) map.fitBounds(points, { padding: [35, 35] }) }
onMounted(async () => { await nextTick(); map = L.map(mapElement.value, { zoomControl: false }).setView([13.69, -89.19], 13); L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '&copy; OpenStreetMap contributors' }).addTo(map); redraw() }); watch(() => [props.restaurant, props.destination, props.courier], redraw, { deep: true }); onBeforeUnmount(() => map?.remove())
</script>
<template><div ref="mapElement" class="delivery-map"><div v-if="!hasCoordinates" class="map-empty">El mapa aparecerá cuando existan coordenadas válidas para el restaurante y el destino.</div></div></template>
