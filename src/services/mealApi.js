const MEAL_DB_URL = 'https://www.themealdb.com/api/json/v1/1'
const cache = new Map()

const searchTerms = {
  hamburguesas: 'burger',
  pizza: 'pizza',
  pastas: 'pasta',
  pollo: 'chicken',
  mexicana: 'tacos',
  asiatica: 'sushi',
  postres: 'cake',
  'comida tipica': 'chicken',
  'comida mexicana': 'tacos',
  'comida asiatica': 'sushi',
  combos: 'burger',
  bebidas: 'cocktail'
}

function normalize(value = '') {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
}

function mealDescription(meal) {
  const text = meal?.strInstructions?.replace(/\s+/g, ' ').trim()
  if (!text) return null
  return text.length > 150 ? `${text.slice(0, 147)}…` : text
}

function restaurantSearchTerm(restaurant) {
  const text = normalize(`${restaurant.nombre} ${restaurant.descripcion || ''}`)
  if (text.includes('pizza')) return 'pizza'
  if (text.includes('burger') || text.includes('hamburg')) return 'burger'
  if (text.includes('pasta')) return 'pasta'
  if (text.includes('pollo') || text.includes('chicken')) return 'chicken'
  if (text.includes('taco') || text.includes('mexic')) return 'tacos'
  if (text.includes('asia') || text.includes('wok') || text.includes('ramen')) return 'sushi'
  if (text.includes('dulce') || text.includes('postre') || text.includes('cafe')) return 'cake'
  return 'chicken'
}

export async function getApiMenuForRestaurant(restaurant, priceRows) {
  const meals = await findMealsForCategory(restaurantSearchTerm(restaurant))
  if (!meals.length || !priceRows.length) return []
  return meals.slice(0, priceRows.length).map((meal, index) => ({
    id: priceRows[index].id,
    restaurante_id: restaurant.id,
    categoria_id: null,
    nombre: meal.strMeal,
    descripcion: mealDescription(meal) || `Plato internacional de ${meal.strArea || 'la casa'}.`,
    precio: priceRows[index].precio,
    imagen_url: meal.strMealThumb,
    disponible: true,
    categorias: { id: null, nombre: meal.strCategory || 'Menú', orden: index },
    meal_source: meal.strMeal
  }))
}

export async function findMealsForCategory(categoryName) {
  const key = normalize(categoryName)
  if (cache.has(key)) return cache.get(key)
  const term = searchTerms[key] || key
  try {
    const response = await fetch(`${MEAL_DB_URL}/search.php?s=${encodeURIComponent(term)}`)
    if (!response.ok) throw new Error(`TheMealDB respondió ${response.status}`)
    const payload = await response.json()
    const meals = payload.meals || []
    cache.set(key, meals)
    return meals
  } catch {
    cache.set(key, [])
    return []
  }
}

export async function enrichProductImages(products) {
  const getCategoryName = (product) => product.categorias?.nombre || product.categoria?.nombre
  const getSearchTerm = (product) => {
    const category = normalize(getCategoryName(product))
    const name = normalize(product.nombre)
    if (category === 'bebidas') return name.includes('cafe') ? 'coffee' : name.includes('chocolate') ? 'chocolate' : null
    if (name.includes('pasta') || name.includes('spaghetti') || name.includes('fettuccine') || name.includes('lasagna')) return 'pasta'
    if (name.includes('pollo') || name.includes('alitas')) return 'chicken'
    if (name.includes('taco') || name.includes('burrito') || name.includes('quesadilla')) return 'tacos'
    if (name.includes('wok') || name.includes('ramen') || name.includes('gyoza')) return 'sushi'
    if (category === 'postres') return 'cake'
    return searchTerms[category] || category
  }
  const terms = [...new Set(products.map(getSearchTerm).filter(Boolean))]
  const mealsByTerm = new Map()
  await Promise.all(terms.map(async (term) => mealsByTerm.set(term, await findMealsForCategory(term))))
  const counters = new Map()
  return products.map((product) => {
    if (product.imagen_url) return product
    const term = getSearchTerm(product)
    const meals = term ? mealsByTerm.get(term) || [] : []
    const index = counters.get(term) || 0
    counters.set(term, index + 1)
    const meal = meals[index % (meals.length || 1)]
    return {
      ...product,
      nombre: meal?.strMeal || product.nombre,
      descripcion: mealDescription(meal) || product.descripcion,
      imagen_url: meal?.strMealThumb || null,
      meal_source: meal?.strMeal || null
    }
  })
}
