-- PedidosYa MVP v2 - publicación Realtime
-- Las políticas RLS siguen siendo la barrera de autorización de cada suscripción.

alter table public.pedidos replica identity full;
alter table public.asignaciones replica identity full;
alter table public.notificaciones replica identity full;
alter table public.repartidores replica identity full;

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'pedidos') then
    alter publication supabase_realtime add table public.pedidos;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'asignaciones') then
    alter publication supabase_realtime add table public.asignaciones;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notificaciones') then
    alter publication supabase_realtime add table public.notificaciones;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'repartidores') then
    alter publication supabase_realtime add table public.repartidores;
  end if;
end;
$$;
