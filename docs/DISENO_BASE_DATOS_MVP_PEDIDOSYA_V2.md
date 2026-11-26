# DISEÑO DE BASE DE DATOS — PedidosYa MVP (v2)
**Estado:** diseño aprobado funcionalmente, pendiente de convertir a migraciones SQL y validar con pruebas.  
**Motor:** Supabase PostgreSQL + Supabase Auth + Realtime. **No ejecutar este archivo como SQL.**  
**Fuente funcional:** `PLAN_MVP_PEDIDOSYA_CODEX_V2.md`.

## 1. Convenciones
- PK `uuid DEFAULT gen_random_uuid()` salvo `perfiles.id`, que referencia `auth.users(id)`.
- `created_at` y `updated_at`: `timestamptz`, hora del servidor; trigger para actualización.
- Montos `numeric(12,2)`; cantidades `integer`; restricciones `CHECK`; fechas en UTC.
- IDs y claves foráneas indexados según consultas; no borrar en cascada pedidos/historial.
- Roles `CLIENTE`, `REPARTIDOR`, `ADMIN` asignados **por operaciones privilegiadas**, nunca por un campo libre enviado en registro.
- No almacenar contraseñas en tablas públicas: solo Supabase Auth.
- Posiciones `(pos_x,pos_y)` son puntos **ficticios** en un plano de demo, no GPS.
- Estados de pedido `PENDIENTE`, `ASIGNADO`, `RECOGIDO`, `EN_CAMINO`, `ENTREGADO`, `CANCELADO`.
- El carrito permanece en Pinia/localStorage y **no necesita tabla** en el MVP.

## 2. Tablas — 19 entidades de aplicación

### 01 `perfiles`
`id uuid PK REFERENCES auth.users(id)`, `nombre varchar(120) NOT NULL`, `telefono varchar(30)`, `rol varchar(20) NOT NULL DEFAULT 'CLIENTE' CHECK (...)`, `activo boolean DEFAULT true`, `created_at timestamptz`, `updated_at timestamptz`.
- Trigger al crear usuario Auth genera perfil con rol **CLIENTE**, sin confiar en metadatos manipulables.
- Alta/promoción de repartidores y admins solo mediante operación privilegiada. Evitar que un cliente edite `rol` o `activo`.

### 02 `direcciones`
`id uuid PK`, `cliente_id uuid NOT NULL FK perfiles(id)`, `alias varchar(60)`, `detalle text NOT NULL`, `referencia text`, `zona_id uuid NOT NULL FK zonas(id)`, `predeterminada boolean DEFAULT false`, `created_at`, `updated_at`.
- Índice parcial único `(cliente_id) WHERE predeterminada` para una dirección principal.
- Solo perfiles CLIENTE pueden administrar sus propias direcciones.

### 03 `zonas`
`id uuid PK`, `nombre varchar(100) UNIQUE NOT NULL`, `descripcion text`, `activa boolean DEFAULT true`, `bloqueada boolean DEFAULT false`, `bloqueada_desde timestamptz`, `updated_at`.
- Bloqueo persistido para histéresis. La advertencia se **calcula**; no duplicar estado.
- Cambios de bloqueo exclusivamente por función de capacidad, no por `UPDATE` desde navegador.

### 04 `restaurantes`
`id uuid PK`, `zona_id uuid NOT NULL FK zonas(id)`, `nombre varchar(150) NOT NULL`, `descripcion text`, `imagen_url text`, `banner_url text`, `tiempo_preparacion_min integer DEFAULT 20 CHECK (>0)`, `pos_x numeric(10,3)`, `pos_y numeric(10,3)`, `activo boolean DEFAULT true`, `created_at`, `updated_at`.
- Para demo, un restaurante atiende su propia zona de entrega; se puede ampliar después.

### 05 `categorias`
`id uuid PK`, `nombre varchar(100) UNIQUE NOT NULL`, `imagen_url text`, `orden integer DEFAULT 0`, `activa boolean DEFAULT true`.
- Categorías de navegación/catálogo.

### 06 `productos`
`id uuid PK`, `restaurante_id uuid NOT NULL FK restaurantes(id)`, `categoria_id uuid NOT NULL FK categorias(id)`, `nombre varchar(150) NOT NULL`, `descripcion text`, `precio numeric(12,2) NOT NULL CHECK (>=0)`, `imagen_url text`, `disponible boolean DEFAULT true`, `created_at`, `updated_at`.

### 07 `grupos_opciones`
`id uuid PK`, `producto_id uuid NOT NULL FK productos(id)`, `nombre varchar(100) NOT NULL`, `obligatorio boolean DEFAULT false`, `min_selecciones integer DEFAULT 0 CHECK (>=0)`, `max_selecciones integer NOT NULL CHECK (>0)`, `orden integer DEFAULT 0`, `CHECK (min_selecciones <= max_selecciones)`.
- Ej.: tamaño, bebida o extras. Validar coherencia de obligatorio/min.

### 08 `opciones_producto`
`id uuid PK`, `grupo_id uuid NOT NULL FK grupos_opciones(id)`, `nombre varchar(100) NOT NULL`, `precio_extra numeric(12,2) DEFAULT 0 CHECK (>=0)`, `disponible boolean DEFAULT true`, `orden integer DEFAULT 0`.
- Opciones configurables, no cambios de precio arbitrarios desde cliente.

### 09 `promociones`
`id uuid PK`, `restaurante_id uuid NULL FK restaurantes(id)`, `titulo varchar(150) NOT NULL`, `descripcion text`, `imagen_url text`, `tipo varchar(20) CHECK IN ('BANNER','DESCUENTO')`, `descuento_porcentaje numeric(5,2) NULL CHECK (>=0 AND <=100)`, `inicio timestamptz`, `fin timestamptz`, `activa boolean DEFAULT true`, `CHECK (fin IS NULL OR inicio IS NULL OR fin > inicio)`.
- Para MVP, los banners son informativos; **si hay descuento aplicado al total, validarlo en servidor y persistir el monto**. No mostrar una oferta que se cobre de otra forma. Se puede usar solo `BANNER` en el seed inicial.

### 10 `repartidores`
`id uuid PK`, `perfil_id uuid NOT NULL UNIQUE FK perfiles(id)`, `zona_id uuid NULL FK zonas(id)`, `disponible boolean DEFAULT false`, `pos_x numeric(10,3)`, `pos_y numeric(10,3)`, `activo boolean DEFAULT true`, `updated_at`.
- Perfil debe tener rol REPARTIDOR (validar en función/trigger).
- `zona_id` se elige manualmente desde la vista de repartidor. Prohibir cambiar zona si existen asignaciones activas.
- Disponibilidad significa **aceptar nuevos pedidos**, incluso si ya tiene asignaciones; no imponer máximo fijo de dos.
- La carga se calcula de asignaciones vigentes; no guardar contador editable.
- `logout` no borra asignaciones ni pedidos; antes de cerrar se puede advertir y poner no disponible para nuevas asignaciones según política de sesión.

### 11 `pedidos`
`id uuid PK`, `numero bigint GENERATED BY DEFAULT AS IDENTITY UNIQUE`, `cliente_id uuid NOT NULL FK perfiles(id)`, `restaurante_id uuid NOT NULL FK restaurantes(id)`, `zona_id uuid NOT NULL FK zonas(id)`, `direccion_id uuid NULL FK direcciones(id)`, `direccion_snapshot text NOT NULL`, `estado varchar(20) NOT NULL CHECK (...)`, `subtotal numeric(12,2) CHECK (>=0)`, `descuento numeric(12,2) DEFAULT 0 CHECK (>=0)`, `costo_envio numeric(12,2) DEFAULT 0 CHECK (>=0)`, `total numeric(12,2) CHECK (>=0)`, `eta_minutos integer CHECK (>=0)`, `confirmado_en timestamptz`, `finalizado_en timestamptz`, `created_at`, `updated_at`.
- `total = subtotal - descuento + costo_envio`, `descuento <= subtotal`.
- `cliente_id` es identidad Auth, no UUID elegido desde localStorage.
- `direccion_snapshot` conserva dirección histórica aunque el usuario edite su libreta.
- Solo se crean mediante función transaccional; nunca aceptar `precio`, `total`, `cliente_id` o `estado` arbitrarios del frontend.

### 12 `pedido_detalles`
`id uuid PK`, `pedido_id uuid NOT NULL FK pedidos(id)`, `producto_id uuid NOT NULL FK productos(id)`, `nombre_producto_snapshot varchar(150) NOT NULL`, `cantidad integer NOT NULL CHECK (>0)`, `precio_base_unitario numeric(12,2) NOT NULL CHECK (>=0)`, `precio_opciones_unitario numeric(12,2) NOT NULL DEFAULT 0 CHECK (>=0)`, `subtotal_linea numeric(12,2) NOT NULL CHECK (>=0)`, `observaciones text`, `opciones_snapshot jsonb DEFAULT '[]'::jsonb`.
- Snapshot de opciones elegidas con sus nombres y precios; **no requiere tabla extra** para selección por pedido en el MVP.
- Servidor valida que opciones pertenecen al producto, límites del grupo, disponibilidad y totales. `subtotal_linea = cantidad * (precio_base_unitario + precio_opciones_unitario)`.

### 13 `asignaciones`
`id uuid PK`, `pedido_id uuid NOT NULL FK pedidos(id)`, `repartidor_id uuid NOT NULL FK repartidores(id)`, `distancia_simulada numeric(12,3) NOT NULL CHECK (>=0)`, `carga_antes integer NOT NULL CHECK (>=0)`, `criterio varchar(60) NOT NULL DEFAULT 'MENOR_CARGA_DISTANCIA'`, `asignada_en timestamptz NOT NULL`, `terminada_en timestamptz NULL`, `motivo_fin varchar(30) NULL`.
- Índice **único parcial** `UNIQUE(pedido_id) WHERE terminada_en IS NULL`.
- Una asignación vigente por pedido; historial de reasignaciones conservado.

### 14 `eventos_pedido`
`id uuid PK`, `pedido_id uuid NOT NULL FK pedidos(id)`, `tipo_evento varchar(40) NOT NULL`, `estado_anterior varchar(20)`, `estado_nuevo varchar(20)`, `actor_id uuid NULL FK perfiles(id)`, `origen varchar(20) NOT NULL CHECK IN ('SISTEMA','CLIENTE','REPARTIDOR','ADMIN')`, `detalle text`, `created_at timestamptz NOT NULL`.
- Append-only desde funciones de negocio. Registrar confirmación, validación, asignación, cambio, cancelación y reembolso.

### 15 `cancelaciones`
`id uuid PK`, `pedido_id uuid NOT NULL UNIQUE FK pedidos(id)`, `motivo_codigo varchar(50) NOT NULL`, `descripcion text`, `origen varchar(20) NOT NULL`, `actor_id uuid NULL FK perfiles(id)`, `created_at timestamptz NOT NULL`.
- Causa `SIN_REPARTIDORES_EN_AREA` activa reembolso automático simulado.
- Una cancelación por pedido, validada con estado y permisos.

### 16 `reembolsos`
`id uuid PK`, `pedido_id uuid NOT NULL UNIQUE FK pedidos(id)`, `cancelacion_id uuid NOT NULL UNIQUE FK cancelaciones(id)`, `motivo_codigo varchar(50) NOT NULL`, `monto numeric(12,2) NOT NULL CHECK (>=0)`, `automatico boolean NOT NULL`, `estado varchar(30) NOT NULL CHECK IN ('SIMULADO_PENDIENTE','SIMULADO_COMPLETADO','REVISION_MANUAL','REVISION_APROBADA','REVISION_RECHAZADA')`, `revisado_por uuid NULL FK perfiles(id)`, `created_at`, `updated_at`.
- Solo un reembolso/expediente por pedido y cancelación. Ningún movimiento financiero real.
- Operaciones idempotentes, aprobaciones solo ADMIN.

### 17 `notificaciones`
`id uuid PK`, `destinatario_id uuid NOT NULL FK perfiles(id)`, `pedido_id uuid NULL FK pedidos(id)`, `tipo varchar(40) NOT NULL`, `titulo varchar(140) NOT NULL`, `mensaje text NOT NULL`, `leida_en timestamptz NULL`, `created_at timestamptz NOT NULL`.
- Cliente/repartidor ve solo las propias. Se generan en funciones/acciones validadas. Realtime filtrado por destinatario.

### 18 `escenarios_demo`
`id uuid PK`, `codigo varchar(40) UNIQUE NOT NULL`, `nombre varchar(100) NOT NULL`, `descripcion text`, `configuracion jsonb NOT NULL DEFAULT '{}'::jsonb`, `activo boolean DEFAULT true`.
- Configuraciones sintéticas `NORMAL`, `ADVERTENCIA`, `BLOQUEO`, `RECUPERACION`, `EQUILIBRIO`, `SIN_REPARTIDORES`. No confiar en JSON para el estado de negocio real; solo parametriza simulaciones administradas.

### 19 `ejecuciones_demo`
`id uuid PK`, `escenario_id uuid NOT NULL FK escenarios_demo(id)`, `ejecutado_por uuid NOT NULL FK perfiles(id)`, `resultado jsonb`, `created_at timestamptz NOT NULL`.
- Historial de quién inició un escenario y cuándo. El reset de demo debe limitarse a datos marcados como sintéticos y nunca borrar cuentas ni pedidos de prueba reales de otros usuarios sin confirmación.

## 3. Relaciones principales
```text
auth.users 1—1 perfiles
perfiles(CLIENTE) 1—N direcciones
perfiles(CLIENTE) 1—N pedidos
perfiles(REPARTIDOR) 1—1 repartidores
zonas 1—N direcciones, restaurantes, repartidores, pedidos
restaurantes 1—N productos, pedidos, promociones
categorias 1—N productos
productos 1—N grupos_opciones 1—N opciones_producto
pedidos 1—N pedido_detalles N—1 productos
pedidos 1—N asignaciones N—1 repartidores
pedidos 1—N eventos_pedido
pedidos 1—0..1 cancelaciones 1—0..1 reembolsos
perfiles 1—N notificaciones
escenarios_demo 1—N ejecuciones_demo
```

## 4. Reglas críticas en funciones SQL transaccionales
### Confirmación de pedido
1. Exigir `auth.uid()` y rol CLIENTE; verificar que la dirección pertenece al cliente, restaurante activo, productos disponibles y zona coherente.
2. Recalcular precios, opciones, descuento, envío y total desde tablas servidor.
3. Bloquear fila `zonas` para serializar confirmaciones de la misma zona.
4. Calcular pedidos activos y repartidores disponibles; si cero repartidores, rechazar.
5. Si bloqueada, permitir desbloqueo **solo** si ratio actual `<4` y repartidores >0.
6. Si no bloqueada, mostrar advertencia si `4 < ratio_actual <=5`; **proyectar** `(activos+1)/disponibles`. Si proyectado `>5`, marcar bloqueada y **rechazar** la confirmación. **Importante:** si se desea conservar el cambio a `bloqueada` al rechazar, la función debe retornar resultado de negocio sin lanzar excepción que revierta la transacción.
7. Crear pedido/detalles, registrar evento y asignar repartidor elegible en la misma transacción, o devolver error controlado sin crear pedido.
8. Considerar clave de idempotencia por intento de confirmación para impedir duplicados por doble clic/reintento (recomendación: añadir `solicitud_id uuid UNIQUE` a `pedidos` y exigirlo en la función).
9. Recalcular capacidad tras cambios operativos; conservar histéresis.

### Asignación
1. Filtrar repartidores `activo AND disponible` en zona y con perfil REPARTIDOR activo.
2. Contar asignaciones vigentes de pedidos activos por repartidor.
3. Ordenar `carga ASC`, `distancia_ficticia ASC`, `id ASC`. Registrar carga/distancia/criterio.
4. Serializar asignaciones por zona (bloqueo de zona o advisory lock) para evitar carreras.
5. Si no hay elegibles, no crear asignación; en confirmación rechazar sin cobrar. Si la ausencia ocurre en pedido ya aceptado, cancelación controlada con causa apropiada.
6. El balance se mejora incrementalmente, pero no se puede garantizar diferencia <=1 cuando el simulador introduce cargas artificiales, repartidores cambian de disponibilidad o hay reasignaciones. Documentar limitación y medir solo elegibles.

### Estados
- `PENDIENTE → ASIGNADO → RECOGIDO → EN_CAMINO → ENTREGADO`.
- Cancelación antes de entrega según reglas explícitas (p. ej., cliente puede cancelar `PENDIENTE` o `ASIGNADO`; administrador gestiona incidencias posteriores).
- Al entregar/cancelar: cerrar asignación vigente, crear evento, notificación y recalcular zona.
- Repartidor solo modifica pedidos **actualmente asignados a él**.

### Cancelaciones y reembolsos
- Una cancelación por pedido (`UNIQUE(pedido_id)`), una devolución simulada por cancelación/pedido.
- `SIN_REPARTIDORES_EN_AREA`: `automatico=true`, `SIMULADO_COMPLETADO` o `SIMULADO_PENDIENTE` según animación de demo.
- Otros motivos: `REVISION_MANUAL`; admin resuelve. Reintentos no duplican.
- Registrar actor/origen/motivo/fecha en historial.

### Notificaciones y Realtime
- Insertar notificaciones dentro de las mismas transacciones o tras ellas mediante proceso controlado.
- Realtime en `pedidos`, `asignaciones`, `notificaciones` y, si hace falta, disponibilidad/capacidad. Suscripciones filtradas; RLS para cada usuario.
- Los clientes no deben poder suscribirse a pedidos ajenos.

## 5. RLS y autorización
- RLS en todas las tablas públicas; lectura anónima solo de catálogo público (`zonas` con columnas seguras mediante vista, `restaurantes`, `categorias`, `productos`, grupos/opciones, promociones).
- `perfiles`: usuario lee/edita sus datos **excepto rol/activo**; admin ve lo necesario.
- `direcciones`: propietario CRUD; admin lectura si necesaria para operación de pedido, minimizar exposición.
- `pedidos`/detalles/eventos: cliente solo propios; repartidor solo pedidos asignados; admin acceso operativo.
- `repartidores`: repartidor lee su ficha y modifica zona/disponibilidad **mediante RPC validada**; admin gestiona demo.
- `cancelaciones`, `reembolsos`: lectura del cliente propietario y admin; escritura solo mediante funciones.
- `notificaciones`: destinatario puede leer y marcar como leída; no crear arbitrariamente.
- `escenarios_demo`/`ejecuciones_demo`: solo admin invoca simulaciones.
- Funciones `SECURITY DEFINER` solo si imprescindibles, con `SET search_path` explícito, revocación de `EXECUTE` a `PUBLIC`, chequeos `auth.uid()`/rol y `GRANT` específico.
- Nunca poner service role/secret keys en el navegador. El selector de rol en localStorage es solo UX.

## 6. Índices, controles y seed
Índices recomendados:
- `pedidos(cliente_id, created_at DESC)`, `(zona_id, estado)`, `(restaurante_id)`, `UNIQUE(solicitud_id)`.
- `repartidores(zona_id, activo, disponible)`.
- `asignaciones(repartidor_id, terminada_en)`, `UNIQUE(pedido_id) WHERE terminada_en IS NULL`.
- `notificaciones(destinatario_id, created_at DESC)`, `eventos_pedido(pedido_id, created_at)`.
- `productos(restaurante_id, disponible)`, `direcciones(cliente_id)`.
- `UNIQUE(cancelaciones.pedido_id)`, `UNIQUE(reembolsos.pedido_id)`, `UNIQUE(reembolsos.cancelacion_id)`.

Datos ficticios: 3 zonas, 6 restaurantes, 4 categorías, 25–35 productos, opciones simples, 3–5 banners, 8–12 repartidores con **cuentas Auth reales de prueba** y rol autorizado, 1 admin con Auth, 2–3 clientes de prueba y pedidos históricos coherentes. La creación de cuentas Auth/roles debe hacerse por vía privilegiada y documentada, no con inserts arbitrarios en `auth.users`.

## 7. Pruebas obligatorias antes de frontend
1. Cliente anónimo puede leer catálogo, **no** crear pedidos ni editar operaciones.
2. Cliente autenticado solo ve sus direcciones/pedidos/notificaciones.
3. Cliente no puede promoverse a ADMIN/REPARTIDOR cambiando metadatos o `localStorage`.
4. Repartidor no puede cambiar zona con asignaciones activas; no puede actualizar pedidos ajenos.
5. Repartidor elige zona ficticia, disponible y recibe asignación.
6. Capacidad: `>4` advierte; `>5` bloquea; `=4` mantiene bloqueo; `<4` desbloquea.
7. Con 0 repartidores disponibles, no aceptar nuevos pedidos.
8. Dos confirmaciones concurrentes respetan capacidad; doble clic no duplica pedidos.
9. Asignación favorece menor carga; desempata por distancia; una asignación vigente por pedido.
10. Precio/opciones/totales se recalculan en BD.
11. Entrega/cancelación cierran asignación y recalculan capacidad.
12. Reembolso automático simulado solo por causa indicada, no duplicable; otras causas revisión manual.
13. Notificaciones y Realtime solo muestran información autorizada.
14. Simulador solo ejecutable por ADMIN; reinicio no destruye cuentas.

## 8. Instrucción a Codex
Generar **migraciones SQL versionadas**, RLS, RPC transaccionales, triggers, índices, seed y pruebas; **no ejecutar ni cambiar frontend hasta aprobación**. Explicar decisiones y advertir si una restricción del diseño resulta contradictoria. No introducir tablas extras sin justificar.

## 9. Decisiones técnicas que debe validar Codex antes de SQL
- Método de generar cuentas demo de repartidor/admin en Supabase Auth sin exponer credenciales.
- Cómo preservar la histéresis ante transacciones fallidas y eventos simultáneos.
- Cómo limitar el reset del simulador a registros marcados como demo (puede requerir `es_demo boolean` en pedidos y datos operativos).
- Si promociones se limitarán a banners o también aplicarán descuentos: **por defecto banners**.
- Confirmar la adaptación de RF-04 (cercanía) a prioridad RS-02 (carga) con el equipo académico.
