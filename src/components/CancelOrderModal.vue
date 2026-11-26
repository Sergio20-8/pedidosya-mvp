<script setup>
import { ref, watch } from 'vue'
import { AlertTriangle, X } from 'lucide-vue-next'
import '../assets/cancel-order.css'

const props = defineProps({
  modelValue: Boolean,
  role: { type: String, default: 'client' },
  order: { type: Object, default: null },
  busy: Boolean,
})
const emit = defineEmits(['close', 'confirm'])
const reason = ref('')
const description = ref('')
const error = ref('')
const clientReasons = [
  ['CAMBIO_DE_OPINION', 'Cambié de opinión'], ['ERROR_EN_PEDIDO', 'Hay un error en mi pedido'],
  ['DIRECCION_INCORRECTA', 'La dirección es incorrecta'], ['DEMORA_EN_PEDIDO', 'El pedido está tardando'], ['OTRO', 'Otro'],
]
const adminReasons = [
  ['SIN_REPARTIDORES_EN_AREA', 'Sin repartidores en el área'], ['RESTAURANTE_RECHAZA', 'El restaurante rechazó el pedido'],
  ['PRODUCTOS_NO_DISPONIBLES', 'Productos no disponibles'], ['PROBLEMAS_DE_ENTREGA', 'Problemas de entrega'],
  ['SOLICITUD_CLIENTE', 'Solicitud del cliente'], ['OTRO', 'Otro'],
]
const reasons = props.role === 'admin' ? adminReasons : clientReasons
watch(() => props.modelValue, (open) => { if (open) { reason.value = ''; description.value = ''; error.value = '' } })
function submit() {
  if (!reason.value) { error.value = 'Selecciona un motivo para continuar.'; return }
  if (reason.value === 'OTRO' && !description.value.trim()) { error.value = 'Describe el motivo de la cancelación.'; return }
  emit('confirm', { motivo: reason.value, descripcion: description.value.trim() || null })
}
</script>

<template>
  <div v-if="modelValue" class="cancel-modal" role="presentation" @click.self="emit('close')">
    <section class="cancel-modal__card" role="dialog" aria-modal="true" aria-labelledby="cancel-modal-title">
      <button class="cancel-modal__close" type="button" aria-label="Cerrar" :disabled="busy" @click="emit('close')"><X :size="19" /></button>
      <div class="cancel-modal__icon"><AlertTriangle :size="24" /></div>
      <h2 id="cancel-modal-title">{{ role === 'admin' ? 'Cancelar pedido' : '¿Cancelar pedido?' }}</h2>
      <p>{{ role === 'admin' ? 'Selecciona el motivo y confirma la cancelación.' : 'Esta acción no se puede deshacer.' }}</p>
      <div v-if="role === 'admin' && order" class="cancel-modal__summary">
        <span>Total: <strong>${{ Number(order.total || 0).toFixed(2) }}</strong></span>
        <span>Pago: <strong>{{ order.metodo_pago === 'TARJETA_SIMULADA' ? 'Tarjeta' : 'Efectivo' }} · {{ order.estado_pago || 'PENDIENTE' }}</strong></span>
      </div>
      <label class="cancel-modal__field">Motivo<select v-model="reason"><option value="" disabled>Selecciona un motivo</option><option v-for="item in reasons" :key="item[0]" :value="item[0]">{{ item[1] }}</option></select></label>
      <label v-if="reason === 'OTRO'" class="cancel-modal__field">Descripción<textarea v-model="description" rows="3" placeholder="Explica brevemente el motivo" /></label>
      <p v-if="role === 'admin' && order" class="cancel-modal__refund">{{ order.estado_pago === 'PAGADO' ? (reason === 'SIN_REPARTIDORES_EN_AREA' ? 'Se generará un reembolso automático.' : 'Se enviará a revisión manual el reembolso.') : 'No se generará ningún reembolso porque el pedido no está pagado.' }}</p>
      <p v-if="error" class="cancel-modal__error" aria-live="polite">{{ error }}</p>
      <div class="cancel-modal__actions"><button type="button" class="cancel-modal__secondary" :disabled="busy" @click="emit('close')">Volver</button><button type="button" class="cancel-modal__primary" :disabled="busy" @click="submit">{{ busy ? 'Cancelando…' : 'Confirmar cancelación' }}</button></div>
    </section>
  </div>
</template>
