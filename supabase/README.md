# Migraciones Supabase — PedidosYa MVP v2

Orden de aplicación:

1. `202611180001_schema.sql`: extensión, 19 tablas, claves, restricciones, índices, triggers y perfil automático desde Auth.
2. `202611180002_authorization_rls.sql`: funciones de rol, RLS y grants mínimos.
3. `202611180003_business_functions.sql`: capacidad, selección de zona, disponibilidad, confirmación idempotente, estados, cancelación y reembolsos.
4. `202611180004_realtime.sql`: publicación Realtime para pedidos, asignaciones, notificaciones y repartidores.

Después de las migraciones, ejecutar `supabase/seed/202611180005_demo_seed.sql` desde el SQL Editor o como seed controlado. El seed es idempotente para las filas de catálogo y escenarios; no crea usuarios.

No incluye seed ni cuentas Auth reales. Las cuentas y la promoción de roles deben crearse posteriormente mediante Supabase Auth y una operación administrativa controlada.

## Aplicación posterior

Con Supabase CLI enlazado al proyecto correcto:

```bash
supabase link --project-ref <PROJECT_REF>
supabase db push
```

Para cargar el seed posteriormente:

```bash
supabase db query --file supabase/seed/202611180005_demo_seed.sql
```

Antes de aplicar en producción, ejecutar en un proyecto/branch de desarrollo y revisar las pruebas de concurrencia, RLS y RPC. No usar la clave publishable para aplicar migraciones; la CLI usa el acceso administrativo local configurado por el operador.
