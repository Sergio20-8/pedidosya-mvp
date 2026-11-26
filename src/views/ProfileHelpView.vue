<script setup>
import { ArrowLeft, CircleHelp } from 'lucide-vue-next'
import { useRouter } from 'vue-router'
const router = useRouter()
</script>
<template><main class="profile-page profile-subpage"><header class="profile-header"><button @click="router.back"><ArrowLeft :size="22" /></button><h1>Ayuda y soporte</h1><span /></header><section class="profile-help-panel"><span class="profile-help-icon"><CircleHelp :size="28" /></span><h2>¿En qué podemos ayudarte?</h2><p>Consulta tus pedidos desde la sección de pedidos. Para actualizar una ubicación, abre Mis direcciones.</p><div class="profile-help-item"><strong>Seguimiento del pedido</strong><span>El estado se actualiza con los cambios reales registrados en Supabase.</span></div><div class="profile-help-item"><strong>Direcciones</strong><span>Puedes agregar, editar o cancelar una dirección desde Mis direcciones.</span></div></section></main></template>
