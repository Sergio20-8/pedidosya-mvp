<script setup>
import { computed, ref } from 'vue'
import { BarChart3, ClipboardList, Menu, Package, Store, Tags, Truck, X, LogOut, SlidersHorizontal, ReceiptText } from 'lucide-vue-next'
import { RouterLink, RouterView, useRoute, useRouter } from 'vue-router'
import { useSessionStore } from '../stores/session'
const route = useRoute(); const router = useRouter(); const session = useSessionStore(); const open = ref(false)
const links = [{ to: '/admin', label: 'Dashboard', icon: BarChart3 }, { to: '/admin/restaurantes', label: 'Restaurantes', icon: Store }, { to: '/admin/categorias', label: 'Categorías', icon: Tags }, { to: '/admin/productos', label: 'Productos', icon: Package }, { to: '/admin/pedidos', label: 'Pedidos', icon: ClipboardList }, { to: '/admin/repartidores', label: 'Repartidores', icon: Truck }, { to: '/admin/logistica', label: 'Control logístico', icon: SlidersHorizontal }, { to: '/admin/logistica?tab=analysis', label: 'Análisis de demanda', icon: BarChart3 }, { to: '/admin/cancelaciones-reembolsos', label: 'Cancelaciones y reembolsos', icon: ReceiptText }]
const section = computed(() => links.find((link) => link.to === route.path)?.label || 'Administración')
async function logout() { await session.signOut(); router.replace('/') }
</script>
<template>
  <div class="admin-shell">
    <aside class="admin-sidebar" :class="{ 'is-open': open }"><div class="admin-brand"><img src="/logos/logo.png" alt="PedidosYa" /><strong>Operaciones</strong><button class="admin-close" @click="open = false"><X :size="20" /></button></div><nav><RouterLink v-for="link in links" :key="link.to" :to="link.to" :class="{ active: route.path === link.to.split('?')[0] && (link.to.includes('?tab=analysis') ? route.query.tab === 'analysis' : !route.query.tab) }" @click="open = false"><component :is="link.icon" :size="19" /><span>{{ link.label }}</span></RouterLink></nav><button class="admin-logout" @click="logout"><LogOut :size="18" /> Cerrar sesión</button></aside>
    <div v-if="open" class="admin-backdrop" @click="open = false" />
    <div class="admin-main"><header class="admin-topbar"><button class="admin-menu" @click="open = true"><Menu :size="22" /></button><div><span>Panel administrativo</span><h1>{{ section }}</h1></div><button class="admin-avatar" aria-label="Perfil">{{ session.profile?.nombre?.slice(0, 1) || 'A' }}</button></header><main class="admin-page-content"><RouterView /></main></div>
  </div>
</template>
