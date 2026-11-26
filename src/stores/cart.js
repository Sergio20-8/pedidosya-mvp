import { computed, ref, watch } from 'vue'
import { defineStore } from 'pinia'

export const useCartStore = defineStore('cart', () => {
  const items = ref([])
  const restaurant = ref(null)

  try {
    const saved = JSON.parse(localStorage.getItem('pedidosya-cart') || 'null')
    if (saved) {
      items.value = saved.items || []
      restaurant.value = saved.restaurant || null
    }
  } catch { /* El carrito comienza vacío si el almacenamiento no es válido. */ }

  const count = computed(() => items.value.reduce((total, item) => total + item.quantity, 0))
  const subtotal = computed(() => items.value.reduce((total, item) => total + Number(item.precio) * item.quantity, 0))

  watch([items, restaurant], () => {
    localStorage.setItem('pedidosya-cart', JSON.stringify({ items: items.value, restaurant: restaurant.value }))
  }, { deep: true })

  function addItem(product, selectedRestaurant, quantity = 1) {
    if (restaurant.value && restaurant.value.id !== selectedRestaurant.id) {
      items.value = []
    }
    restaurant.value = { id: selectedRestaurant.id, nombre: selectedRestaurant.nombre, image: selectedRestaurant.image || selectedRestaurant.imagen_url || '', tiempo_preparacion_min: selectedRestaurant.tiempo_preparacion_min }
    const existing = items.value.find((item) => item.id === product.id)
    if (existing) existing.quantity += quantity
    else items.value.push({ ...product, quantity })
  }

  function updateQuantity(id, amount) {
    const item = items.value.find((entry) => entry.id === id)
    if (!item) return
    item.quantity = Math.max(0, item.quantity + amount)
    if (!item.quantity) removeItem(id)
  }

  function removeItem(id) {
    items.value = items.value.filter((item) => item.id !== id)
    if (!items.value.length) restaurant.value = null
  }

  return { items, restaurant, count, subtotal, addItem, updateQuantity, removeItem }
})
