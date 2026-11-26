-- Evita la recursión entre las políticas de pedidos y asignaciones.
-- Las funciones leen con el propietario de la función, sin volver a evaluar
-- las políticas RLS de las tablas consultadas.

create or replace function public.pedido_asignado_al_repartidor(p_pedido_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.asignaciones a
    join public.repartidores r on r.id = a.repartidor_id
    where a.pedido_id = p_pedido_id
      and a.terminada_en is null
      and r.perfil_id = auth.uid()
  );
$$;

create or replace function public.pedido_es_del_usuario(p_pedido_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.pedidos p
    where p.id = p_pedido_id and p.cliente_id = auth.uid()
  );
$$;

revoke all on function public.pedido_asignado_al_repartidor(uuid) from public;
revoke all on function public.pedido_es_del_usuario(uuid) from public;
grant execute on function public.pedido_asignado_al_repartidor(uuid) to authenticated;
grant execute on function public.pedido_es_del_usuario(uuid) to authenticated;

drop policy if exists pedidos_owner_or_ops_select on public.pedidos;
create policy pedidos_owner_or_ops_select on public.pedidos
for select to authenticated
using (
  cliente_id = auth.uid()
  or public.es_admin()
  or public.pedido_asignado_al_repartidor(id)
);

drop policy if exists asignaciones_owner_or_ops_select on public.asignaciones;
create policy asignaciones_owner_or_ops_select on public.asignaciones
for select to authenticated
using (
  public.es_admin()
  or public.pedido_es_del_usuario(pedido_id)
  or exists (
    select 1 from public.repartidores r
    where r.id = asignaciones.repartidor_id and r.perfil_id = auth.uid()
  )
);

