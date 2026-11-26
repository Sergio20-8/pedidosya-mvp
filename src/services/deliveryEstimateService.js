import { getDrivingRoute } from './routeService'

const routeCache = new Map()
const pendingRoutes = new Map()

function coordinate(value) {
  const number = Number(value)
  return Number.isFinite(number) ? number : null
}

function points(restaurant, address) {
  const restaurantPoint = [coordinate(restaurant?.pos_y), coordinate(restaurant?.pos_x)]
  const addressPoint = [coordinate(address?.latitud), coordinate(address?.longitud)]
  if (restaurantPoint.some((value) => value == null) || addressPoint.some((value) => value == null)) return null
  return { restaurantPoint, addressPoint }
}

async function getCachedRoute(origin, destination) {
  const key = `${origin.join(',')};${destination.join(',')}`
  if (routeCache.has(key)) return routeCache.get(key)
  if (!pendingRoutes.has(key)) {
    pendingRoutes.set(key, getDrivingRoute(origin, destination).then((route) => {
      routeCache.set(key, route)
      return route
    }).finally(() => pendingRoutes.delete(key)))
  }
  return pendingRoutes.get(key)
}

export async function calculateDeliveryEstimate({ restaurant, address }) {
  const routePoints = points(restaurant, address)
  if (!routePoints) return null
  const route = await getCachedRoute(routePoints.restaurantPoint, routePoints.addressPoint)
  const preparation = Math.max(0, Number(restaurant?.tiempo_preparacion_min) || 0)
  const travel = Math.max(0, Math.ceil(Number(route?.duration || 0) / 60))
  const pickup = 5
  const estimated = preparation + travel + pickup
  return { min: Math.max(0, estimated - 5), max: estimated + 5, estimated, travel, preparation, pickup }
}

export function formatDeliveryEstimate(estimate) {
  return estimate ? `${estimate.min}–${estimate.max} min` : ''
}
