<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useSessionStore } from '../stores/session'
const session = useSessionStore(); const router = useRouter()
const title = computed(() => ({ CLIENTE: 'Área de cliente', REPARTIDOR: 'Área de repartidor', ADMIN: 'Panel administrativo' }[session.role] || 'Área privada'))
async function logout() { await session.signOut(); router.replace('/') }
</script>

<template>
  <main class="page centered"><section class="card hero-card">
    <p class="eyebrow">Sesión activa</p><h1>{{ title }}</h1><p class="muted">Hola, {{ session.profile?.nombre || session.user?.email }}.</p>
    <p class="role-badge">Rol verificado: {{ session.role }}</p><button class="secondary" @click="logout">Cerrar sesión</button>
  </section></main>
</template>
