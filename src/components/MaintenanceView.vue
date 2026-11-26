<script setup>
import { ArrowLeft, Construction } from 'lucide-vue-next'
import { useRouter } from 'vue-router'

defineProps({ section: { type: String, required: true } })
const router = useRouter()
</script>

<template>
  <main class="maintenance-page">
    <header class="maintenance-header"><button class="icon-button" aria-label="Regresar" @click="router.back()"><ArrowLeft :size="26" /></button><strong>{{ section }}</strong><span /></header>
    <section class="maintenance-content"><div class="maintenance-icon"><Construction :size="42" /></div><h1>Estamos trabajando en ello</h1><p>La sección {{ section.toLowerCase() }} se encuentra temporalmente en mantenimiento. Muy pronto estará disponible.</p><button class="admin-primary-button" @click="router.push('/')">Volver al inicio</button></section>
  </main>
</template>
