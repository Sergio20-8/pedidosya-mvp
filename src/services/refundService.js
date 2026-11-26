import { supabase } from '../lib/supabase'

const cancellationSelect = 'id, pedido_id, motivo_codigo, descripcion, origen, actor_id, actor:perfiles!cancelaciones_actor_id_fkey(nombre), created_at, pedidos(id, numero, cliente_id, estado, estado_pago, metodo_pago, total, restaurantes(nombre), perfiles(nombre), reembolsos(id, monto, automatico, estado, revisado_por, created_at, updated_at))'
const refundSelect = 'id, pedido_id, cancelacion_id, motivo_codigo, monto, automatico, estado, revisado_por, revisor:perfiles!reembolsos_revisado_por_fkey(nombre), created_at, updated_at, pedidos(numero, cliente_id, estado_pago, metodo_pago, total, restaurantes(nombre), perfiles(nombre))'

export async function listAdminCancellations() {
  const { data, error } = await supabase.from('cancelaciones').select(cancellationSelect).order('created_at', { ascending: false })
  if (error) throw error
  return data || []
}

export async function listAdminRefunds() {
  const { data, error } = await supabase.from('reembolsos').select(refundSelect).order('created_at', { ascending: false })
  if (error) throw error
  return data || []
}

export async function resolveRefund(id, approve) {
  const { data, error } = await supabase.rpc('resolver_reembolso', { p_reembolso_id: id, p_aprobar: approve })
  if (error) throw error
  return data
}
