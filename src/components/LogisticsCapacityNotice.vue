<script setup>
import { computed } from 'vue'
import { AlertTriangle, Clock3, UsersRound } from 'lucide-vue-next'

const props = defineProps({
  capacity: { type: Object, default: null },
  estimateLabel: { type: String, default: '' },
  compact: { type: Boolean, default: false }
})

const state = computed(() => {
  const reason = props.capacity?.motivo
  if (reason === 'SIN_REPARTIDORES') return 'unavailable'
  if (reason === 'ZONA_BLOQUEADA') return 'recovering'
  if (reason === 'CAPACIDAD_SUPERADA') return 'saturated'
  if (props.capacity?.advertencia) return 'warning'
  return 'normal'
})

const content = computed(() => ({
  warning: { title: 'Tenemos alta demanda', message: 'Tu pedido podría tardar más de lo habitual debido a la disponibilidad de repartidores en tu zona.', icon: Clock3 },
  saturated: { title: 'Alta demanda en tu zona', message: 'Temporalmente no podemos aceptar nuevos pedidos debido a la saturación de repartidores. Intenta nuevamente más tarde.', icon: AlertTriangle },
  unavailable: { title: 'Sin repartidores disponibles', message: 'Por el momento no contamos con repartidores disponibles en tu zona. Intenta nuevamente más tarde.', icon: UsersRound },
  recovering: { title: 'Zona recuperando capacidad', message: 'Esta zona todavía está recuperando su capacidad de entrega. Intenta nuevamente en unos minutos.', icon: Clock3 }
}[state.value] || null))
</script>

<template>
  <aside v-if="content" class="logistics-notice" :class="[`logistics-notice--${state}`, { 'logistics-notice--compact': compact }]" role="status">
    <component :is="content.icon" :size="compact ? 18 : 21" aria-hidden="true" />
    <div>
      <strong>{{ content.title }}</strong>
      <p>{{ content.message }}</p>
      <small v-if="state === 'warning' && estimateLabel">Tiempo estimado habitual: {{ estimateLabel }}. La demora adicional por saturación aún no puede calcularse con los datos disponibles.</small>
    </div>
  </aside>
</template>
