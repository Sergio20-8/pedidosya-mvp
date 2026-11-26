import { supabase } from '../lib/supabase'

export async function listClientOrders(userId) {
  const { data, error } = await supabase.from('pedidos').select('id, numero, estado, estado_pago, metodo_pago, total, created_at, restaurantes(id, nombre, tipo_establecimiento, imagen_url), direcciones(detalle, zonas(nombre)), pedido_detalles(id, cantidad, nombre_producto_snapshot, productos(imagen_url)), cancelaciones(motivo_codigo, descripcion, created_at), reembolsos(id, monto, automatico, estado, created_at, updated_at)').eq('cliente_id', userId).order('created_at', { ascending: false })
  if (error) throw error
  return data || []
}
