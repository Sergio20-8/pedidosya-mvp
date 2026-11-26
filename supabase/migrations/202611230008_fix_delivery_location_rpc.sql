-- Corrige la ambigüedad entre el alias de repartidores y la variable PL/pgSQL.
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
  v_asignacion public.asignaciones;
  v_repartidor public.repartidores;
  v_pedido public.pedidos;
begin
  if public.mi_rol() <> 'REPARTIDOR' then raise exception 'ROL_NO_AUTORIZADO'; end if;
  if p_pos_x is null or p_pos_x < -180 or p_pos_x > 180 or p_pos_y is null or p_pos_y < -90 or p_pos_y > 90 then
    raise exception 'UBICACION_INVALIDA';
  end if;
  select * into v_pedido from public.pedidos where id = p_pedido_id;
  if not found or v_pedido.estado not in ('ASIGNADO', 'RECOGIDO', 'EN_CAMINO') then raise exception 'ENTREGA_NO_ACTIVA'; end if;
  select rep.* into v_repartidor
    from public.repartidores as rep
    join public.asignaciones as asign on asign.repartidor_id = rep.id
    where asign.pedido_id = p_pedido_id
      and asign.terminada_en is null
      and rep.perfil_id = auth.uid()
    for update of rep;
  if not found then raise exception 'REPARTIDOR_NO_ASIGNADO'; end if;
  update public.asignaciones
    set ubicacion_pos_x = p_pos_x,
        ubicacion_pos_y = p_pos_y,
        ubicacion_actualizada_en = now()
    where pedido_id = p_pedido_id
      and repartidor_id = v_repartidor.id
      and terminada_en is null
    returning * into v_asignacion;
  update public.repartidores
    set pos_x = p_pos_x, pos_y = p_pos_y, updated_at = now()
    where id = v_repartidor.id;
  return v_asignacion;
end;
$$;

revoke all on function public.actualizar_ubicacion_entrega(uuid, numeric, numeric) from public;
grant execute on function public.actualizar_ubicacion_entrega(uuid, numeric, numeric) to authenticated;
