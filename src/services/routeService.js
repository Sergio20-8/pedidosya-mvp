const OSRM_URL = 'https://router.project-osrm.org/route/v1/driving'

export async function getDrivingRoute(origin, destination) {
  if (!origin || !destination) return null
  const response = await fetch(`${OSRM_URL}/${origin[1]},${origin[0]};${destination[1]},${destination[0]}?overview=false&geometries=geojson`)
  if (!response.ok) throw new Error('No se pudo calcular la ruta')
  const route = (await response.json()).routes?.[0]
  if (!route) throw new Error('No se encontró una ruta')
  return { distance: route.distance, duration: route.duration }
}
