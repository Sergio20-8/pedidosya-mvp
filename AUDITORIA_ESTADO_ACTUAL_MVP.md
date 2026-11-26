# Auditoría técnica y funcional del MVP PedidosYa

Fecha de auditoría: 2026-11-24  
Alcance: inspección estática del repositorio, migraciones SQL, frontend y servicios. No se modificó código de aplicación ni se ejecutaron migraciones durante esta auditoría.

## Resumen ejecutivo

El proyecto es una PWA Vue 3 con Pinia, Vue Router, Supabase y Leaflet. El backend de negocio está concentrado en PostgreSQL/Supabase: las mutaciones principales se realizan mediante RPC `security definer`, con RLS y funciones de autorización por rol.

El MVP tiene una base funcional amplia para cliente, repartidor y administrador: catálogo, carrito, checkout, pedidos, asignación, seguimiento, disponibilidad, cancelaciones simuladas, reembolsos simulados, capacidad por zona, escenarios demo y Realtime. La principal limitación es que varias capacidades académicas avanzadas todavía son MVP o simulación: pagos, predicción de demanda, ETA de transporte persistente, monitoreo avanzado, reasignación automática y algunas interfaces administrativas.

La migración `202611240001_preparation_estimates.sql` existe localmente y fue aplicada previamente al proyecto remoto `pedidosya-mvp` mediante `supabase db push --remote --include-all --yes`; esa aplicación fue verificada por la salida exitosa de la CLI. El resto de la auditoría distingue evidencia local de evidencia remota.

## 1. Arquitectura actual

### Stack y versiones

- Vue `^3.5.x` vía `vue` en `package.json`.
- Vite `^7.x` y `@vitejs/plugin-vue`.
- Vue Router `^4.x`.
- Pinia `^3.x`.
- Supabase JS `latest`.
- Leaflet `^1.9.4` para mapas.
- Lucide Vue Next `latest` para iconos.
- Tailwind CSS `3.4.17`, aunque la mayor parte de la UI utiliza CSS propio.
- `vite-plugin-pwa` para manifest, service worker y actualización automática.
- Fuente Nunito Sans mediante `@fontsource-variable/nunito-sans`.

No existe un backend Node separado en el repositorio. La lógica backend está en Supabase/PostgreSQL, especialmente en las migraciones SQL y RPC.

### Estructura

- `src/views/`: pantallas de cliente, repartidor y administración.
- `src/components/`: mapas, tracking, bottom sheet, selector de ubicación y componentes de fases.
- `src/services/`: acceso a Supabase, RPC, catálogo, pedidos, repartidores, geocodificación y APIs externas.
- `src/stores/`: sesión y carrito Pinia.
- `src/router/index.js`: rutas y guardas por rol.
- `src/assets/`: CSS modular por funcionalidad.
- `src/lib/supabase.js`: cliente Supabase.
- `src/constants/`: imágenes y constantes visuales.
- `supabase/migrations/`: esquema, RLS, RPC, Realtime y evoluciones funcionales.
- `supabase/seed/`: catálogo y datos demo.
- `public/`: logos y recursos públicos.

### Comunicación frontend-Supabase

El frontend usa `createClient` de `@supabase/supabase-js` con `VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY`. Las consultas de lectura usan `.from(...).select(...)`; las mutaciones de negocio usan `.rpc(...)`. El frontend no contiene una API propia.

Realtime se implementa con canales Supabase `postgres_changes`, principalmente sobre `pedidos`, `asignaciones`, `notificaciones` y `repartidores`.

### PWA

`vite.config.js` configura `VitePWA` con:

- `registerType: 'autoUpdate'`.
- Manifest con nombre `PedidosYa MVP`.
- `display: standalone`.
- idioma español.
- colores de tema y fondo.

El build genera `dist/sw.js`, `dist/registerSW.js` y el manifest.

## 2. Base de datos

### Tablas y propósito

| Tabla | Propósito |
|---|---|
| `perfiles` | Usuario de aplicación, nombre, teléfono, rol y activo. Relacionada con `auth.users`. |
| `zonas` | Áreas operativas, activa/bloqueada y fecha de bloqueo. |
| `categorias` | Categorías de catálogo. |
| `restaurantes` | Locales, zona, imágenes, preparación base y coordenadas `pos_x/pos_y`. |
| `direcciones` | Direcciones del cliente, zona, coordenadas y predeterminada. |
| `productos` | Productos, precio, disponibilidad y categoría. |
| `grupos_opciones` | Grupos de personalización de productos. |
| `opciones_producto` | Opciones y recargos. |
| `promociones` | Banners/descuentos con ventana temporal. |
| `repartidores` | Perfil operativo, zona, disponibilidad, ubicación, activo y demo. |
| `pedidos` | Cabecera del pedido, cliente, restaurante, estado, totales, ETA y timestamps. |
| `pedido_detalles` | Snapshot de líneas, cantidades, precio y opciones. |
| `asignaciones` | Relación pedido-repartidor, carga previa, distancia simulada y ciclo de asignación. Tiene índice único para asignación vigente. |
| `eventos_pedido` | Auditoría de cambios de estado y acciones. |
| `cancelaciones` | Causa, origen, actor y fecha. Una por pedido. |
| `reembolsos` | Reembolso simulado/manual, monto, estado y responsable. Uno por pedido/cancelación. |
| `notificaciones` | Mensajes por usuario y pedido. |
| `escenarios_demo` | Configuración de escenarios operativos. |
| `ejecuciones_demo` | Historial de ejecución de escenarios. |
| `solicitudes_repartidor` | Solicitudes para convertirse en repartidor. Añadida en `202611220005`. |

### Campos relevantes de `pedidos`

Incluye `estado`, `subtotal`, `descuento`, `costo_envio`, `total`, `eta_minutos`, `confirmado_en`, `finalizado_en`, `solicitud_repartidor_publicada` y timestamps.

La migración de preparación añade:

- `preparacion_minutos_estimados`.
- `preparacion_iniciada_en`.
- `preparacion_lista_estimada_en`.
- `preparacion_lista_en`.

### Estados

La evolución `202611220003_restaurant_acceptance_flow.sql` amplía el check para incluir:

`PENDIENTE_ACEPTACION`, `PREPARANDO`, `LISTO_PARA_RECOGER`, `PENDIENTE`, `ASIGNADO`, `RECOGIDO`, `EN_CAMINO`, `ENTREGADO`, `CANCELADO`.

La tabla original fue creada con un conjunto menor y luego modificada por migración.

### RPC principales

- `mi_rol`, `es_admin`, `es_repartidor`.
- `capacidad_zona`.
- `actualizar_bloqueo_zona`.
- `seleccionar_zona_repartidor`.
- `cambiar_disponibilidad_repartidor`.
- `confirmar_pedido`.
- `aceptar_pedido`.
- `actualizar_tiempo_preparacion`.
- `marcar_pedido_listo`.
- `solicitar_repartidor`.
- `aceptar_entrega_repartidor`.
- `actualizar_estado_pedido`.
- `actualizar_ubicacion_entrega`.
- `ubicacion_repartidor_pedido`.
- `cancelar_pedido`.
- `resolver_reembolso`.
- `ejecutar_escenario_demo` y `restablecer_escenario_demo`.

Las RPC de negocio usan `security definer`, validan rol/estado y registran eventos o notificaciones según el caso.

### Triggers, índices y restricciones

Existe trigger `set_updated_at` sobre perfiles, direcciones, restaurantes, productos, repartidores, pedidos y reembolsos. Hay índices para pedidos por cliente/zona/restaurante, detalles, asignaciones vigentes, eventos y notificaciones.

Restricciones relevantes:

- Totales no negativos y consistencia `total = subtotal - descuento + costo_envio`.
- Detalle igual a cantidad por precio base/opciones.
- Una dirección predeterminada por cliente.
- Una asignación vigente por pedido.
- Opciones y descuentos dentro de límites.
- Coordenadas de direcciones dentro de rangos geográficos.

### RLS y permisos

RLS está habilitado en todas las tablas principales. Los usuarios pueden consultar sus propios perfiles, direcciones y pedidos; administradores tienen acceso operativo; repartidores acceden a pedidos asignados y solicitudes visibles según políticas adicionales.

El proyecto revoca privilegios generales y concede permisos mínimos. Las mutaciones críticas no se ofrecen como INSERT/DELETE directo, sino mediante RPC.

### Migraciones

Migraciones locales identificadas: esquema base, autorización/RLS, funciones de negocio, Realtime, catálogo administrativo, tipo de restaurante, checkout, corrección RLS, coordenadas, flujo de aceptación, solicitudes de repartidor, registro de repartidor, detalles/coordenadas de solicitudes, ubicación activa y preparación.

Evidencia remota:

- La migración `202611240001_preparation_estimates.sql` fue aplicada al proyecto remoto con salida exitosa de `supabase db push`.
- No se realizó una auditoría completa de cada versión remota mediante `migration list` porque la consulta quedó sin respuesta en el entorno; por tanto, la correspondencia completa local/remota no está verificada aquí.

## 3. Funcionalidades por rol

### CLIENTE

Pantallas y capacidades implementadas:

- Inicio y catálogo: `HomeView.vue`, `RestaurantsView.vue`, `RestaurantDetailView.vue`.
- Productos y carrito: `ProductDetailView.vue`, `CartView.vue`, `stores/cart.js`.
- Checkout: `CheckoutView.vue` y `orderService.js`.
- Direcciones: `AddressSelectView.vue`, `AddressLocationView.vue`, `AddressDetailsView.vue`.
- Historial de pedidos: `ClientOrdersView.vue`.
- Seguimiento: `OrderConfirmationView.vue`, `OrderTrackingSheet.vue`, `OrderProgressSegments.vue`, `CourierRequestMap.vue`.
- Perfil, datos y ayuda: `ProfileView.vue`, `ProfileDataView.vue`, `ProfileHelpView.vue`.
- Registro para repartidor: `CourierRegistrationView.vue`.

El cliente puede consultar catálogo, agregar líneas/opciones, seleccionar dirección, confirmar pedido, consultar su pedido y cancelar en estados autorizados. El pago es simulado: no hay integración de gateway.

Limitaciones:

- Promociones en navegación tienen elementos visuales sin flujo completo.
- Algunas tarjetas de inicio son UI sin acción.
- El seguimiento combina rutas reales de OSRM con fases de negocio; no existe un ETA persistido de transporte en Supabase.

### REPARTIDOR

Pantalla principal: `CourierDashboardView.vue` y componentes de entrega/mapa.

Capacidades:

- Consultar solicitudes publicadas.
- Aceptar solicitud con ubicación inicial.
- Ver entregas activas e historial.
- Cambiar disponibilidad.
- Actualizar ubicación manualmente.
- Avanzar `ASIGNADO → RECOGIDO → EN_CAMINO → ENTREGADO`.
- Ver rutas, productos, dirección y navegación externa.
- Cambiar a vista normal de cliente sin cambiar el rol.
- Descartar solicitudes localmente mediante `localStorage`.

Limitaciones:

- El descarte es solo visual/local; no existe estado de rechazo de solicitud persistido.
- Parte de la vista de entregas activas fue agregada mediante manipulación DOM y tiene mayor complejidad de mantenimiento que un componente Vue nativo.
- No hay reasignación automática de una entrega abandonada o fallida.

### ADMINISTRADOR

Pantallas: `AdminLayout.vue`, dashboard, pedidos, catálogo y repartidores.

Capacidades:

- Consultar estadísticas básicas y pedidos.
- Aceptar/rechazar pedidos.
- Establecer y actualizar tiempo de preparación mediante RPC.
- Marcar pedido listo.
- Solicitar repartidor.
- Cambiar estados operativos.
- Administrar restaurantes, categorías y productos.
- Consultar repartidores.
- Ejecutar lógica demo a nivel SQL, aunque no se identificó una pantalla completa para todos los escenarios.

Limitaciones:

- Gestión completa de usuarios no está expuesta como módulo dedicado.
- La selección de tiempo de preparación se presenta actualmente mediante un popup DOM generado desde `AdminOrdersView.vue`, no como componente Vue reutilizable.
- No hay dashboard de demanda histórica/predicción.
- Monitoreo de capacidad existe principalmente en RPC/estadísticas, no como panel operativo completo.

## 4. Ciclo de vida del pedido

1. El cliente consulta catálogo y restaurantes.
2. El carrito Pinia conserva productos y cantidades.
3. Checkout carga direcciones y zonas.
4. `confirmar_pedido` valida cliente, dirección, restaurante, zona, productos, opciones y capacidad.
5. El pedido se crea como `PENDIENTE_ACEPTACION` en el flujo posterior de aceptación.
6. Admin acepta con minutos de preparación: `aceptar_pedido(uuid, integer)` cambia a `PREPARANDO`, registra inicio/fecha estimada, evento y notificación.
7. Admin puede actualizar el tiempo con `actualizar_tiempo_preparacion`.
8. Admin marca `LISTO_PARA_RECOGER`.
9. Admin publica solicitud de repartidor con `solicitar_repartidor`.
10. Repartidor acepta con ubicación y el pedido pasa a `ASIGNADO`.
11. Repartidor confirma recogida: `ASIGNADO → RECOGIDO`.
12. Repartidor inicia entrega: `RECOGIDO → EN_CAMINO`.
13. Repartidor marca entregado: `EN_CAMINO → ENTREGADO`.
14. Cancelación usa `cancelar_pedido`, registra causa, termina asignación y crea reembolso simulado.

Las transiciones principales se validan en SQL, especialmente `actualizar_estado_pedido`, RPC de aceptación, RPC de publicación y RPC de cancelación.

## 5. Gestión de repartidores y capacidad

### Disponibilidad y zona

`repartidores.disponible` y `repartidores.zona_id` determinan elegibilidad. `seleccionar_zona_repartidor` impide cambiar zona con asignaciones activas. `cambiar_disponibilidad_repartidor(false)` impide desactivarse con asignaciones vigentes.

### Capacidad

`capacidad_zona` cuenta como activos los pedidos en:

`PENDIENTE`, `ASIGNADO`, `RECOGIDO`, `EN_CAMINO`.

Cuenta repartidores disponibles, activos, con perfil activo y rol `REPARTIDOR` en la zona.

Fórmula:

`ratio = activos / disponibles`

Reglas:

- Advertencia si `ratio > 4` y `ratio <= 5`.
- Bloqueo si no hay disponibles.
- Bloqueo si `(activos + incremento) / disponibles > 5`.
- Recuperación automática cuando el ratio baja de `4`.

### Asignación

La asignación automática de `confirmar_pedido` y los flujos posteriores prioriza repartidores de la zona, activos, disponibles y con perfil válido. El orden utiliza carga activa y luego distancia simulada/identificador según la función concreta.

La asignación administrativa en `asignar_repartidor_admin` ordena por cantidad de asignaciones activas y `id`; calcula `distancia_simulada` con distancia euclidiana entre coordenadas, no distancia vial OSRM.

### Concurrencia y liberación

Las RPC usan `for update`, índices únicos para asignación vigente y manejo de `unique_violation` en aceptación. Al entregar o cancelar, se cierra `asignaciones.terminada_en` y se actualiza el bloqueo de zona.

### Limitaciones

- No hay reasignación automática.
- No hay cola operativa avanzada.
- La distancia de asignación es simulada/euclidiana.
- La capacidad no considera tiempos de preparación ni duración real de rutas.
- La selección automática completa depende del flujo RPC exacto; no hay pruebas automatizadas de concurrencia incluidas en el repositorio.

## 6. Geolocalización y tiempos

- Cliente: direcciones con `latitud`/`longitud`, capturadas por `DeliveryLocationPicker.vue` y geocodificación en `geocodingService.js`.
- Restaurante: `pos_x`/`pos_y`.
- Repartidor: `repartidores.pos_x`/`pos_y`, además de ubicación vigente de `asignaciones`.
- Mapas: Leaflet y tiles Esri/OpenStreetMap según componente.
- Rutas: OSRM público (`router.project-osrm.org`) en `CourierRequestMap.vue` y reutilización parcial en `routeService.js`.
- Tiempo de preparación: persistido en timestamps de `pedidos` desde la migración `202611240001`.
- ETA de transporte: se calcula en frontend con duración OSRM y margen visual; no se persiste cada segundo.
- `ASIGNADO`: frontend suma repartidor-restaurante y restaurante-cliente.
- `RECOGIDO`/`EN_CAMINO`: frontend calcula repartidor-cliente.
- El rango de entrega usa la zona `America/El_Salvador` y margen de cinco minutos.

Cuando OSRM falla, el mapa muestra puntos disponibles y el texto de error. El seguimiento no tiene una ruta alternativa propia.

## 7. Cancelaciones y reembolsos

`cancelar_pedido` permite cancelación por admin o cliente en estados definidos. Admin puede cancelar; cliente está limitado a estados tempranos (`PENDIENTE`, `ASIGNADO`). Estados `ENTREGADO` y `CANCELADO` son idempotentes.

La RPC registra:

- `cancelaciones`: motivo, descripción, origen, actor y fecha.
- `reembolsos`: monto total, código, automático/manual y estado.
- `eventos_pedido` y notificación al cliente.

`SIN_REPARTIDORES_EN_AREA` produce `SIMULADO_COMPLETADO`; otras causas producen `REVISION_MANUAL`. `resolver_reembolso` solo procesa `REVISION_MANUAL`, evitando doble resolución.

No hay integración de dinero real. Los reembolsos son simulados.

## 8. Tiempo real

### Suscripciones

- Cliente: canal por `pedidos.id` y `asignaciones.pedido_id` en `OrderConfirmationView.vue`.
- Admin: cambios globales en `pedidos` desde `AdminOrdersView.vue` y dashboard.
- Repartidor: INSERT/UPDATE de `pedidos` para solicitudes.
- Base: publicación Realtime habilitada para `pedidos`, `asignaciones`, `notificaciones` y `repartidores`.

La pantalla cliente recarga el pedido completo después de eventos para incorporar relaciones, ubicación y estado. Se marca desconexión del canal, pero la estrategia de reconexión explícita es limitada a la gestión del canal Supabase.

Las notificaciones se almacenan en tabla y se consultan por RLS, pero no existe un centro de notificaciones frontend completo.

## 9. Panel administrativo

Implementado:

- Dashboard con conteos básicos.
- Bandeja de pedidos, filtros y drawer de detalle.
- Aceptar/rechazar, marcar listo, solicitar repartidor y transiciones.
- Catálogo de restaurantes, categorías y productos.
- Consulta de repartidores y solicitudes.
- RPC de escenarios demo disponible en backend.

Parcial o ausente:

- Gestión administrativa general de usuarios: no hay CRUD dedicado.
- Capacidad: existe backend, no un monitor de ratios completo.
- Cancelaciones/reembolsos: lógica SQL existe, la UI administrativa no expone un flujo amplio de revisión.
- Auditoría: eventos SQL existen, no hay visor dedicado.
- Demanda histórica/predicción: no implementada.
- Simulador: funciones SQL existen; no se verificó una UI completa para operar todos los escenarios.

## 10. Seguridad y no funcionales

Fortalezas:

- Auth Supabase.
- Guardas de rutas por roles.
- RLS habilitado y políticas por propietario/operación.
- RPC `security definer` para mutaciones.
- Validación de estados y constraints SQL.
- Locks `for update` en operaciones críticas.
- No se encontraron secretos expuestos en el contenido auditado; las variables sensibles no se copiaron.
- Diseño responsive y PWA móvil.

Limitaciones:

- Se usa OSRM público sin garantía SLA ni autenticación.
- Algunas acciones UI se crean con manipulación DOM en vez de componentes Vue.
- No hay suite de tests automatizados en `package.json`.
- No hay evidencia de pruebas E2E, carga o concurrencia automatizadas.
- Los datos de ubicación se exponen a roles operativos autorizados, pero no existe política de retención/anominización documentada.
- La clave publishable debe permanecer limitada al cliente; las migraciones requieren CLI/rol administrativo.
- Parte del contenido visual todavía es placeholder o simulación.
- No hay gateway de pago ni protección antifraude.

## 11. Inventario general

| ID | Módulo | Funcionalidad | Estado | Implementación real o simulada | Evidencia en código | Observaciones |
|---|---|---|---|---|---|---|
| F-001 | Auth | Login/logout/registro | IMPLEMENTADO | Real | `src/stores/session.js`, `LoginView.vue`, `RegisterView.vue` | Supabase Auth. |
| F-002 | Auth | Protección por rol | IMPLEMENTADO | Real | `src/router/index.js` | Guardas CLIENTE/REPARTIDOR/ADMIN. |
| F-003 | Cliente | Catálogo/restaurantes | IMPLEMENTADO | Real | `RestaurantsView.vue`, `restaurantService.js` | Lecturas Supabase. |
| F-004 | Cliente | Imágenes/enriquecimiento | PARCIAL | Externa/demo | `mealApi.js` | Usa TheMealDB como complemento; puede alterar nombre/imagen. |
| F-005 | Cliente | Carrito | IMPLEMENTADO | Real en frontend | `stores/cart.js`, `CartView.vue` | Persistencia de sesión local según store. |
| F-006 | Cliente | Checkout/dirección | IMPLEMENTADO | Real | `CheckoutView.vue`, `orderService.js` | Pago no real. |
| F-007 | Cliente | Pago | SOLO_UI | Simulado | `CheckoutView.vue` | No gateway ni captura financiera. |
| F-008 | Cliente | Confirmar pedido | IMPLEMENTADO | RPC real | `confirmar_pedido` | Validaciones y capacidad SQL. |
| F-009 | Cliente | Historial | IMPLEMENTADO | Real | `ClientOrdersView.vue`, `listClientOrders` | Consulta propios pedidos. |
| F-010 | Cliente | Seguimiento de estados | IMPLEMENTADO | Real/Reatime | `OrderConfirmationView.vue` | Realtime de pedido/asignación. |
| F-011 | Cliente | ETA preparación | IMPLEMENTADO | Real tras migración | `202611240001`, `OrderTrackingSheet.vue` | Countdown frontend desde timestamp. |
| F-012 | Cliente | ETA transporte | PARCIAL | OSRM real, presentación frontend | `routeService.js`, `OrderConfirmationView.vue` | No persistido; depende de OSRM. |
| F-013 | Cliente | Cancelación | IMPLEMENTADO | RPC real | `cancelar_pedido` | Reglas dependen del estado. |
| F-014 | Cliente | Reembolso | PARCIAL | Simulado | `reembolsos`, `resolver_reembolso` | Sin dinero real. |
| F-015 | Repartidor | Registro/aprobación | IMPLEMENTADO | RPC real | `CourierRegistrationView.vue`, `courierRegistrationService.js` | Admin aprueba/rechaza. |
| F-016 | Repartidor | Disponibilidad/zona | IMPLEMENTADO | RPC real | `courierService.js`, RPC de zona/disponibilidad | Bloquea desactivar con asignación activa. |
| F-017 | Repartidor | Solicitudes | IMPLEMENTADO | Real | `CourierDashboardView.vue`, `solicitar_repartidor` | Descarte local no persistido. |
| F-018 | Repartidor | Aceptar entrega | IMPLEMENTADO | RPC real | `aceptar_entrega_repartidor` | Ubicación inicial requerida. |
| F-019 | Repartidor | Ciclo de entrega | IMPLEMENTADO | RPC real | `actualizar_estado_pedido` | ASIGNADO→RECOGIDO→EN_CAMINO→ENTREGADO. |
| F-020 | Repartidor | Ubicación activa | IMPLEMENTADO | RPC real | `actualizar_ubicacion_entrega`, `DeliveryLocationPicker.vue` | Actualización manual. |
| F-021 | Repartidor | Historial | IMPLEMENTADO | Real | `listCourierHistory`, dashboard | Presentación básica. |
| F-022 | Admin | Pedidos | IMPLEMENTADO | Real | `AdminOrdersView.vue` | Drawer y transiciones. |
| F-023 | Admin | Tiempo de preparación | IMPLEMENTADO | RPC real | `202611240001`, `adminOperationsService.js` | Popup y actualización. |
| F-024 | Admin | Catálogo | IMPLEMENTADO | Real | `AdminCatalogModuleView.vue`, `adminCatalogService.js` | CRUD protegido por RLS. |
| F-025 | Admin | Repartidores | PARCIAL | Real/limitado | `AdminCouriersView.vue` | Consulta/operación limitada. |
| F-026 | Admin | Capacidad por zona | SOLO_BACKEND | Real en SQL | `capacidad_zona`, `actualizar_bloqueo_zona` | No hay monitor completo. |
| F-027 | Admin | Escenarios demo | SOLO_BACKEND | Simulado controlado | `ejecutar_escenario_demo` | UI completa no verificada. |
| F-028 | Admin | Demanda histórica/predicción | NO_IMPLEMENTADO | No existe | Búsqueda de código sin módulo de predicción | Pendiente académico. |
| F-029 | Plataforma | RLS | IMPLEMENTADO | Real | `202611180002`, migraciones posteriores | Revisar exhaustivamente en cada cambio. |
| F-030 | Plataforma | Realtime | IMPLEMENTADO | Real | `202611180004`, vistas | Sin centro de notificaciones completo. |
| F-031 | Plataforma | PWA | IMPLEMENTADO | Real | `vite.config.js` | Manifest/service worker generados. |
| F-032 | Plataforma | Tests automatizados | NO_IMPLEMENTADO | No existe evidencia | `package.json` no tiene script test | Validación realizada solo con build. |

Estados anteriores se basan en inspección estática, salvo el build ejecutado y la aplicación remota previamente observada de `202611240001`.

## 12. Diagnóstico final

### Completado

- Arquitectura base PWA funcional.
- Auth, roles, RLS y RPC principales.
- Catálogo, carrito, checkout y pedidos.
- Flujo operativo de repartidor.
- Mapas Leaflet y rutas OSRM.
- Capacidad básica por zona y escenarios demo backend.
- Realtime de pedidos/asignaciones.
- Preparación estimada persistente y actualización administrativa.

### Pendiente

- Pago real.
- Predicción de demanda.
- Monitor administrativo de capacidad y operación.
- Reasignación automática.
- ETA persistido y gobernado por backend para transporte.
- Centro de notificaciones completo.
- Tests unitarios, integración, E2E y concurrencia.
- Componente Vue nativo para reemplazar varias manipulaciones DOM recientes.

### Problemas técnicos/inconsistencias

1. El esquema inicial define estados antiguos y luego se amplía mediante migraciones; cualquier entorno que no aplique todas las migraciones queda incompatible.
2. El frontend depende de columnas añadidas por migraciones recientes; un Supabase desactualizado rompe consultas.
3. Hay RPC sobrecargadas para aceptar repartidor (`uuid` y `uuid,numeric,numeric`), lo que exige cuidado en grants y llamadas.
4. Las distancias de asignación SQL son euclidianas/simuladas, mientras el frontend usa OSRM vial.
5. El descarte de solicitudes es local y no forma parte del estado operacional.
6. Algunas interfaces se agregaron mediante `MutationObserver`/DOM directo; esto puede generar problemas de ciclo de vida, duplicación y accesibilidad.
7. OSRM público puede fallar, limitarse o responder lentamente.
8. No se encontraron pruebas automatizadas que aseguren transiciones concurrentes o consistencia entre Realtime y vistas.

### Restricciones aceptables de MVP

- Pago simulado.
- Reembolso simulado.
- Datos demo controlados por `es_demo`.
- ETA dependiente de servicio externo.
- Descarte local de solicitudes.
- Operaciones administrativas y notificaciones con alcance reducido.

## Verificaciones realizadas

- Inspección de todos los archivos principales de `src/`.
- Inspección de migraciones SQL y seeds disponibles.
- Revisión de RPC, tablas, índices, triggers, RLS y grants.
- Revisión de rutas y guardas.
- Revisión de servicios Supabase, OSRM y TheMealDB.
- `npm run build`: ejecutado correctamente durante la auditoría.
- No se ejecutaron pruebas E2E ni pruebas de base de datos con datos reales.

## Aspectos no verificables con evidencia suficiente

- Estado completo de todas las migraciones en cada entorno remoto; solo existe evidencia directa de la migración de preparación aplicada previamente.
- Comportamiento real bajo concurrencia de varios repartidores.
- Rendimiento de OSRM y Supabase bajo carga.
- Accesibilidad completa con lector de pantalla.
- Existencia o configuración de usuarios reales en Auth.
- Flujo financiero real, porque no existe integración de pagos.
