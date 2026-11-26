-- Última ubicación manual por entrega activa.
alter table public.asignaciones
  add column if not exists ubicacion_pos_x numeric(10,3),
  add column if not exists ubicacion_pos_y numeric(10,3),
  add column if not exists ubicacion_actualizada_en timestamptz;

create index if not exists asignaciones_ubicacion_actualizada_idx
  on public.asignaciones(pedido_id, ubicacion_actualizada_en desc);

create or replace function public.actualizar_ubicacion_entrega(
  p_pedido_id uuid,
  p_pos_x numeric,
  p_pos_y numeric
)
returns public.asignaciones
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.asignaciones;
  r public.repartidores;
  p public.pedidos;
begin
  if public.mi_rol() <> 'REPARTIDOR' then raise exception 'ROL_NO_AUTORIZADO'; end if;
  if p_pos_x is null or p_pos_x < -180 or p_pos_x > 180 or p_pos_y is null or p_pos_y < -90 or p_pos_y > 90 then
    raise exception 'UBICACION_INVALIDA';
  end if;
  select * into p from public.pedidos where id = p_pedido_id;
  if not found or p.estado not in ('ASIGNADO', 'RECOGIDO', 'EN_CAMINO') then raise exception 'ENTREGA_NO_ACTIVA'; end if;
  select r.* into r
    from public.repartidores r
    join public.asignaciones a on a.repartidor_id = r.id
    where a.pedido_id = p_pedido_id and a.terminada_en is null and r.perfil_id = auth.uid()
    for update;
  if not found then raise exception 'REPARTIDOR_NO_ASIGNADO'; end if;
  update public.asignaciones
    set ubicacion_pos_x = p_pos_x, ubicacion_pos_y = p_pos_y, ubicacion_actualizada_en = now()
    where pedido_id = p_pedido_id and repartidor_id = r.id and terminada_en is null
    returning * into v;
  update public.repartidores set pos_x = p_pos_x, pos_y = p_pos_y, updated_at = now() where id = r.id;
  return v;
end;
$$;

revoke all on function public.actualizar_ubicacion_entrega(uuid, numeric, numeric) from public;
grant execute on function public.actualizar_ubicacion_entrega(uuid, numeric, numeric) to authenticated;

create or replace function public.ubicacion_repartidor_pedido(p_pedido_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'nombre', pf.nombre,
    'pos_x', coalesce(a.ubicacion_pos_x, r.pos_x),
    'pos_y', coalesce(a.ubicacion_pos_y, r.pos_y),
    'actualizada_en', coalesce(a.ubicacion_actualizada_en, r.updated_at)
  )
  from public.pedidos p
  join public.asignaciones a on a.pedido_id = p.id and a.terminada_en is null
  join public.repartidores r on r.id = a.repartidor_id
  join public.perfiles pf on pf.id = r.perfil_id
  where p.id = p_pedido_id and p.cliente_id = auth.uid()
  limit 1;
$$;
