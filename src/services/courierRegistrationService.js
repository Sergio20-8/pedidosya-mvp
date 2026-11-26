import { supabase } from '../lib/supabase'

const select = 'id, perfil_id, zona_id, tipo_vehiculo, estado, motivo_rechazo, solicitada_en, revisada_en, revisado_por, zonas(nombre), perfiles!solicitudes_repartidor_perfil_id_fkey(nombre, telefono)'

export async function listActiveZones() { const { data, error } = await supabase.from('zonas').select('id, nombre').eq('activa', true).order('nombre'); if (error) throw error; return data || [] }
export async function getMyCourierRequest(userId) { const { data, error } = await supabase.from('solicitudes_repartidor').select(select).eq('perfil_id', userId).maybeSingle(); if (error) throw error; return data }
export async function submitCourierRequest(zoneId, vehicle) { const { data, error } = await supabase.rpc('enviar_solicitud_repartidor', { p_zona_id: zoneId, p_tipo_vehiculo: vehicle }); if (error) throw error; return data }
export async function listCourierApplications(status = '') { let query = supabase.from('solicitudes_repartidor').select(select).order('solicitada_en', { ascending: false }); if (status) query = query.eq('estado', status); const { data, error } = await query; if (error) throw error; return data || [] }
export async function approveCourierApplication(id) { const { data, error } = await supabase.rpc('aprobar_solicitud_repartidor', { p_solicitud_id: id }); if (error) throw error; return data }
export async function rejectCourierApplication(id, reason) { const { data, error } = await supabase.rpc('rechazar_solicitud_repartidor', { p_solicitud_id: id, p_motivo: reason }); if (error) throw error; return data }
