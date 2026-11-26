import { supabase } from '../lib/supabase'
import { images } from '../constants/images'

function normalize(value) { return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim() }
function distance(a, b) { const row = Array.from({ length: b.length + 1 }, (_, index) => index); for (let i = 1; i <= a.length; i += 1) { let previous = row[0]; row[0] = i; for (let j = 1; j <= b.length; j += 1) { const current = row[j]; row[j] = Math.min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] === b[j - 1] ? 0 : 1)); previous = current } } return row[b.length] }
function matches(value, query) { const text = normalize(value); const term = normalize(query); if (!term || text.includes(term)) return true; return term.split(/\s+/).every((part) => text.split(/\s+/).some((word) => distance(part, word) <= (part.length <= 4 ? 1 : Math.max(1, Math.floor(part.length * 0.3))))) }

export async function searchProducts(query = '', category = '') {
  const { data, error } = await supabase.from('productos').select('id, restaurante_id, categoria_id, nombre, descripcion, precio, imagen_url, disponible, categorias(id, nombre), restaurantes(id, nombre, tipo_establecimiento, activo, imagen_url, banner_url)').eq('disponible', true).eq('restaurantes.activo', true).order('nombre')
  if (error) throw error
  const term = String(query || '').trim()
  const categoryTerm = String(category || '').trim()
  if (!term && !categoryTerm) return []
  return (data || []).filter((product) => {
    const categoryName = product.categorias?.nombre || ''
    const matchesCategory = !categoryTerm || matches(categoryName, categoryTerm) || normalize(categoryName).includes(normalize(categoryTerm)) || normalize(categoryTerm).includes(normalize(categoryName))
    const matchesText = !term || matches(`${product.nombre} ${product.descripcion || ''} ${categoryName}`, term)
    return matchesCategory && matchesText
  }).map((product) => ({ ...product, image: product.imagen_url || images.productoDefault, restaurantImage: product.restaurantes?.imagen_url || product.restaurantes?.banner_url || images.productoDefault }))
}
