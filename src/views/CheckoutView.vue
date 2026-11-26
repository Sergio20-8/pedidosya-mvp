<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue'
import { ArrowLeft, Banknote, Bike, CreditCard, Eye, EyeOff, MapPin, Pencil, Save, X } from 'lucide-vue-next'
import { useRouter } from 'vue-router'
import { useSessionStore } from '../stores/session'
import { useCartStore } from '../stores/cart'
import { confirmOrder, loadCheckoutData, saveAddress, SHIPPING_FEE } from '../services/orderService'
import { getRestaurantDetail } from '../services/restaurantService'
import { calculateDeliveryEstimate, formatDeliveryEstimate } from '../services/deliveryEstimateService'
import { getCheckoutCapacity } from '../services/logisticsService'
import DeliveryLocationPicker from '../components/DeliveryLocationPicker.vue'
import LogisticsCapacityNotice from '../components/LogisticsCapacityNotice.vue'
import LogisticsCapacityModal from '../components/LogisticsCapacityModal.vue'
import '../assets/payment-card-actions.css'

const router = useRouter(); const session = useSessionStore(); const cart = useCartStore()
const addresses = ref([]); const zones = ref([]); const selectedAddressId = ref(''); const showAddressForm = ref(false); const showAddressPicker = ref(false); const showLocationPicker = ref(false); const showCashForm = ref(false); const paymentMethod = ref('cash'); const initialPaymentMethod = ref('cash'); const initialCardIndex = ref(-1); const showCvv = ref(false); const paymentOptions = ref(null); const paying = ref(false); const error = ref(''); const cashAmount = ref(''); const exactCash = ref(false); const instructions = ref(''); const savedCards = ref([]); const selectedCardIndex = ref(-1); const savedCard = ref(null); const showCardForm = ref(false); const editingCardIndex = ref(-1)
const deliveryEstimate = ref(null); const deliveryStatus = ref('loading'); let estimateRequest = 0
const capacity = ref(null); const capacityLoading = ref(false); const capacityError = ref(''); let capacityRequest = 0; let capacityTimer
const capacityModalOpen = ref(false); const capacityModalKind = ref('blocked'); const capacityModalBusy = ref(false)
const addressForm = reactive({ alias: 'Casa', detalle: '', referencia: '', zona_id: '', latitud: null, longitud: null })
const cardForm = reactive({ number: '', name: '', expiry: '', cvv: '' })
const SAVED_CARD_KEY = 'pedidosya-card-data'
const SAVED_PAYMENT_KEY = 'pedidosya-last-payment'
const total = computed(() => cart.subtotal + SHIPPING_FEE)
const cashToPay = computed(() => String(cashAmount.value ?? '').trim() === '' ? total.value : Number(cashAmount.value))
const change = computed(() => Math.max(0, cashToPay.value - total.value))
const selectedAddress = computed(() => addresses.value.find((address) => address.id === selectedAddressId.value))
const cardNumberDigits = computed(() => cardForm.number.replace(/\D/g, ''))
const cardExpiryDigits = computed(() => cardForm.expiry.replace(/\D/g, ''))
const cardValid = computed(() => /^\d{13,19}$/.test(cardNumberDigits.value) && cardForm.name.trim().length >= 2 && /^\d{4}$/.test(cardExpiryDigits.value) && /^\d{3,4}$/.test(cardForm.cvv))
const savedCardNumber = computed(() => savedCard.value?.number?.replace(/\D/g, '') || '')
const savedCardLastFour = computed(() => savedCardNumber.value.slice(-4) || '••••')
const savedCardName = computed(() => savedCard.value?.name || 'TITULAR DE LA TARJETA')
const savedCardExpiry = computed(() => savedCard.value?.expiry || '••/••')
const paymentValid = computed(() => paymentMethod.value === 'cash' ? cashToPay.value >= total.value : cardValid.value)
const deliveryLabel = computed(() => deliveryStatus.value === 'ready' ? formatDeliveryEstimate(deliveryEstimate.value) : deliveryStatus.value === 'no-address' ? 'Tiempo de entrega por calcular' : deliveryStatus.value === 'unavailable' ? 'Tiempo estimado no disponible' : 'Calculando…')

async function refreshDeliveryEstimate() {
  const request = ++estimateRequest
  deliveryEstimate.value = null
  deliveryStatus.value = 'loading'
  const address = selectedAddress.value
  if (!cart.restaurant?.id || !address || address.latitud == null || address.longitud == null) { deliveryStatus.value = 'no-address'; return }
  try {
    const restaurant = await getRestaurantDetail(cart.restaurant.id)
    const estimate = await calculateDeliveryEstimate({ restaurant, address })
    if (request !== estimateRequest) return
    deliveryEstimate.value = estimate
    deliveryStatus.value = 'ready'
  } catch {
    if (request === estimateRequest) deliveryStatus.value = 'unavailable'
  }
}

async function refreshCapacity() { const request = ++capacityRequest; capacityError.value = ''; if (!selectedAddress.value || !cart.restaurant?.id) { capacity.value = null; return null } capacityLoading.value = true; try { const result = await getCheckoutCapacity(cart.restaurant.id, selectedAddress.value.id); if (request === capacityRequest) capacity.value = result; return result } catch (e) { if (request === capacityRequest) capacityError.value = e.message || 'No se pudo validar la capacidad de la zona.'; return null } finally { if (request === capacityRequest) capacityLoading.value = false } }

async function load() {
  if (!session.user) return
  try {
    const data = await loadCheckoutData(session.user.id); addresses.value = data.addresses; zones.value = data.zones
    const requestedAddress = typeof router.currentRoute.value.query.address === 'string' ? router.currentRoute.value.query.address : ''
    selectedAddressId.value = requestedAddress && addresses.value.some((address) => address.id === requestedAddress) ? requestedAddress : (addresses.value[0]?.id || '')
    showAddressForm.value = false
    addressForm.zona_id = zones.value[0]?.id || ''
    refreshDeliveryEstimate(); refreshCapacity()
  } catch (loadError) { error.value = loadError.message || 'No se pudieron cargar tus datos de entrega.' }
}
async function addAddress() { error.value = ''; if (!addressForm.detalle.trim()) { error.value = 'Escribe una dirección.'; return } if (!addressForm.zona_id) { error.value = 'Selecciona una zona de entrega.'; return } try { const address = await saveAddress(session.user.id, addressForm); address.zonas = { nombre: zones.value.find((zone) => zone.id === addressForm.zona_id)?.nombre || '' }; addresses.value = [address, ...addresses.value]; selectedAddressId.value = address.id; showAddressForm.value = false; showAddressPicker.value = false } catch (saveError) { error.value = saveError.message || 'No se pudo guardar la dirección. Verifica que tu sesión sea de cliente.' } }
function openAddressPicker() { router.push({ name: 'address-select', query: { from: 'checkout' } }) }
function openAddressForm() { router.push({ name: 'address-new', query: { from: 'checkout' } }) }
function openLocationPicker() { showLocationPicker.value = true }
function confirmLocation(point) { addressForm.latitud = point.latitud; addressForm.longitud = point.longitud; showLocationPicker.value = false }
function selectAddress(id) { selectedAddressId.value = id; showAddressPicker.value = false; refreshDeliveryEstimate(); refreshCapacity() }
function cancelAddressAction() { showAddressPicker.value = false; showAddressForm.value = false }
function formatAddress(address) { return [address?.detalle, address?.referencia, address?.zonas?.nombre].filter(Boolean).join(' · ') }
function useExactCash() { cashAmount.value = exactCash.value ? total.value.toFixed(2) : '' }
function editCashAmount() { exactCash.value = false }
function persistPaymentPreference() { try { localStorage.setItem(SAVED_PAYMENT_KEY, JSON.stringify({ method: paymentMethod.value, cardIndex: selectedCardIndex.value })) } catch { /* El checkout continúa aunque el almacenamiento local falle. */ } }
function applyInitialPaymentOrder() { paymentOptions.value?.classList.toggle('last-payment-cash', initialPaymentMethod.value === 'cash') }
function focusFirstPaymentOption() { paymentOptions.value?.scrollTo({ left: 0, behavior: 'auto' }) }
function restorePaymentPreference() { try { const preference = JSON.parse(localStorage.getItem(SAVED_PAYMENT_KEY) || 'null'); initialPaymentMethod.value = preference?.method === 'card' && savedCards.value.length ? 'card' : 'cash'; if (initialPaymentMethod.value === 'card') { const index = Number.isInteger(preference.cardIndex) && savedCards.value[preference.cardIndex] ? preference.cardIndex : 0; initialCardIndex.value = index; selectSavedCard(index) } else selectPayment('cash'); window.setTimeout(() => { applyInitialPaymentOrder(); focusFirstPaymentOption() }, 0) } catch { /* Se mantiene efectivo como método predeterminado. */ } }
function selectPayment(method) { paymentMethod.value = method; showCashForm.value = false; persistPaymentPreference(); const container = paymentOptions.value; window.setTimeout(() => { const target = method === 'card' ? container?.querySelector('.first-payment-option') || container?.querySelector('.saved-payment-card--option') || container?.querySelector('.card-payment') : container?.querySelector('.cash-card'); if (container && target) container.scrollTo({ left: method === 'card' ? Math.max(0, target.offsetLeft - 18) : 0, behavior: 'smooth' }) }, 0) }
function openCashAmount() { selectPayment('cash'); showCashForm.value = true }
function selectSavedCard(index) { selectedCardIndex.value = index; editingCardIndex.value = index; savedCard.value = savedCards.value[index]; cardForm.number = savedCard.value.number; cardForm.name = savedCard.value.name; cardForm.expiry = savedCard.value.expiry; cardForm.cvv = savedCard.value.cvv || ''; selectPayment('card') }
function cardLastFour(card) { return card?.number?.replace(/\D/g, '').slice(-4) || '••••' }
function addAnotherCard() { editingCardIndex.value = -1; showCardForm.value = true; cardForm.number = ''; cardForm.name = ''; cardForm.expiry = ''; cardForm.cvv = ''; error.value = ''; selectPayment('card') }
function editSavedCard() { editingCardIndex.value = selectedCardIndex.value; showCardForm.value = true; error.value = '' }
function cancelCardEdit() { showCardForm.value = false; error.value = ''; if (savedCard.value) { cardForm.number = savedCard.value.number; cardForm.name = savedCard.value.name; cardForm.expiry = savedCard.value.expiry; cardForm.cvv = savedCard.value.cvv || '' } }
async function saveNewCard() { if (!/^\d{13,19}$/.test(cardNumberDigits.value) || cardForm.name.trim().length < 2 || !/^\d{4}$/.test(cardExpiryDigits.value)) { error.value = 'Completa los datos de la tarjeta para guardarla.'; return } const card = { number: cardForm.number, name: cardForm.name.trim(), expiry: cardForm.expiry, cvv: cardForm.cvv }; if (editingCardIndex.value >= 0) savedCards.value.splice(editingCardIndex.value, 1, card); else { savedCards.value = [...savedCards.value, card]; editingCardIndex.value = savedCards.value.length - 1 } selectedCardIndex.value = editingCardIndex.value; initialPaymentMethod.value = 'card'; initialCardIndex.value = editingCardIndex.value; savedCard.value = card; try { localStorage.setItem(SAVED_CARD_KEY, JSON.stringify(savedCards.value)) } catch { /* Las tarjetas permanecen disponibles durante la sesión. */ } showCardForm.value = false; error.value = ''; persistPaymentPreference(); await nextTick(); applyInitialPaymentOrder(); focusFirstPaymentOption() }
function deleteSavedCard() { const index = editingCardIndex.value; if (index < 0 || !savedCards.value[index]) return; savedCards.value.splice(index, 1); try { localStorage.setItem(SAVED_CARD_KEY, JSON.stringify(savedCards.value)) } catch { /* La eliminación permanece vigente durante la sesión. */ } showCardForm.value = false; editingCardIndex.value = -1; selectedCardIndex.value = -1; savedCard.value = null; cardForm.number = ''; cardForm.name = ''; cardForm.expiry = ''; cardForm.cvv = ''; if (savedCards.value.length) selectSavedCard(0); else selectPayment('cash') }
function formatCardNumber(event) { const digits = event.target.value.replace(/\D/g, '').slice(0, 16); cardForm.number = digits.replace(/(.{4})/g, '$1 ').trim() }
function formatCardExpiry(event) { const digits = event.target.value.replace(/\D/g, '').slice(0, 4); cardForm.expiry = digits.length > 2 ? `${digits.slice(0, 2)}/${digits.slice(2)}` : digits }
function formatCvv(event) { cardForm.cvv = event.target.value.replace(/\D/g, '').slice(0, 4) }
function createRequestId() {
  if (globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID()
  const bytes = new Uint8Array(16)
  if (globalThis.crypto?.getRandomValues) globalThis.crypto.getRandomValues(bytes)
  else for (let index = 0; index < bytes.length; index += 1) bytes[index] = Math.floor(Math.random() * 256)
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('')
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
}
function restoreCard() { try { const stored = JSON.parse(localStorage.getItem(SAVED_CARD_KEY) || 'null'); const cards = Array.isArray(stored) ? stored : stored?.number ? [stored] : []; savedCards.value = cards.filter((card) => card?.number && card?.name && card?.expiry); if (savedCards.value.length) { selectedCardIndex.value = 0; editingCardIndex.value = 0; savedCard.value = savedCards.value[0]; cardForm.number = savedCard.value.number; cardForm.name = savedCard.value.name; cardForm.expiry = savedCard.value.expiry; cardForm.cvv = savedCard.value.cvv || '' } else showCardForm.value = true } catch { localStorage.removeItem(SAVED_CARD_KEY); showCardForm.value = true } }
function persistCard() { if (selectedCardIndex.value < 0 || !savedCards.value[selectedCardIndex.value]) return; const card = { number: cardForm.number, name: cardForm.name, expiry: cardForm.expiry, cvv: cardForm.cvv }; savedCards.value.splice(selectedCardIndex.value, 1, card); savedCard.value = card; try { localStorage.setItem(SAVED_CARD_KEY, JSON.stringify(savedCards.value)) } catch { /* El checkout continúa aunque el almacenamiento local falle. */ } }
function modalKind(result) {
  if (!result) return 'error'
  if (result.motivo === 'SIN_REPARTIDORES') return 'unavailable'
  if (result.motivo === 'ZONA_BLOQUEADA' || result.motivo === 'CAPACIDAD_SUPERADA') return 'saturated'
  if (result.advertencia) return 'warning'
  return null
}
function openCapacityModal(kind) { capacityModalKind.value = kind; capacityModalOpen.value = true }
async function validateCapacityForConfirmation() {
  const result = await refreshCapacity()
  if (!result || capacityError.value || !result.puede_confirmar) { openCapacityModal(modalKind(result)); return null }
  if (result.advertencia) { openCapacityModal('warning'); return null }
  return result
}
async function continueAfterWarning() {
  capacityModalBusy.value = true
  const result = await refreshCapacity()
  capacityModalBusy.value = false
  if (!result || capacityError.value || !result.puede_confirmar) { capacityModalOpen.value = false; openCapacityModal(modalKind(result)); return }
  capacityModalOpen.value = false
  await createOrder()
}
async function createOrder() {
  paying.value = true; error.value = ''
  try {
    const result = await confirmOrder({
      solicitudId: createRequestId(),
      restaurantId: cart.restaurant.id,
      addressId: selectedAddress.value.id,
      items: cart.items,
      metodoPago: paymentMethod.value === 'card' ? 'TARJETA_SIMULADA' : 'EFECTIVO',
      montoEfectivo: paymentMethod.value === 'cash' ? Number(cashToPay.value) : null,
      cambioEstimado: paymentMethod.value === 'cash' ? change.value : null,
      instruccionesEntrega: instructions.value.trim() || null,
    })
    if (!result?.pedido_id) throw new Error(result?.codigo || 'El pedido no pudo registrarse.')
    const orderId = result.pedido_id
    cart.items = []; cart.restaurant = null
    router.replace({ name: 'order-confirmation', params: { id: orderId } })
  } catch (payError) {
    const message = payError.message || ''
    if (message.includes('CAPACIDAD_NO_DISPONIBLE')) {
      const result = await refreshCapacity()
      openCapacityModal(modalKind(result))
    } else error.value = message || 'No se pudo confirmar el pedido.'
  } finally { paying.value = false }
}
async function pay() {
  if (paying.value || !cart.items.length || !selectedAddress.value) return
  if (!paymentValid.value) { error.value = paymentMethod.value === 'card' ? (!/^\d{3,4}$/.test(cardForm.cvv) ? 'Ingresa el CVV de la tarjeta.' : 'Revisa los datos de la tarjeta antes de pagar.') : 'Ingresa un monto válido en efectivo.'; return }
  if (capacityLoading.value) return
  const result = await validateCapacityForConfirmation()
  if (result) await createOrder()
}
watch(() => [cardForm.number, cardForm.name, cardForm.expiry, cardForm.cvv], () => { if (!showCardForm.value) persistCard() })
watch(() => router.currentRoute.value.query.address, (addressId) => { if (typeof addressId === 'string' && addresses.value.some((address) => address.id === addressId)) { selectedAddressId.value = addressId; refreshDeliveryEstimate() } })
watch(() => [selectedAddressId.value, cart.restaurant?.id], () => { refreshDeliveryEstimate(); refreshCapacity() })
onMounted(() => { restoreCard(); restorePaymentPreference(); load(); capacityTimer = window.setInterval(refreshCapacity, 10000) })
onBeforeUnmount(() => window.clearInterval(capacityTimer))
</script>

<template>
  <main class="checkout-page"><header class="checkout-header"><button class="icon-button" aria-label="Regresar" @click="router.back()"><ArrowLeft :size="24" /></button><h1>Último paso</h1><span></span></header>
    <section class="checkout-content"><h2>¿Cómo quieres pagar?</h2><div ref="paymentOptions" class="payment-options"><button class="cash-card" :class="{ selected: paymentMethod === 'cash' }" @click="selectPayment('cash')"><Banknote :size="26" /><strong>Efectivo</strong><span role="button" tabindex="0" @click.stop="openCashAmount" @keydown.enter.stop="openCashAmount">Ingresar monto</span></button><template v-if="savedCards.length"><div v-for="(card, index) in savedCards" :key="`saved-card-${card.number}-${index}`" class="saved-payment-card saved-payment-card--option" :class="['saved-payment-card--color-' + (index % 4), { selected: paymentMethod === 'card' && selectedCardIndex === index, 'first-payment-option': initialPaymentMethod === 'card' && initialCardIndex === index }]" role="button" tabindex="0" @click="selectSavedCard(index)" @keydown.enter="selectSavedCard(index)"><button type="button" class="card-edit-button" aria-label="Editar tarjeta" @click.stop="selectSavedCard(index); editSavedCard()"><Pencil :size="16" /></button><div><strong>VISA</strong></div><p>•••• •••• •••• {{ cardLastFour(card) }}</p><footer><span>{{ card.name }}</span><span>{{ card.expiry }}</span></footer></div></template><button v-if="savedCards.length" type="button" class="cash-card add-card-option" @click="addAnotherCard"><CreditCard :size="23" /><strong>Agregar tarjeta</strong></button><button v-else class="cash-card card-payment" :class="{ selected: paymentMethod === 'card', 'first-payment-option': initialPaymentMethod === 'card' }" @click="selectPayment('card')"><CreditCard :size="26" /><strong>Tarjeta</strong></button></div><div v-if="paymentMethod === 'cash' && showCashForm" class="cash-form"><label>Paga con<input v-model="cashAmount" type="number" min="0" step="0.01" placeholder="0.00" @input="editCashAmount" /></label><label class="exact-check"><input v-model="exactCash" type="checkbox" @change="useExactCash" /> Pagar con el monto exacto</label><p>Cambio estimado: <b>${{ change.toFixed(2) }}</b></p></div><template v-if="paymentMethod === 'card'"><form v-if="showCardForm || !savedCard" class="card-form" @submit.prevent="saveNewCard"><div class="card-form-heading"><strong>{{ editingCardIndex >= 0 ? 'Editar tarjeta' : 'Agregar tarjeta' }}</strong><button type="button" aria-label="Cerrar formulario de tarjeta" @click="cancelCardEdit"><X :size="18" /></button></div><label>Número de tarjeta<input v-model="cardForm.number" inputmode="numeric" maxlength="19" @input="formatCardNumber" /></label><label>Nombre del titular<input v-model="cardForm.name" autocomplete="cc-name" /></label><div><label>Vencimiento<input v-model="cardForm.expiry" inputmode="numeric" maxlength="5" @input="formatCardExpiry" /></label><label class="cvv-field">CVV<div><input v-model="cardForm.cvv" :type="showCvv ? 'text' : 'password'" inputmode="numeric" maxlength="4" @input="formatCvv" /><button type="button" aria-label="Mostrar u ocultar CVV" @click="showCvv = !showCvv"> <EyeOff v-if="showCvv" :size="17" /><Eye v-else :size="17" /></button></div></label></div><button type="submit" class="save-card-button">Guardar tarjeta</button><button v-if="editingCardIndex >= 0" type="button" class="delete-card-button" @click="deleteSavedCard">Eliminar tarjeta</button><small>Los datos de la tarjeta se guardan localmente, excepto el CVV.</small></form><div v-else class="saved-card-cvv"><label>CVV<div><input v-model="cardForm.cvv" :type="showCvv ? 'text' : 'password'" inputmode="numeric" maxlength="4" @input="formatCvv" /><button type="button" aria-label="Mostrar u ocultar CVV" @click="showCvv = !showCvv"> <EyeOff v-if="showCvv" :size="17" /><Eye v-else :size="17" /></button></div></label></div></template>
      <h2>Datos de entrega</h2><div class="checkout-row"><Bike :size="24" /><div><strong>Delivery</strong><span>{{ deliveryLabel }}</span><LogisticsCapacityNotice :capacity="capacity" :estimate-label="deliveryLabel" /></div></div><div class="checkout-row"><MapPin :size="24" /><div><strong>Lo recibes en <button type="button" @click.prevent="addresses.length ? router.push({ name: 'address-select', query: { from: 'checkout' } }) : router.push({ name: 'address-new', query: { from: 'checkout' } })">{{ addresses.length ? 'Cambiar' : 'Agregar' }}</button></strong><span v-if="selectedAddress" class="selected-address">{{ formatAddress(selectedAddress) }}</span><span v-else>Agrega una dirección de entrega</span></div></div><div class="checkout-row"><Pencil :size="24" /><div><strong>Instrucciones de entrega <button type="button">Editar</button></strong><textarea v-model="instructions" placeholder="Ej. Casa de portón negro, llamar al llegar"></textarea></div></div>
      <form v-if="showAddressForm" class="address-form" @submit.prevent="addAddress"><h3>Agregar nueva dirección</h3><label>Alias<input v-model="addressForm.alias" placeholder="Casa, trabajo…" required /></label><label>Dirección<input v-model="addressForm.detalle" placeholder="Ej. Calle y número de casa" required /></label><label>Referencia<input v-model="addressForm.referencia" placeholder="Ej. Portón negro" /></label><label>Zona de entrega<select v-model="addressForm.zona_id" required><option value="" disabled>Selecciona una zona</option><option v-for="zone in zones" :key="zone.id" :value="zone.id">{{ zone.nombre }}</option></select></label><button type="button" class="location-select-button" @click="openLocationPicker">{{ addressForm.latitud ? 'Cambiar ubicación en el mapa' : 'Seleccionar ubicación en el mapa' }}</button><small v-if="addressForm.latitud">Ubicación seleccionada: {{ Number(addressForm.latitud).toFixed(6) }}, {{ Number(addressForm.longitud).toFixed(6) }}</small><div class="address-form-actions"><button type="submit"><Save :size="16" /> Guardar dirección</button><button type="button" class="address-cancel" @click="cancelAddressAction">Cancelar</button></div></form>
      <h2>Datos de facturación</h2><div class="billing-row"><span>Consumidor final</span><span>✓</span></div><h2>Resumen</h2><div class="summary-row"><span>Productos</span><b>${{ cart.subtotal.toFixed(2) }}</b></div><div class="summary-row"><span>Envío</span><b>${{ SHIPPING_FEE.toFixed(2) }}</b></div><div v-if="error" class="checkout-error">{{ error }}</div>
    </section><footer class="checkout-footer"><div><span>Total</span><strong>${{ total.toFixed(2) }}</strong></div><button class="logistics-check-button" :disabled="paying || capacityLoading || !selectedAddress || !cart.items.length" @click="pay">{{ paying ? 'Procesando…' : capacityLoading ? 'Validando…' : capacity?.puede_confirmar === false ? 'Revisar disponibilidad' : paymentMethod === 'cash' ? 'Confirmar pedido' : 'Ir a pagar' }}</button></footer>
  </main><DeliveryLocationPicker v-if="showLocationPicker" :latitud="addressForm.latitud" :longitud="addressForm.longitud" @cancel="showLocationPicker = false" @confirm="confirmLocation" /><LogisticsCapacityModal v-model="capacityModalOpen" :kind="capacityModalKind" :estimate-label="deliveryLabel" :busy="capacityModalBusy" @continue="continueAfterWarning" @close="capacityModalOpen = false" @back="router.push('/carrito')" />
</template>
