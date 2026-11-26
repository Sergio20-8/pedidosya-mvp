import { supabase } from '../lib/supabase'
import { images } from '../constants/images'

function fallbackRestaurantImage(restaurant) {
  const name = `${restaurant.nombre} ${restaurant.descripcion || ''}`.toLowerCase()
  if (name.includes('pizza')) return images.bannerPrincipal
  if (name.includes('burger') || name.includes('hamburg')) return images.restaurantes
  if (name.includes('postre')) return images.cafe
  return images.bannerPizza
}

function fallbackProductImage(product) {
  const category = `${product.categorias?.nombre || ''}`.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
  const name = `${product.nombre || ''}`.toLowerCase()
  if (category === 'bebidas') return name.includes('cafe') ? images.cafe : images.bebidas
  if (category === 'postres') return images.postreDefault
  if (category.includes('pizza')) return images.bannerPrincipal
  if (category.includes('hamburg')) return images.restaurantes
  if (category.includes('pasta')) return images.bannerLasana
  return images.productoDefault
}

export async function listRestaurants(tipoEstablecimiento = 'RESTAURANTE') {
  let query = supabase
    .from('restaurantes')
    .select('id, nombre, tipo_establecimiento, tipo_comida, descripcion, imagen_url, banner_url, tiempo_preparacion_min, calificacion, cantidad_resenas, zona_id, pos_x, pos_y, zonas(nombre)')
    .eq('activo', true)
  if (tipoEstablecimiento && tipoEstablecimiento !== 'TODOS') query = query.eq('tipo_establecimiento', tipoEstablecimiento)
  const { data: restaurants, error } = await query.order('nombre')
  if (error) throw error

  const ids = (restaurants || []).map((restaurant) => restaurant.id)
  const { data: products, error: productsError } = ids.length
    ? await supabase.from('productos').select('id, restaurante_id, categoria_id, nombre, disponible, categorias(nombre)').in('restaurante_id', ids)
    : { data: [], error: null }
  if (productsError) throw productsError

  return (restaurants || []).map((restaurant) => {
    const restaurantProducts = (products || []).filter((product) => product.restaurante_id === restaurant.id && product.disponible)
    const categories = [...new Set(restaurantProducts.map((product) => product.categorias?.nombre).filter(Boolean))]
    return { ...restaurant, image: restaurant.imagen_url || fallbackRestaurantImage(restaurant), categories, productNames: restaurantProducts.map((product) => product.nombre).filter(Boolean), productCount: restaurantProducts.length }
  })
}

export async function getRestaurantDetail(id) {
  const [{ data: restaurant, error }, { data: products, error: productsError }] = await Promise.all([
    supabase.from('restaurantes').select('id, nombre, tipo_establecimiento, tipo_comida, descripcion, imagen_url, banner_url, tiempo_preparacion_min, calificacion, cantidad_resenas, zona_id, pos_x, pos_y, zonas(nombre)').eq('id', id).eq('activo', true).maybeSingle(),
    supabase.from('productos').select('id, restaurante_id, categoria_id, nombre, descripcion, precio, imagen_url, disponible, categorias(id, nombre, orden)').eq('restaurante_id', id).eq('disponible', true).order('nombre')
  ])
  if (error) throw error
  if (productsError) throw productsError
  if (!restaurant) return null
  return { ...restaurant, image: restaurant.imagen_url || fallbackRestaurantImage(restaurant), products: (products || []).map((product) => ({ ...product, imagen_url: product.imagen_url || fallbackProductImage(product) })) }
}
