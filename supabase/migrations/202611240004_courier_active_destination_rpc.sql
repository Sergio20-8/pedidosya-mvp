-- Devuelve el destino únicamente al repartidor asignado a una entrega activa.
create or replace function public.destino_entrega_repartidor(p_pedido_id uuid)
returns table (
  id uuid,
  detalle text,
  referencia text,
  latitud numeric,
  longitud numeric,
  zona_nombre text
)
language sql
stable
security definer
set search_path = public
as $$
  select d.id, d.detalle, d.referencia, d.latitud, d.longitud, z.nombre
  from public.direcciones d
  join public.pedidos p on p.direccion_id = d.id
  left join public.zonas z on z.id = d.zona_id
  where p.id = p_pedido_id
    and p.estado in ('ASIGNADO', 'RECOGIDO', 'EN_CAMINO')
    and public.pedido_asignado_al_repartidor(p.id);
$$;

revoke all on function public.destino_entrega_repartidor(uuid) from public;
grant execute on function public.destino_entrega_repartidor(uuid) to authenticated;
