import { supabase } from '../lib/supabase'

const orderSelect = 'id, numero, cliente_id, estado, estado_pago, metodo_pago, subtotal, costo_envio, total, direccion_snapshot, confirmado_en, created_at, preparacion_minutos_estimados, preparacion_iniciada_en, preparacion_lista_estimada_en, preparacion_lista_en, solicitud_repartidor_publicada, solicitud_repartidor_publicada_en, restaurantes(id, nombre), perfiles(nombre, telefono), pedido_detalles(id, nombre_producto_snapshot, cantidad, precio_base_unitario, precio_opciones_unitario, subtotal_linea, observaciones), asignaciones(id, terminada_en, repartidores(id, perfil_id, perfiles(nombre), zonas(nombre))), cancelaciones(motivo_codigo, descripcion, origen, created_at)'

export async function loadAdminOrders(status = '') {
  let query = supabase.from('pedidos').select(orderSelect).order('created_at', { ascending: false })
  if (status) query = query.eq('estado', status)
  const { data, error } = await query
  if (error) throw error
  return data || []
}

export async function loadAdminStats() {
  const [{ count: restaurants, error: restaurantsError }, { count: products, error: productsError }, { data: orders, error: ordersError }] = await Promise.all([
    supabase.from('restaurantes').select('id', { count: 'exact', head: true }).eq('activo', true),
    supabase.from('productos').select('id', { count: 'exact', head: true }).eq('disponible', true),
    supabase.from('pedidos').select('estado')
  ])
  const error = restaurantsError || productsError || ordersError
  if (error) throw error
  const byState = (state) => (orders || []).filter((order) => order.estado === state).length
  return { restaurants: restaurants || 0, products: products || 0, pending: byState('PENDIENTE'), preparing: byState('ASIGNADO'), onTheWay: byState('EN_CAMINO'), delivered: byState('ENTREGADO') }
}

export async function loadAdminCouriers() {
  const { data, error } = await supabase.from('repartidores').select('id, disponible, activo, zonas(nombre), perfiles(nombre, telefono), asignaciones(id, pedido_id, terminada_en, pedidos(numero, estado))').order('id')
  if (error) throw error
  return data || []
}

export async function updateOrderState(id, state) {
  const { data, error } = await supabase.rpc('actualizar_estado_pedido', { p_pedido_id: id, p_nuevo_estado: state })
  if (error) throw error
  return data
}
export async function acceptOrder(id, minutes) { const { data, error } = await supabase.rpc('aceptar_pedido', { p_pedido_id: id, p_preparacion_minutos: minutes }); if (error) throw error; return data }
export async function updatePreparationTime(id, minutes) { const { data, error } = await supabase.rpc('actualizar_tiempo_preparacion', { p_pedido_id: id, p_minutos_restantes: minutes }); if (error) throw error; return data }
export async function markOrderReady(id) { const { data, error } = await supabase.rpc('marcar_pedido_listo', { p_pedido_id: id }); if (error) throw error; return data }
export async function assignCourier(id) { const { data, error } = await supabase.rpc('asignar_repartidor_admin', { p_pedido_id: id }); if (error) throw error; return data }
export async function rejectOrder(id, description) { const { data, error } = await supabase.rpc('cancelar_pedido', { p_pedido_id: id, p_motivo: 'RESTAURANTE_RECHAZA', p_descripcion: description }); if (error) throw error; return data }
export async function cancelAdminOrder(id, motivo, descripcion = null) { const { data, error } = await supabase.rpc('cancelar_pedido', { p_pedido_id: id, p_motivo: motivo, p_descripcion: descripcion }); if (error) throw error; return data }
export async function publishCourierRequest(id) { const { data, error } = await supabase.rpc('solicitar_repartidor', { p_pedido_id: id }); if (error) throw error; return data }

export function subscribeToOrders(onChange) {
  const channel = supabase.channel(`admin-orders-${crypto.randomUUID()}`).on('postgres_changes', { event: '*', schema: 'public', table: 'pedidos' }, onChange).subscribe()
  return () => supabase.removeChannel(channel)
}
