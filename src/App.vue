<script setup>
import { onMounted, ref } from 'vue'

const SPLASH_SESSION_KEY = 'pedidosya-splash-shown'
const showSplash = ref(false)
const leavingSplash = ref(false)

onMounted(() => {
  try {
    if (sessionStorage.getItem(SPLASH_SESSION_KEY)) return
    sessionStorage.setItem(SPLASH_SESSION_KEY, '1')
  } catch {
    // Si el navegador bloquea sessionStorage, se conserva el comportamiento inicial.
  }
  showSplash.value = true
  window.setTimeout(() => {
    leavingSplash.value = true
    window.setTimeout(() => { showSplash.value = false }, 450)
  }, 1500)
})
</script>

<template>
  <Transition name="splash-fade">
    <div v-if="showSplash" class="splash-screen" :class="{ 'splash-screen--leaving': leavingSplash }" aria-label="Cargando PedidosYa">
      <span class="splash-logo-wrap">
        <img src="/logos/logo blanco.png" alt="PedidosYa" class="splash-logo" />
      </span>
    </div>
  </Transition>
  <RouterView v-show="!showSplash" />
</template>
