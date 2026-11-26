import { supabase } from '../lib/supabase'

export async function getLogisticsConfig() {
  const { data, error } = await supabase.from('configuracion_logistica').select('id, umbral_advertencia, capacidad_maxima, umbral_reactivacion, updated_by, updated_at').eq('id', true).single()
  if (error) throw error
  return data
}

export async function updateLogisticsConfig(form) {
  const { data, error } = await supabase.rpc('actualizar_configuracion_logistica', {
    p_umbral_advertencia: Number(form.umbral_advertencia),
    p_capacidad_maxima: Number(form.capacidad_maxima),
    p_umbral_reactivacion: Number(form.umbral_reactivacion)
  })
  if (error) throw error
  return data
}

export async function getCheckoutCapacity(restaurantId, addressId) {
  const { data, error } = await supabase.rpc('consultar_capacidad_checkout', { p_restaurante_id: restaurantId, p_direccion_id: addressId })
  if (error) throw error
  return data?.[0] || null
}

export async function getLogisticsMonitoring() {
  const [{ data: zones, error: zonesError }, config] = await Promise.all([
    supabase.from('zonas').select('id, nombre, activa, bloqueada, updated_at').order('nombre'),
    getLogisticsConfig()
  ])
  if (zonesError) throw zonesError
  const rows = await Promise.all((zones || []).map(async (zone) => {
    const { data, error } = await supabase.rpc('capacidad_zona', { p_zona_id: zone.id, p_incremento: 1 })
    if (error) throw error
    return { ...zone, ...(data?.[0] || {}) }
  }))
  return { config, zones: rows }
}

export async function getCapacityHistory(filters = {}) {
  let query = supabase.from('eventos_capacidad_zona').select('id, zona_id, estado_anterior, estado_nuevo, activos, disponibles, ratio, motivo, created_at, zonas(nombre)').order('created_at', { ascending: false })
  if (filters.zoneId) query = query.eq('zona_id', filters.zoneId)
  if (filters.type === 'BLOQUEO') query = query.eq('estado_nuevo', true)
  if (filters.type === 'REACTIVACION') query = query.eq('estado_nuevo', false)
  const { data, error } = await query
  if (error) throw error
  return data || []
}

export async function getDemandAnalysis(zoneId = null) {
  const { data, error } = await supabase.rpc('analizar_demanda_historica', { p_zona_id: zoneId || null, p_dias: 90 })
  if (error) throw error
  return data || null
}
