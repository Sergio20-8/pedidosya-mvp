import { supabase } from '../lib/supabase'
export async function getCourierProfile(userId) { const { data, error } = await supabase.from('repartidores').select('id, perfil_id, zona_id, disponible, activo, zonas(nombre)').eq('perfil_id', userId).maybeSingle(); if (error) throw error; return data }
export async function listCourierRequests() { const { data, error } = await supabase.from('pedidos').select('id, numero, estado, zona_id, subtotal, costo_envio, total, created_at, direccion_snapshot, restaurantes(id, nombre, pos_x, pos_y, zonas(nombre)), pedido_detalles(id, cantidad, nombre_producto_snapshot, precio_base_unitario, subtotal_linea, productos(imagen_url)), direcciones(detalle, referencia, latitud, longitud, zonas(nombre))').eq('estado', 'LISTO_PARA_RECOGER').eq('solicitud_repartidor_publicada', true).order('solicitud_repartidor_publicada_en', { ascending: false }); if (error) throw error; return (data || []).map((item) => ({ ...item, restaurantes: item.restaurantes ? { ...item.restaurantes, __destination: item.direcciones } : item.restaurantes, direcciones: item.direcciones ? { ...item.direcciones, zonas: { ...(item.direcciones.zonas || {}), nombre: item.direcciones.detalle || item.direcciones.zonas?.nombre } } : item.direcciones })) }
export async function toggleCourierAvailability(value) { const { data, error } = await supabase.rpc('cambiar_disponibilidad_repartidor', { p_disponible: value }); if (error) throw error; return data }
export async function acceptCourierRequest(id, location) { const { data, error } = await supabase.rpc('aceptar_entrega_repartidor', { p_pedido_id: id, p_pos_x: Number(location.longitud), p_pos_y: Number(location.latitud) }); if (error) throw error; return data }
export async function listCourierAssignedOrders(courierId) {
  const { data, error } = await supabase.from('asignaciones').select('pedido_id, ubicacion_pos_x, ubicacion_pos_y, ubicacion_actualizada_en, repartidores(pos_x, pos_y), pedidos(id, numero, estado, direccion_snapshot, restaurantes(id, nombre, pos_x, pos_y), direcciones(detalle, referencia, latitud, longitud, zonas(nombre)), pedido_detalles(id, cantidad, nombre_producto_snapshot, observaciones, productos(imagen_url)))').eq('repartidor_id', courierId).is('terminada_en', null).order('asignada_en', { ascending: false })
  if (error) throw error
  return Promise.all((data || []).filter((item) => item.pedidos).map(async (item) => {
    const order = { ...item.pedidos, repartidor_ubicacion: { pos_x: item.ubicacion_pos_x ?? item.repartidores?.pos_x, pos_y: item.ubicacion_pos_y ?? item.repartidores?.pos_y, actualizada_en: item.ubicacion_actualizada_en } }
    if (!order.direcciones?.latitud || !order.direcciones?.longitud) {
      const { data: destination, error: destinationError } = await supabase.rpc('destino_entrega_repartidor', { p_pedido_id: order.id })
      if (!destinationError && destination?.[0]) order.direcciones = { ...destination[0], zonas: { nombre: destination[0].zona_nombre } }
    }
    return order
  }))
}
export async function updateCourierLocation(id, location) { const { data, error } = await supabase.rpc('actualizar_ubicacion_entrega', { p_pedido_id: id, p_pos_x: Number(location.longitud), p_pos_y: Number(location.latitud) }); if (error) throw error; return data }
export async function updateCourierOrderState(id, state) {
  const { data, error } = await supabase.rpc('actualizar_estado_pedido', { p_pedido_id: id, p_nuevo_estado: state })
  if (error) throw error
  if (data?.estado && data.estado !== state) throw new Error(`La entrega no cambió de estado. Estado actual: ${data.estado}.`)
  return data
}
export async function listCourierHistory(courierId, filter = 'ALL') { let query = supabase.from('asignaciones').select('pedido_id, asignada_en, terminada_en, pedidos(id, numero, estado, direccion_snapshot, created_at, restaurantes(id, nombre, pos_x, pos_y), direcciones(detalle, referencia, latitud, longitud, zonas(nombre)))').eq('repartidor_id', courierId).not('terminada_en', 'is', null).order('terminada_en', { ascending: false }); if (filter === 'TODAY') query = query.gte('terminada_en', new Date(new Date().setHours(0, 0, 0, 0)).toISOString()); if (filter === 'WEEK') query = query.gte('terminada_en', new Date(Date.now() - 7 * 86400000).toISOString()); const { data, error } = await query; if (error) throw error; return (data || []).map((item) => ({ ...item.pedidos, asignada_en: item.asignada_en, terminada_en: item.terminada_en })).filter(Boolean) }
export function subscribeCourierRequests(onChange, onStatus) {
  let channel
  let stopped = false
  let reconnectTimer
  const connect = () => {
    if (stopped) return
    channel = supabase.channel(`courier-requests-${crypto.randomUUID()}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'pedidos' }, onChange)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'pedidos' }, onChange)
      .subscribe((status) => {
        onStatus?.(status)
        if (status === 'SUBSCRIBED') window.setTimeout(onChange, 250)
        if ((status === 'TIMED_OUT' || status === 'CHANNEL_ERROR' || status === 'CLOSED') && !stopped) {
          clearTimeout(reconnectTimer)
          reconnectTimer = window.setTimeout(connect, 1500)
        }
      })
  }
  connect()
  return () => { stopped = true; clearTimeout(reconnectTimer); if (channel) supabase.removeChannel(channel) }
}
