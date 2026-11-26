-- Devuelve únicamente nombre y ubicación del repartidor asignado al dueño del pedido.
create or replace function public.ubicacion_repartidor_pedido(p_pedido_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'nombre', pf.nombre,
    'pos_x', r.pos_x,
    'pos_y', r.pos_y
  )
  from public.pedidos p
  join public.asignaciones a on a.pedido_id = p.id and a.terminada_en is null
  join public.repartidores r on r.id = a.repartidor_id
  join public.perfiles pf on pf.id = r.perfil_id
  where p.id = p_pedido_id
    and p.cliente_id = auth.uid()
  limit 1;
$$;

revoke all on function public.ubicacion_repartidor_pedido(uuid) from public;
grant execute on function public.ubicacion_repartidor_pedido(uuid) to authenticated;
