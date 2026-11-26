<script setup>
import { AlertTriangle, Clock3, UsersRound, X } from 'lucide-vue-next'

defineProps({
  modelValue: { type: Boolean, default: false },
  kind: { type: String, default: 'blocked' },
  estimateLabel: { type: String, default: '' },
  busy: { type: Boolean, default: false }
})

const emit = defineEmits(['update:modelValue', 'continue', 'close', 'back'])

const copy = {
  warning: {
    title: '¡Tenemos alta demanda!',
    message: 'En este momento tenemos muchos pedidos en tu zona. Tu entrega podría tardar más de lo habitual',
    icon: Clock3,
    primary: 'Continuar con mi pedido',
    secondary: 'Volver al carrito'
  },
  saturated: {
    title: 'Tu zona está saturada',
    message: 'Temporalmente no podemos aceptar nuevos pedidos en tu zona. Intenta nuevamente más tarde',
    icon: AlertTriangle,
    primary: 'Entendido'
  },
  unavailable: {
    title: 'No hay repartidores disponibles',
    message: 'Por el momento no contamos con repartidores disponibles para realizar tu entrega',
    icon: UsersRound,
    primary: 'Entendido'
  },
  error: {
    title: 'No pudimos validar tu zona',
    message: 'No se pudo consultar la capacidad logística. Intenta nuevamente antes de confirmar tu pedido.',
    icon: AlertTriangle,
    primary: 'Entendido'
  }
}
</script>

<template>
  <Teleport to="body">
    <div v-if="modelValue" class="logistics-modal" role="presentation" @click.self="emit('close')">
      <section class="logistics-modal__card" :class="`logistics-modal__card--${kind}`" role="dialog" aria-modal="true" aria-labelledby="logistics-modal-title">
        <button class="logistics-modal__close" type="button" aria-label="Cerrar" :disabled="busy" @click="emit('close')"><X :size="19" /></button>
        <div class="logistics-modal__icon"><component :is="copy[kind]?.icon || copy.error.icon" :size="25" /></div>
        <h2 id="logistics-modal-title">{{ copy[kind]?.title || copy.error.title }}</h2>
        <p>{{ copy[kind]?.message || copy.error.message }}</p>
        <p v-if="kind === 'warning' && estimateLabel" class="logistics-modal__estimate">Tiempo estimado habitual: <strong>{{ estimateLabel }}</strong></p>
        <div class="logistics-modal__actions">
          <button v-if="kind === 'warning'" type="button" class="logistics-modal__secondary" :disabled="busy" @click="emit('back')">{{ copy.warning.secondary }}</button>
          <button type="button" class="logistics-modal__primary" :disabled="busy" @click="kind === 'warning' ? emit('continue') : emit('close')">{{ busy ? 'Validando…' : (copy[kind]?.primary || copy.error.primary) }}</button>
        </div>
      </section>
    </div>
  </Teleport>
</template>
