<script setup>
import { onMounted, reactive, ref } from 'vue'
import { ArrowLeft, Check, Pencil } from 'lucide-vue-next'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useSessionStore } from '../stores/session'

const router = useRouter()
const session = useSessionStore()
const loading = ref(true)
const editing = ref(false)
const saving = ref(false)
const error = ref('')
const notice = ref('')
const form = reactive({ nombre: '', telefono: '' })

async function load() {
  await session.initialize()
  if (session.profile) {
    form.nombre = session.profile.nombre || ''
    form.telefono = session.profile.telefono || ''
  }
  loading.value = false
}

async function save() {
  error.value = ''; notice.value = ''
  if (!form.nombre.trim()) { error.value = 'El nombre es obligatorio.'; return }
  saving.value = true
  try {
    const { error: saveError } = await supabase.from('perfiles').update({ nombre: form.nombre.trim(), telefono: form.telefono.trim() || null }).eq('id', session.user.id)
    if (saveError) throw saveError
    await session.refreshProfile()
    form.nombre = session.profile.nombre || ''
    form.telefono = session.profile.telefono || ''
    editing.value = false
    notice.value = 'Tus datos se actualizaron correctamente.'
  } catch (e) { error.value = e.message || 'No se pudieron guardar tus datos.' } finally { saving.value = false }
}

onMounted(load)
</script>

<template>
  <main class="profile-page profile-subpage">
    <header class="profile-header"><button @click="router.back"><ArrowLeft :size="22" /></button><h1>Datos personales</h1><span /></header>
    <section v-if="loading" class="profile-empty">Cargando datos…</section>
    <section v-else class="profile-data-panel">
      <div class="profile-data-heading"><div><span class="profile-eyebrow">MI CUENTA</span><h2>Información personal</h2><p>Administra los datos que utilizamos para tu cuenta.</p></div><button v-if="!editing" class="profile-edit-button" @click="editing = true"><Pencil :size="17" /> Editar</button></div>
      <div v-if="!editing" class="profile-data-list"><div><span>Nombre</span><strong>{{ session.profile?.nombre || 'Sin registrar' }}</strong></div><div><span>Teléfono</span><strong>{{ session.profile?.telefono || 'Sin registrar' }}</strong></div><div><span>Correo electrónico</span><strong>{{ session.user?.email }}</strong><small>El correo se gestiona desde el inicio de sesión.</small></div></div>
      <form v-else class="profile-edit" @submit.prevent="save"><label>Nombre<input v-model="form.nombre" autocomplete="name" required /></label><label>Teléfono<input v-model="form.telefono" autocomplete="tel" inputmode="tel" /></label><p v-if="error" class="profile-error">{{ error }}</p><div class="profile-form-actions"><button type="button" class="profile-secondary" @click="editing = false">Cancelar</button><button class="profile-primary" :disabled="saving"><Check :size="17" /> {{ saving ? 'Guardando…' : 'Guardar cambios' }}</button></div></form>
      <p v-if="notice" class="profile-success">{{ notice }}</p>
    </section>
  </main>
</template>
