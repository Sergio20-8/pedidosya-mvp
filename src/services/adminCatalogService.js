import { supabase } from '../lib/supabase'

export async function loadAdminCatalog(establishmentType = null) {
  const [{ data: restaurants, error: restaurantsError }, { data: categories, error: categoriesError }, { data: products, error: productsError }, { data: zones, error: zonesError }] = await Promise.all([
    (establishmentType ? supabase.from('restaurantes').select('id, zona_id, nombre, tipo_establecimiento, tipo_comida, descripcion, imagen_url, banner_url, tiempo_preparacion_min, calificacion, cantidad_resenas, pos_x, pos_y, activo, zonas(nombre)').eq('tipo_establecimiento', establishmentType) : supabase.from('restaurantes').select('id, zona_id, nombre, tipo_establecimiento, tipo_comida, descripcion, imagen_url, banner_url, tiempo_preparacion_min, calificacion, cantidad_resenas, pos_x, pos_y, activo, zonas(nombre)')).order('nombre'),
    supabase.from('categorias').select('id, restaurante_id, nombre, orden, activa, restaurantes(nombre)').order('orden').order('nombre'),
    supabase.from('productos').select('id, restaurante_id, categoria_id, nombre, descripcion, precio, imagen_url, disponible, restaurantes(nombre), categorias(nombre)').order('nombre'),
    supabase.from('zonas').select('id, nombre').eq('activa', true).order('nombre')
  ])
  const error = restaurantsError || categoriesError || productsError || zonesError
  if (error) throw error
  return { restaurants: restaurants || [], categories: categories || [], products: products || [], zones: zones || [] }
}

export async function saveRestaurant(form, id = null) {
  const payload = { zona_id: form.zona_id, nombre: form.nombre, tipo_establecimiento: form.tipo_establecimiento || 'RESTAURANTE', tipo_comida: form.tipo_comida, descripcion: form.descripcion || null, imagen_url: form.imagen_url || null, banner_url: form.banner_url || null, tiempo_preparacion_min: Number(form.tiempo_preparacion_min), calificacion: Number(form.calificacion), cantidad_resenas: Number(form.cantidad_resenas), pos_x: form.pos_x == null || form.pos_x === '' ? null : Number(form.pos_x), pos_y: form.pos_y == null || form.pos_y === '' ? null : Number(form.pos_y), activo: Boolean(form.activo) }
  const query = id ? supabase.from('restaurantes').update(payload).eq('id', id) : supabase.from('restaurantes').insert(payload)
  const { error } = await query
  if (error) throw error
}

export async function saveCategory(form, id = null) {
  const payload = { restaurante_id: form.restaurante_id, nombre: form.nombre, orden: Number(form.orden), activa: Boolean(form.activa) }
  const query = id ? supabase.from('categorias').update(payload).eq('id', id) : supabase.from('categorias').insert(payload)
  const { error } = await query
  if (error) throw error
}

export async function saveProduct(form, id = null) {
  const payload = { restaurante_id: form.restaurante_id, categoria_id: form.categoria_id, nombre: form.nombre, descripcion: form.descripcion || null, precio: Number(form.precio), imagen_url: form.imagen_url || null, disponible: Boolean(form.disponible) }
  const query = id ? supabase.from('productos').update(payload).eq('id', id) : supabase.from('productos').insert(payload)
  const { error } = await query
  if (error) throw error
}
