import { supabase } from '../lib/supabase'

export const SHIPPING_FEE = 0

export async function loadCheckoutData(userId) {
  const [{ data: addresses, error: addressesError }, { data: zones, error: zonesError }] = await Promise.all([
    supabase.from('direcciones').select('id, alias, detalle, referencia, zona_id, predeterminada, latitud, longitud, zonas(nombre)').eq('cliente_id', userId).order('predeterminada', { ascending: false }).order('created_at', { ascending: false }),
    supabase.from('zonas').select('id, nombre').eq('activa', true).order('nombre')
  ])
  if (addressesError) throw addressesError
  if (zonesError) throw zonesError
  return { addresses: addresses || [], zones: zones || [] }
}

export async function saveAddress(userId, form, options = {}) {
  const { data: authData, error: authError } = await supabase.auth.getUser()
  if (authError || !authData.user) throw new Error('Tu sesión expiró. Inicia sesión nuevamente.')
  if (authData.user.id !== userId) throw new Error('La dirección no corresponde al usuario autenticado.')
  const address = { cliente_id: authData.user.id, alias: form.alias || 'Casa', detalle: form.detalle.trim(), referencia: form.referencia?.trim() || null, zona_id: form.zona_id, predeterminada: Boolean(options.predeterminada), latitud: form.latitud ?? null, longitud: form.longitud ?? null }
  const { data, error } = await supabase.from('direcciones').insert(address).select('id, alias, detalle, referencia, zona_id, predeterminada, latitud, longitud').single()
  if (error) throw error
  return { ...data, zonas: { nombre: '' } }
}

export async function updateAddress(userId, id, form) {
  const { data: authData, error: authError } = await supabase.auth.getUser()
  if (authError || authData.user?.id !== userId) throw new Error('La dirección no corresponde al usuario autenticado.')
  const payload = { alias: form.alias || 'Casa', detalle: form.detalle.trim(), referencia: form.referencia?.trim() || null, zona_id: form.zona_id, latitud: form.latitud ?? null, longitud: form.longitud ?? null }
  const { data, error } = await supabase.from('direcciones').update(payload).eq('id', id).eq('cliente_id', userId).select('id, alias, detalle, referencia, zona_id, predeterminada, latitud, longitud').single()
  if (error) throw error
  return data
}

export async function getAddress(id, userId) {
  const { data, error } = await supabase.from('direcciones').select('id, alias, detalle, referencia, zona_id, predeterminada, latitud, longitud, zonas(nombre)').eq('id', id).eq('cliente_id', userId).maybeSingle()
  if (error) throw error
  return data
}

export async function confirmOrder({ solicitudId, restaurantId, addressId, items, metodoPago = 'EFECTIVO', montoEfectivo = null, cambioEstimado = null, instruccionesEntrega = null }) {
  const { data, error } = await supabase.rpc('confirmar_pedido', {
    p_solicitud_id: solicitudId,
    p_restaurante_id: restaurantId,
    p_direccion_id: addressId,
    p_items: items.map((item) => ({ producto_id: item.id, cantidad: item.quantity, opciones: [] })),
    p_metodo_pago: metodoPago,
    p_monto_efectivo: montoEfectivo,
    p_cambio_estimado: cambioEstimado,
    p_instrucciones_entrega: instruccionesEntrega,
  })
  if (error) throw error
  return data
}

export async function getOrder(id) {
  const { data, error } = await supabase.from('pedidos').select('id, numero, estado, estado_pago, metodo_pago, subtotal, costo_envio, total, eta_minutos, preparacion_minutos_estimados, preparacion_iniciada_en, preparacion_lista_estimada_en, preparacion_lista_en, confirmado_en, created_at, restaurantes(id, nombre, tipo_establecimiento, pos_x, pos_y), direcciones(detalle, referencia, latitud, longitud, zonas(nombre)), pedido_detalles(id, nombre_producto_snapshot, cantidad, precio_base_unitario, subtotal_linea), asignaciones(id, terminada_en, repartidores(id, perfil_id, pos_x, pos_y, perfiles(nombre))), cancelaciones(motivo_codigo, descripcion, origen, actor_id, created_at), reembolsos(id, monto, automatico, estado, revisado_por, created_at, updated_at)').eq('id', id).maybeSingle()
  if (error) throw error
  if (!data) return data
  const [{ data: cancellations, error: cancellationsError }, { data: refunds, error: refundsError }] = await Promise.all([
    supabase.from('cancelaciones').select('motivo_codigo, descripcion, origen, actor_id, created_at').eq('pedido_id', id).order('created_at', { ascending: false }),
    supabase.from('reembolsos').select('id, monto, automatico, estado, revisado_por, created_at, updated_at').eq('pedido_id', id).order('created_at', { ascending: false }),
  ])
  if (cancellationsError) throw cancellationsError
  if (refundsError) throw refundsError
  const { data: courierLocation } = await supabase.rpc('ubicacion_repartidor_pedido', { p_pedido_id: id })
  return { ...data, cancelaciones: cancellations || data.cancelaciones || [], reembolsos: refunds || data.reembolsos || [], repartidor_nombre: courierLocation?.nombre || null, repartidor_ubicacion: courierLocation ? { pos_x: courierLocation.pos_x, pos_y: courierLocation.pos_y, actualizada_en: courierLocation.actualizada_en } : null }
}

export async function cancelOrder(id, motivo, descripcion = null) {
  const { data, error } = await supabase.rpc('cancelar_pedido', { p_pedido_id: id, p_motivo: motivo, p_descripcion: descripcion })
  if (error) throw error
  return data
}
