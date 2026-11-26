import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'

export const useSessionStore = defineStore('session', () => {
  const user = ref(null)
  const profile = ref(null)
  const loading = ref(true)
  const initialized = ref(false)
  const error = ref('')
  let authSubscription

  const isAuthenticated = computed(() => Boolean(user.value))
  const role = computed(() => profile.value?.rol ?? null)

  async function loadProfile(currentUser) {
    if (!currentUser) {
      profile.value = null
      return
    }
    const { data, error: profileError } = await supabase
      .from('perfiles')
      .select('id, nombre, telefono, rol, activo')
      .eq('id', currentUser.id)
      .maybeSingle()
    if (profileError) throw profileError
    profile.value = data
  }

  async function initialize() {
    if (initialized.value) return
    loading.value = true
    error.value = ''
    const { data, error: sessionError } = await supabase.auth.getSession()
    if (sessionError) error.value = sessionError.message
    user.value = data.session?.user ?? null
    try { await loadProfile(user.value) } catch (profileError) { error.value = profileError.message }

    const { data: listener } = supabase.auth.onAuthStateChange((event, session) => {
      user.value = session?.user ?? null
      if (!session) {
        profile.value = null
        loading.value = false
        return
      }
      setTimeout(async () => {
        try { await loadProfile(session.user) } catch (profileError) { error.value = profileError.message }
        finally { loading.value = false }
      }, 0)
    })
    authSubscription = listener.subscription
    initialized.value = true
    loading.value = false
  }

  async function signIn(email, password) {
    const result = await supabase.auth.signInWithPassword({ email, password })
    if (result.error) throw result.error
    return result.data
  }

  async function signUp({ nombre, telefono, email, password }) {
    const result = await supabase.auth.signUp({ email, password, options: { data: { nombre, telefono } } })
    if (result.error) throw result.error
    return result.data
  }

  async function signOut() {
    const { error: signOutError } = await supabase.auth.signOut()
    if (signOutError) throw signOutError
    user.value = null
    profile.value = null
  }

  async function refreshProfile() {
    await loadProfile(user.value)
  }

  function dispose() {
    authSubscription?.unsubscribe()
    authSubscription = undefined
  }

  return { user, profile, loading, initialized, error, isAuthenticated, role, initialize, refreshProfile, signIn, signUp, signOut, dispose }
})
