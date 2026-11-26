import { createRouter, createWebHistory } from 'vue-router'
import { useSessionStore } from '../stores/session'

const routes = [
  { path: '/', name: 'home', component: () => import('../views/HomeView.vue') },
  { path: '/restaurantes', name: 'restaurants', component: () => import('../views/RestaurantsView.vue') },
  { path: '/restaurantes/:id', name: 'restaurant-detail', component: () => import('../views/RestaurantDetailView.vue') },
  { path: '/restaurantes/:restaurantId/productos/:productId', name: 'product-detail', component: () => import('../views/ProductDetailView.vue') },
  { path: '/carrito', name: 'cart', component: () => import('../views/CartView.vue') },
  { path: '/checkout', name: 'checkout', component: () => import('../views/CheckoutView.vue'), meta: { roles: ['CLIENTE'] } },
  { path: '/direcciones/seleccionar', name: 'address-select', component: () => import('../views/AddressSelectView.vue'), meta: { roles: ['CLIENTE'] } },
  { path: '/direcciones/nueva', name: 'address-new', component: () => import('../views/AddressLocationView.vue'), meta: { roles: ['CLIENTE'] } },
  { path: '/direcciones/editar/:id', name: 'address-edit', component: () => import('../views/AddressLocationView.vue'), meta: { roles: ['CLIENTE'] } },
  { path: '/direcciones/detalles', name: 'address-details', component: () => import('../views/AddressDetailsView.vue'), meta: { roles: ['CLIENTE'] } },
  { path: '/pedido/:id/confirmacion', name: 'order-confirmation', component: () => import('../views/OrderConfirmationView.vue'), meta: { roles: ['CLIENTE'] } },
  { path: '/login', name: 'login', component: () => import('../views/LoginView.vue'), meta: { guestOnly: true } },
  { path: '/registro', name: 'register', component: () => import('../views/RegisterView.vue'), meta: { guestOnly: true } },
  { path: '/cliente', name: 'client', component: () => import('../views/ClientOrdersView.vue'), meta: { roles: ['CLIENTE'] } },
  { path: '/perfil', name: 'profile', component: () => import('../views/ProfileView.vue') },
  { path: '/registro/repartidor', name: 'courier-registration', component: () => import('../views/CourierRegistrationView.vue') },
  { path: '/perfil/datos', name: 'profile-data', component: () => import('../views/ProfileDataView.vue'), meta: { roles: ['CLIENTE'] } },
  { path: '/perfil/ayuda', name: 'profile-help', component: () => import('../views/ProfileHelpView.vue'), meta: { roles: ['CLIENTE'] } },
  { path: '/repartidor', name: 'courier', component: () => import('../views/CourierDashboardView.vue'), meta: { roles: ['REPARTIDOR'] } },
  { path: '/admin', component: () => import('../views/AdminLayout.vue'), meta: { roles: ['ADMIN'] }, children: [
    { path: '', name: 'admin', component: () => import('../views/AdminDashboardView.vue') },
    { path: 'restaurantes', name: 'admin-restaurants', component: () => import('../views/AdminCatalogModuleView.vue'), props: { module: 'restaurants' } },
    { path: 'categorias', name: 'admin-categories', component: () => import('../views/AdminCatalogModuleView.vue'), props: { module: 'categories' } },
    { path: 'productos', name: 'admin-products', component: () => import('../views/AdminCatalogModuleView.vue'), props: { module: 'products' } },
    { path: 'pedidos', name: 'admin-orders', component: () => import('../views/AdminOrdersView.vue') },
    { path: 'repartidores', name: 'admin-couriers', component: () => import('../views/AdminCouriersView.vue') }
    ,{ path: 'logistica', name: 'admin-logistics', component: () => import('../views/AdminLogisticsView.vue') }
    ,{ path: 'cancelaciones-reembolsos', name: 'admin-refunds', component: () => import('../views/AdminRefundsView.vue') }
  ] },
  { path: '/:pathMatch(.*)*', redirect: '/' }
]

const router = createRouter({ history: createWebHistory(), routes })

router.beforeEach(async (to) => {
  const session = useSessionStore()
  await session.initialize()
  if (session.isAuthenticated && !session.profile) {
    try { await session.refreshProfile() } catch { return { name: 'home', replace: true } }
  }
  if (to.meta.guestOnly && session.isAuthenticated) return { name: homeForRole(session.role), replace: true }
  if (to.meta.roles) {
    if (!session.isAuthenticated) {
      sessionStorage.setItem('pedidosya-pending-redirect', to.fullPath)
      return { name: 'login', query: { redirect: to.fullPath } }
    }
    if (!session.profile?.activo || !to.meta.roles.includes(session.role)) return { name: homeForRole(session.role), replace: true }
  }
})

function homeForRole(role) { return { ADMIN: 'admin', REPARTIDOR: 'courier', CLIENTE: 'client' }[role] || 'home' }

export default router
