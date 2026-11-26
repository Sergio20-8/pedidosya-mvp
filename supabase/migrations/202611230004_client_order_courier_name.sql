-- Permite al cliente ver únicamente el nombre del repartidor asignado a su pedido.
-- No expone teléfono, rol ni otros datos del perfil.
create or replace function public.nombre_repartidor_pedido(p_pedido_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select pf.nombre
  from public.pedidos p
  join public.asignaciones a on a.pedido_id = p.id and a.terminada_en is null
  join public.repartidores r on r.id = a.repartidor_id
  join public.perfiles pf on pf.id = r.perfil_id
  where p.id = p_pedido_id
    and p.cliente_id = auth.uid()
  limit 1;
$$;

revoke all on function public.nombre_repartidor_pedido(uuid) from public;
grant execute on function public.nombre_repartidor_pedido(uuid) to authenticated;
