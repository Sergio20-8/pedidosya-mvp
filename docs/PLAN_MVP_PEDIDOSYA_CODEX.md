# Plan maestro del MVP — Plataforma de pedidos y optimización logística

> **Documento de contexto para Codex.** Versión de planificación, 18 de noviembre de 2026. No empezar a implementar funcionalidades fuera de este alcance sin consultarlo. Las capturas de referencia visual de PedidosYa serán entregadas a Codex por separado.

## 1. Objetivo

Construir una **PWA mobile-first**, inspirada visualmente en la aplicación de PedidosYa, para demostrar un proyecto universitario de **optimización de pedidos, disponibilidad y asignación de repartidores, saturación por zona, cancelaciones y reembolsos**. No es una integración oficial con PedidosYa ni un producto comercial. Utilizar datos ficticios y pagos/reembolsos simulados.

El objetivo de la demostración es completar un recorrido entre **cliente → sistema logístico → repartidor**, mientras el administrador puede alterar las condiciones operativas y comprobar las reglas de negocio.

## 2. Decisiones confirmadas

- **Una sola PWA**, con tres vistas: **CLIENTE, REPARTIDOR y ADMINISTRADOR**.
- **No implementar pantalla de login ni registro en esta versión.** Esta decisión sustituye la propuesta anterior de Supabase Auth y registro público. La referencia real muestra que la aplicación puede abrir directamente en inicio; para nuestro prototipo habrá **selector de tipo de usuario en la primera apertura**.
- Guardar el tipo seleccionado en `localStorage`, omitir el selector en aperturas siguientes y ofrecer **Cambiar tipo de usuario** en Configuración. Esto es una preferencia de interfaz, **no autenticación ni autorización**.
- La interfaz del cliente debe ser **muy fiel visualmente a las capturas que entregará el usuario**: splash, inicio, pedidos, perfil, búsqueda, producto, carrito y modal de carritos vacíos. No inventar una estética genérica. No copiar activos protegidos sin permiso; usar imágenes y logos de prueba con derechos adecuados cuando corresponda.
- Proyecto de **Supabase ya creado** por el usuario; Codex preparará el esquema y migraciones. No asumir que existen tablas.
- Codex escribirá el código; el usuario revisará el resultado visual y los flujos.
- No trabajar por ahora en metodologías, DevOps, DevSecOps, CI/CD complejo ni documentación académica extensa.

## 3. Stack mínimo

| Capa | Tecnología | Uso |
|---|---|---|
| Aplicación | Vue 3 + Vite + TypeScript | Interfaz y lógica del frontend |
| Diseño | Tailwind CSS | Reproducir capturas mobile-first |
| Estado | Pinia | Carrito, selección de vista y estado compartido |
| Rutas | Vue Router | Pantallas y navegación |
| Base de datos | Supabase PostgreSQL | Restaurantes, productos, zonas, pedidos, repartidores, eventos |
| Actualización | Supabase Realtime, solo donde aporte valor | Refrescar estados de pedidos/entregas |
| PWA | vite-plugin-pwa | Instalable desde navegador en Android y iOS |
| Publicación | Vercel | Hosting sencillo, cuando el MVP esté listo |

Evitar backend propio en Spring Boot/Node, microservicios, Docker, pagos reales, GPS en vivo y servicios de mapas de pago. No añadir PrimeVue salvo necesidad concreta: para lograr fidelidad visual, priorizar componentes Vue propios con Tailwind.

## 4. Perfiles y navegación

### Inicio de la PWA

1. Mostrar splash breve con estilo de la referencia visual.
2. Leer `localStorage` (p. ej. `mvp_user_type`).
3. Si no hay valor válido, mostrar selector **Cliente / Repartidor / Administrador**.
4. Guardar selección y redirigir a la página inicial del rol.
5. En Configuración, **Cambiar tipo de usuario** elimina la selección y vuelve al selector.

No pedir correo, contraseña ni datos personales para usar el prototipo. No afirmar que el selector de rol protege datos. El selector puede cambiarse libremente porque es una demostración.

### Cliente

Barra inferior con **Inicio, Mercados, Promociones, Pedidos, Mi perfil**, como en las capturas. Las pestañas de Mercados y Promociones pueden usar contenido ficticio y funciones sencillas, pero no deben ser botones muertos.

Pantallas mínimas:

1. **Inicio:** ubicación/zona seleccionada, búsqueda, carrito, banners, categorías, establecimientos y promociones.
2. **Búsqueda:** buscar restaurantes/productos y mostrar búsquedas recientes locales.
3. **Listado y detalle de restaurante:** imagen, nombre, categorías, menú, productos y precios.
4. **Detalle de producto:** imagen, descripción, precio, opciones obligatorias/opcionales si existen, cantidad y agregar al carrito.
5. **Carrito:** productos, edición de cantidad/opciones, subtotal, cargo de entrega simulado, total, modalidad de entrega si se muestra, botón para continuar. Modal de carrito vacío siguiendo captura.
6. **Confirmación:** zona/dirección ficticia, resumen, estimación de entrega y validación de capacidad **antes de aceptar el pedido**. No cobrar dinero real.
7. **Seguimiento:** estado actual, repartidor asignado si existe, ETA simulada y línea de progreso.
8. **Mis pedidos:** activos, entregados y cancelados; detalle, motivo de cancelación y estado de reembolso cuando aplique.
9. **Mi perfil:** nombre de demostración editable localmente, zona/direcciones ficticias, opciones visuales de la referencia y Configuración para cambiar rol. Las opciones no implementadas deben indicarlo claramente, no aparentar funcionar.

### Repartidor

Interfaz simple, coherente con el estilo visual de la PWA:

- Panel de pedidos asignados y cantidad de entregas activas.
- Cambiar estado **Disponible / No disponible**.
- Consultar detalle del pedido: comercio, zona/dirección ficticia, resumen y estado.
- Marcar transiciones válidas: **Asignado → Recogido → En camino → Entregado**.
- Ver historial de entregas de prueba.
- No exigir GPS real, navegación externa ni geolocalización continua.

### Administrador / Operaciones

Panel ligero para exponer las mejoras:

- Ver zonas y su capacidad: pedidos activos, repartidores disponibles y relación pedidos/repartidor.
- Ver y editar escenarios de prueba: activar/desactivar repartidores, simular nuevos pedidos/carga, cambiar disponibilidad.
- Ver pedidos, estados y repartidor asignado.
- Ver historial de cancelaciones y reembolsos simulados.
- Reiniciar datos de demostración de forma controlada, con confirmación.
- Mostrar por qué una zona está **normal / advertencia / bloqueada**.

## 5. Reglas de negocio fundamentales

Estas reglas provienen de la planificación funcional y de los requerimientos académicos ya discutidos. **No sustituirlas por criterios arbitrarios.**

### 5.1 Capacidad por zona

- Calcular `ratio = pedidos_activos / repartidores_disponibles` para cada zona.
- Si `ratio <= 4`: operación normal **si la zona no estaba previamente bloqueada**.
- Si `4 < ratio <= 5`: mostrar advertencia **antes de confirmar** el pedido, con ETA estimada y posibilidad de continuar/cancelar.
- Si `ratio > 5`: bloquear aceptación de nuevos pedidos en la zona.
- **Histéresis:** una zona que ya fue bloqueada **permanece bloqueada hasta que el ratio sea estrictamente menor que 4**. No desbloquear en 4 exacto. Por tanto, el estado depende también del bloqueo anterior; no basta con calcularlo solo a partir del ratio actual.
- Si hay **0 repartidores disponibles**, no dividir entre cero: la zona no puede aceptar nuevos pedidos; mostrar indisponibilidad. Definir el caso sin pedidos también como falta de capacidad operativa, no como ratio cero.
- Revalidar capacidad en la operación de confirmación para evitar aceptar pedidos simultáneos que superen el límite. La UI solo presenta el resultado; la base de datos debe controlar la aceptación.

**Conflicto documental por resolver con el equipo:** un requisito general previo (RGN-01) plantea bloqueo al superar 1:1, mientras los específicos RF-03/RF-07 establecen bloqueo >5:1 y desbloqueo <4:1. Para este MVP aplicar provisionalmente **RF-03/RF-07**, que describen el comportamiento más específico; señalar la discrepancia en la entrega, sin ocultarla.

### 5.2 Asignación de repartidores

- Al aceptar un pedido, buscar repartidores **disponibles en la zona**.
- Elegir el más cercano al restaurante según **distancia simulada/predefinida**; en empate, menor cantidad de pedidos activos.
- Registrar la asignación y reflejarla en vistas cliente/repartidor/admin.
- Evitar doble asignación por concurrencia. No usar únicamente estado de Pinia o lógica cliente para decidir.
- Considerar el criterio de equilibrio de carga de RS-02 (diferencia máxima de un pedido entre repartidores disponibles), pero **documentar y resolver** su posible tensión con la prioridad de cercanía antes de prometer cumplimiento absoluto en todos los escenarios.
- Si no hay repartidor elegible, no inventar asignación; manejar el estado y la cancelación según reglas de demostración.

### 5.3 Estados y cancelaciones

Estados propuestos: `PENDIENTE`, `ASIGNADO`, `RECOGIDO`, `EN_CAMINO`, `ENTREGADO`, `CANCELADO`. Ajustar nombres en código si se mantiene una máquina de estados consistente. Contar como activos solo los estados que correspondan a pedidos no finalizados.

- Registrar motivo, fecha/hora y origen de la cancelación (sistema o persona).
- Si la causa es **falta de repartidores disponibles en el área**, crear solicitud de **reembolso simulado automático**.
- Para otras causas, registrar **revisión manual**.
- Evitar reembolsos duplicados para el mismo pedido y causa.
- Mostrar estado e historial del reembolso. No usar tarjetas reales ni pasarelas de pago.

### 5.4 ETA y demanda

- Mostrar una **estimación de entrega simulada**, explicable, basada en preparación, distancia y carga de zona.
- No afirmar precisión real del 90 % ni tráfico real: son requisitos de un sistema empresarial, no demostrables con datos simulados.
- Predicción de demanda con 90 días de historial y entrenamiento semanal **fuera del MVP**; se puede dejar como mejora futura, sin mostrar un modelo de IA inexistente.

## 6. Datos y esquema mínimo sugerido

Codex debe diseñar las migraciones SQL versionadas y las relaciones apropiadas. Entidades sugeridas:

- `zones`: nombre, estado de bloqueo persistido, fecha de cambio.
- `restaurants`: nombre, descripción, categoría, zona, imagen, disponibilidad.
- `products`: restaurante, nombre, descripción, precio, imagen, opciones de producto si se necesitan.
- `drivers`: alias ficticio, zona, disponibilidad, posición simulada, capacidad/carga calculable.
- `orders`: identificador, cliente ficticio, restaurante, zona, estado, subtotal, envío, total, ETA, repartidor, timestamps.
- `order_items`: pedido, producto, cantidad, precio unitario congelado, opciones.
- `order_events`: pedido, estado/evento, actor/origen, fecha y notas.
- `cancellations`: pedido, causa, origen, fecha.
- `refunds`: pedido, causa, estado, monto simulado, fecha; restricción contra duplicados.
- Opcional: `demo_scenarios` o mecanismos de restablecimiento de datos.

**Identidad sin login:** utilizar cliente ficticio de demostración o identificador local no sensible; **no tratar un ID de localStorage como prueba de identidad**. Evitar datos personales reales. Si se requieren pedidos privados multiusuario o acceso real por roles, detenerse y proponer Supabase Auth antes de publicar.

### Seguridad mínima obligatoria incluso para un prototipo

- La `publishable key` de Supabase puede usarse en frontend; **nunca** poner `service_role`, secret keys ni contraseña de DB en variables `VITE_*` o repositorio.
- No dejar tablas con permisos indiscriminados de escritura/lectura desde `anon`, en especial administración, repartidores y pedidos.
- Como **no hay login**, la app no puede ofrecer controles de autorización por rol. Para una demo pública, preferir **datos sintéticos, operaciones limitadas y un entorno aislado**; las mutaciones sensibles requieren funciones restringidas o un mecanismo seguro adicional. Si esto impide demostrar todas las acciones de admin en un despliegue público, explicarlo y proponer un modo demo local/aislado o autenticación real. **Nunca presentar `localStorage` como barrera de seguridad.**
- Operaciones de aceptación, asignación y reembolso deben ser atómicas/idempotentes cuando corresponda.

## 7. Diseño visual y UX

Las capturas serán entregadas **por separado**. Codex debe inspeccionarlas antes de implementar y utilizar sus patrones como fuente principal:

- Splash rosa intenso con marca centrada.
- Inicio con cabecera rosa, ubicación, búsqueda blanca redondeada, banners, categorías en tarjetas, carruseles y barra inferior fija.
- Pantalla Mis pedidos con filtros y estados de entregado/cancelado.
- Mi perfil con accesos y secciones de configuración.
- Búsqueda con campo superior y búsquedas recientes.
- Detalle de producto con imagen protagonista, opciones, cantidad y botón fijo inferior.
- Carrito con resumen, sugerencias y CTA inferior fijo.
- Bottom sheet para carrito vacío.

Cuidar proporciones, espaciado, tipografía, bordes redondeados, iconografía, sombras, comportamiento de scroll, safe areas de iPhone y teclado móvil. La referencia es la **estructura y apariencia**, pero no afirmar afiliación oficial con PedidosYa. Para la presentación, usar activos permitidos y contenido de demostración.

## 8. Flujos de aceptación para demostrar

### Escenario A — Pedido normal
1. Seleccionar Cliente; abrir restaurante, agregar producto, ir al carrito.
2. Seleccionar zona con capacidad y confirmar.
3. Ver pedido creado, ETA y repartidor asignado.
4. Cambiar a Repartidor, actualizar estados.
5. Volver a Cliente y comprobar el seguimiento hasta Entregado.

### Escenario B — Advertencia y bloqueo
1. Desde Admin configurar pedidos/repartidores para superar 4:1.
2. Cliente intenta confirmar y recibe advertencia con ETA.
3. Admin provoca relación >5:1; Cliente no puede confirmar pedido nuevo.
4. Reducir ratio a 4:1: la zona **sigue bloqueada**.
5. Reducirlo a <4:1: la zona se desbloquea y vuelve a aceptar pedidos.

### Escenario C — Cancelación y reembolso
1. Simular pedido que se cancela por falta de repartidores.
2. Comprobar registro de causa, origen y hora.
3. Ver reembolso simulado automático.
4. Reintentar operación y verificar que no se duplique.
5. Simular otra causa y comprobar estado de revisión manual.

## 9. Orden de implementación para Codex

**Fase 1 — Base y visual:** proyecto Vue, Tailwind, rutas, Pinia, PWA, splash, selector de rol persistido, navegación y estructura visual conforme a capturas.

**Fase 2 — Cliente:** inicio, búsqueda, categorías, restaurante, detalle de producto, carrito, pedidos, perfil y estados vacíos con datos de prueba.

**Fase 3 — Persistencia:** migraciones Supabase, seed ficticio, acceso controlado, creación/consulta de pedidos y sincronización de estados.

**Fase 4 — Logística:** ratio por zona, histéresis, advertencia, bloqueo, ETA y asignación de repartidores; validación atómica.

**Fase 5 — Repartidor y admin:** disponibilidad, entregas, cambios de estado, dashboard y controles de escenarios.

**Fase 6 — Cancelaciones y entrega:** eventos, reembolsos simulados, pruebas integradas, revisión visual, responsive, PWA y despliegue.

**En cada fase:** entregar funcionalidad verificable, explicar archivos/cambios, detallar cómo probar y no avanzar automáticamente a la siguiente fase si hay decisiones abiertas importantes.

## 10. Criterios generales de aceptación

- Se puede instalar la PWA en Android y en iPhone mediante el navegador compatible.
- Al elegir un tipo de usuario por primera vez, se recuerda en reaperturas y se puede cambiar desde Configuración.
- Las tres vistas están disponibles y no son maquetas sin interacción.
- El cliente puede completar el flujo de compra ficticia y ver su pedido.
- El repartidor puede ver y actualizar sus entregas asignadas.
- Admin puede producir escenarios de capacidad y consultar resultados.
- La advertencia (>4:1), bloqueo (>5:1) y desbloqueo (<4:1) funcionan respetando histéresis.
- Las cancelaciones registran causas y los reembolsos simulados no se duplican.
- Las pantallas del cliente siguen las referencias visuales suministradas.
- No hay cobros reales, datos sensibles reales ni claves secretas expuestas.

## 11. Fuera de alcance

- Integración con API interna de PedidosYa.
- Pagos reales, reembolsos bancarios, facturación o comercios operativos.
- GPS en tiempo real, mapas/rutas de pago o tracking físico.
- Modelos de machine learning reales o entrenamiento histórico.
- Migración de años de datos, SLA empresarial, alta disponibilidad garantizada.
- App nativa separada para cada rol.
- Login/registro público en **esta versión**, salvo nueva decisión expresa del usuario.
- Metodologías, DevOps, DevSecOps o infraestructura compleja.

## 12. Instrucciones de trabajo para Codex

1. **Primero inspecciona este archivo y las imágenes de referencia que te proporcione el usuario.**
2. Antes de programar, presenta un resumen de entendimiento, mapa de pantallas, modelo de datos propuesto y dudas realmente bloqueantes.
3. No presupongas que Supabase ya tiene tablas ni inventes credenciales.
4. Mantén la implementación sencilla, modular y con datos ficticios coherentes.
5. Prioriza fidelidad visual del cliente y corrección de las reglas logísticas.
6. No implementar funcionalidades fuera de alcance ni sustituir las reglas por aproximaciones sin avisar.
7. Explica claramente las limitaciones de seguridad de un selector de roles sin autenticación.
8. Trabaja por fases; al final de cada una indica cómo verificarla.

---

**Nota:** Este archivo recoge las decisiones conversadas para el MVP. Las capturas y los documentos académicos originales se entregarán a Codex aparte cuando corresponda. Si una captura o requisito original contradice esta planificación, informar al usuario y pedir decisión antes de alterar una regla central.
