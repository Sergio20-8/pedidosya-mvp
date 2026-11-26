# PLAN MAESTRO DEL MVP — PedidosYa (prototipo académico)
**Versión:** 2.0 · **Estado:** alcance funcional aprobado · **Fecha:** 18/11/2026  
**Destinatario:** Codex. Leer también `DISENO_BASE_DATOS_MVP_PEDIDOSYA_V2.md`. Las capturas de referencia visual serán entregadas por separado.

## 1. Objetivo
Construir **una PWA mobile-first**, visualmente cercana a las capturas proporcionadas de PedidosYa, para demostrar una propuesta universitaria de optimización logística: validar capacidad antes de aceptar pedidos, advertir saturación, distribuir asignaciones, gestionar estados y simular cancelaciones/reembolsos. **No** es una integración oficial ni procesa pagos reales. Utilizar comercios, productos, posiciones y operaciones ficticias.

## 2. Alcance aprobado por el usuario
1. Registro, inicio y cierre de sesión.
2. Perfil y direcciones del cliente.
3. Restaurantes, productos y carrito.
4. Confirmación y seguimiento de pedidos.
5. Disponibilidad y selección manual de zona del repartidor.
6. Asignación automática equilibrada.
7. Advertencias y bloqueo por saturación.
8. Cancelaciones y reembolsos simulados.
9. Panel administrativo con simulador.
10. Notificaciones dentro de la aplicación.
11. Datos compartidos mediante Supabase Realtime.

**No implementar funciones fuera de este alcance sin autorización.** Favoritos, cupones complejos, repetición de pedidos, analítica predictiva real, mapas/GPS real, pasarelas de pago, facturación y push notifications quedan fuera de la primera entrega. Promociones y mercados deben tener contenido de prueba útil, no botones muertos.

## 3. Stack aprobado
Vue 3 + Vite + **JavaScript** + Composition API (`<script setup>`), Tailwind CSS, Vue Router, Pinia, `@supabase/supabase-js`, `vite-plugin-pwa`, `lucide-vue-next`, Supabase PostgreSQL/Auth/Realtime y Vercel para publicar. Evitar backend propio, Docker, Spring Boot, microservicios y librerías UI pesadas; componentes Vue propios para máxima fidelidad visual. No agregar dependencias sin necesidad.

## 4. Acceso, registro y sesiones
- **No mostrar login obligatorio al abrir la PWA.** En la primera visita se muestra **selector de tipo de experiencia**: Cliente / Repartidor / Administrador; guardar preferencia en `localStorage`. En siguientes aperturas ir directo a la experiencia seleccionada.
- **Cliente:** puede explorar catálogo, restaurantes, promociones y carrito como visitante. **Al intentar confirmar pedido**, solicitar **registro o inicio de sesión** sin perder carrito ni navegación. Registro mínimo: nombre, correo, teléfono, contraseña y confirmación. Supabase Auth administra contraseña/sesión; `perfiles` guarda nombre/teléfono. Permitir cerrar sesión en Mi perfil; tras cerrar, seguir en vista pública de cliente.
- **Repartidor y administrador:** requieren **sesión real** con cuentas habilitadas para esos roles. Cuentas creadas/promovidas de forma controlada (no permitir autoelegir roles privilegiados). Pantalla de acceso reutilizable cuando sea necesaria. Al cerrar sesión, volver al acceso del rol o selector.
- El selector local **no concede permisos**. Un usuario no puede hacerse administrador cambiando `localStorage`; validar roles con políticas RLS y funciones de BD. No poner contraseñas en tablas de perfiles ni exponer secret/service_role keys.
- En Configuración, **Cambiar tipo de usuario** permite elegir otra experiencia. Si se cambia de perfil, la UI se ajusta, pero para operaciones privilegiadas se exigirá sesión autorizada.
- Configurar recuperación de contraseña por email solo si es necesaria para la demo; no priorizar login social.

## 5. Interfaz del cliente
Referencias visuales: **capturas entregadas a Codex**, no inventar diseño genérico. Respetar distribución, buscador, tarjetas, banners, colores, iconos, espacios, splash y barra inferior. No dibujar barra de estado del sistema ni Dynamic Island dentro de HTML. Usar recursos de prueba con licencia adecuada.

Barra inferior: **Inicio, Mercados, Promociones, Pedidos, Mi perfil**.
Pantallas:
- **Inicio:** zona/dirección, buscador, banners, categorías, restaurantes y promociones ficticias.
- **Búsqueda:** restaurantes/productos, historial local opcional.
- **Restaurante:** nombre, imagen, menú, categorías y productos.
- **Producto:** detalle, cantidad, observaciones y opciones/extras sencillos si el catálogo lo define.
- **Carrito:** editar cantidades, quitar ítems, subtotal, envío simulado, total, carrito vacío con modal según referencia; carrito local persistente, sincronizar solo al confirmar.
- **Confirmación:** exigir sesión, dirección válida de zona de entrega, resumen, ETA simulado, validación de capacidad **antes de aceptar**. No cobrar dinero real.
- **Seguimiento:** estados `PENDIENTE`, `ASIGNADO`, `RECOGIDO`, `EN_CAMINO`, `ENTREGADO`, `CANCELADO`; repartidor asignado, ETA, eventos; refresco Realtime.
- **Mis pedidos:** activos, entregados, cancelados, detalle, motivo y reembolso simulado.
- **Mi perfil:** datos, direcciones, cerrar sesión, cambiar tipo de experiencia.
- **Promociones/Mercados:** pantallas navegables con datos ficticios, sin simular descuentos que no se reflejen en el total.

## 6. Interfaz del repartidor
- Acceso con cuenta rol `REPARTIDOR`.
- Seleccionar manualmente **zona de trabajo** de catálogo (ej.: Centro, Escalón, Santa Tecla) sin GPS. Permitir cambiar zona **solo sin asignaciones activas**.
- Cambiar disponibilidad `DISPONIBLE / NO_DISPONIBLE`; no desactivar ni cerrar jornada si hay entregas activas, salvo reasignación administrativa explícita. **Cerrar sesión sí se permite**, pero el estado operativo debe manejarse sin perder entregas ni permitir nuevas asignaciones indebidamente; si hay pedidos activos, advertir y conservar la responsabilidad asignada.
- Ver carga actual, pedidos asignados, detalle, restaurante, dirección ficticia, historial.
- Transiciones autorizadas: `ASIGNADO → RECOGIDO → EN_CAMINO → ENTREGADO`. Refrescar cliente y admin con Realtime.
- Posiciones `(pos_x,pos_y)` ficticias configurables por administrador para probar distancias.

## 7. Administrador y simulador de aula
- Acceso rol `ADMIN`, sin registro público.
- Dashboard por zona: repartidores habilitados/disponibles, pedidos activos, ratio, advertencia/bloqueo.
- Ver pedidos, repartidores, asignaciones, motivos de cancelación, reembolsos, historial de eventos.
- Preparar **escenarios reproducibles**: normal, advertencia, bloqueo, recuperación, reparto equilibrado, cancelación por falta de repartidores y revisión manual.
- Controles de demo para activar/desactivar repartidores, cambiar zona, fijar posiciones ficticias, sembrar carga/pedidos ficticios y reiniciar datos **solo con privilegios ADMIN**. Distinguir acciones simuladas de pedidos reales del usuario de prueba.
- Realtime actualiza vistas de cliente/repartidor/admin; suscripciones filtradas y limpieza al salir.

## 8. Reglas logísticas aprobadas para el prototipo
### Capacidad por zona
- `activos`: pedidos `PENDIENTE`, `ASIGNADO`, `RECOGIDO`, `EN_CAMINO` cuya **zona de entrega** es la zona Z.
- `disponibles`: repartidores activos, disponibles y asignados a Z (pueden tener carga activa; `disponible` significa que aceptan nuevas asignaciones).
- Sin repartidores disponibles: no aceptar pedidos nuevos, aunque el ratio sea matemáticamente indefinido.
- `ratio = activos / disponibles`.
- Si la zona **no está bloqueada** y `4 < ratio <= 5`: advertencia previa con ETA y posibilidad de continuar.
- Si `ratio > 5`: bloquear nuevos pedidos; zona permanece bloqueada hasta que `ratio < 4` y haya repartidores.
- **Histéresis:** con `ratio = 4` la zona bloqueada continúa bloqueada; con `ratio = 5` una zona aún no bloqueada no se bloquea automáticamente.
- Revalidar **en BD y en transacción**, no solo en frontend. Para impedir que un pedido nuevo lleve la zona a `>5`, comprobar ratio **proyectado** `(activos+1)/disponibles` en confirmación; si lo supera, bloquear y rechazar la nueva confirmación. Mostrar aviso con ratio actual antes de confirmar.
- Si la capacidad cambia entre vista previa y confirmación, mostrar mensaje y solicitar reintento.
- Los umbrales RF-03/RF-07 prevalecen **provisionalmente** sobre RGN-01 (>1:1), contradicción documental pendiente de validación con el equipo.

### Asignación equilibrada y cercanía
- Filtrar repartidores de la zona, activos, disponibles y autorizados.
- **Prioridad MVP:** menor cantidad de asignaciones activas; **desempate:** menor distancia euclidiana ficticia al restaurante; último desempate ID estable. Este criterio prioriza RS-02 sobre la cercanía absoluta de RF-04; registrar explícitamente la decisión como adaptación del prototipo.
- No imponer límite fijo de dos pedidos por repartidor: impediría probar ratios 4:1/5:1. La carga se calcula desde asignaciones vigentes de pedidos activos.
- Realizar la elección y creación de asignación con protección transaccional/concurrencia; una asignación vigente por pedido. Si un repartidor está más cargado que otro elegible, no darle una nueva asignación mientras exista uno menos cargado, preservando la diferencia de cargas cuando se parte de un estado equilibrado.
- Si no hay repartidor elegible al confirmar, no crear asignación falsa. **Para el MVP:** rechazar confirmación sin cobrar; si un pedido ya aceptado queda sin repartidor por una incidencia simulada, permitir cancelación con causa `SIN_REPARTIDORES_EN_AREA`.
- Guardar razón de asignación en historial/evento.
- El sistema no garantiza equilibrio histórico absoluto si el administrador introduce cargas artificialmente desiguales; mostrarlo como situación de simulación.

### Estados, cancelaciones y reembolsos
- Flujo normal: `PENDIENTE → ASIGNADO → RECOGIDO → EN_CAMINO → ENTREGADO`. Cancelación permitida solo en estados autorizados y antes de `ENTREGADO`, según reglas de BD.
- `SIN_REPARTIDORES_EN_AREA` genera **un** reembolso automático **simulado**.
- Otras causas generan expediente `REVISION_MANUAL`; admin puede resolverlo simuladamente.
- No duplicar cancelaciones/reembolsos; conservar eventos auditables. No mover dinero.

## 9. Notificaciones internas
Tabla `notificaciones` por usuario autenticado; crear al asignar repartidor, cambiar estado, cancelar pedido, actualizar reembolso y cuando haya novedades relevantes. Lista/campana dentro de PWA, leídas/no leídas; Realtime para nuevas notificaciones. **No** push del sistema operativo, email masivo ni SMS.

## 10. Modelo de datos
**Fuente de verdad:** `DISENO_BASE_DATOS_MVP_PEDIDOSYA_V2.md`. Incluye entidades de autenticación, perfiles, direcciones, zonas, restaurantes, categorías, productos, opciones, promociones, repartidores, pedidos, detalles, opciones elegidas, asignaciones, eventos, cancelaciones, reembolsos, notificaciones y escenarios de demo. Carrito se guarda localmente; pedidos se persisten al confirmar.

## 11. Seguridad
- Supabase Auth para sesiones. `perfiles.id = auth.users.id`, roles controlados.
- RLS en todas las tablas expuestas; clientes solo leen sus pedidos/direcciones/notificaciones; repartidores solo sus asignaciones; admin operaciones autorizadas.
- Catálogo público solo lectura; **no** escrituras anónimas de operaciones.
- Confirmación, asignación, cambios de estado, cancelaciones, reembolsos y reset de simulador a través de funciones transaccionales con verificación explícita de `auth.uid()` y rol. Revisar `SECURITY DEFINER` y `search_path` si se usa.
- No guardar claves secretas en frontend. Datos sintéticos para exposición.

## 12. Entregas pequeñas a Codex
**Codex debe completar y detenerse en cada paso; no hacer todo en un solo prompt.**
1. Inicializar proyecto e instalar dependencias; comprobar `npm run build`.
2. Revisar diseño de BD y generar migraciones SQL sin aplicarlas todavía.
3. Aplicar migraciones y RLS con aprobación; insertar datos ficticios.
4. Conectar Supabase y crear selector de experiencia.
5. Implementar registro/login/logout y perfiles.
6. Pantallas cliente, catálogo y carrito según capturas.
7. Confirmación, capacidad, pedidos y seguimiento.
8. Repartidor: zona, disponibilidad, asignaciones y estados.
9. Admin: dashboard, simulador y reinicio.
10. Cancelaciones/reembolsos, notificaciones, Realtime.
11. Validación móvil, pruebas integradas y publicación.

## 13. Criterios de aceptación para exposición
- Abrir como cliente visitante, explorar y llenar carrito sin login; al confirmar, solicitar registro/login y **conservar carrito**.
- Registrar cliente, cerrar sesión y volver a ingresar; sus pedidos y direcciones permanecen.
- Repartidor inicia sesión, elige zona ficticia y actualiza estados; el cliente observa cambios.
- Asignación elige menor carga y desempata por distancia simulada; queda trazabilidad.
- Zona avisa al superar 4:1, bloquea al superar 5:1 y solo desbloquea al bajar de 4:1.
- Admin reproduce escenarios en clase y reinicia datos de prueba.
- Cancelación por falta de repartidores genera exactamente un reembolso simulado; otras causas pasan a revisión.
- Notificaciones internas y Realtime funcionan entre dos dispositivos o sesiones.
- PWA instalable; interfaz cliente fiel a capturas; sin pagos/GPS reales.

## 14. Decisiones que no debe improvisar Codex
- No cambiar prioridades de asignación ni umbrales sin consultar.
- No implementar permisos con `localStorage`.
- No exponer mutaciones administrativas a `anon`.
- No afirmar que ETA o reembolsos son reales.
- No copiar logos/fotografías comerciales sin permiso.
- No comenzar el siguiente paso sin aprobación.
