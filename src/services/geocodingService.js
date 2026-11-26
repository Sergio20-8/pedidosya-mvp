const cache = new Map()
export function normalizeReverseGeocode(data) {
  const address = data?.address || {}
  const city = address.city || address.town || address.village || address.municipality || address.county || ''
  const locality = address.suburb || address.neighbourhood || address.quarter || address.city_district || ''
  const street = [address.road, address.house_number].filter(Boolean).join(' ')
  return { detalle: street || data?.display_name?.split(',').slice(0, 2).join(',').trim() || '', localidad: locality, ciudad: city, departamento: address.state || '', pais: address.country || '', display: [street, locality, city].filter(Boolean).join(', ') || data?.display_name || '' }
}
export async function reverseGeocode(lat, lon) {
  const key = `${Number(lat).toFixed(5)},${Number(lon).toFixed(5)}`
  if (cache.has(key)) return cache.get(key)
  const response = await fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&addressdetails=1&lat=${encodeURIComponent(lat)}&lon=${encodeURIComponent(lon)}`, { headers: { Accept: 'application/json' } })
  if (!response.ok) throw new Error('No pudimos identificar la dirección. Puedes completar los detalles manualmente.')
  const result = normalizeReverseGeocode(await response.json()); cache.set(key, result); return result
}
