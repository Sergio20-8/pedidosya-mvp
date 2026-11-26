-- Aceptación atómica de una entrega con la ubicación inicial elegida por el repartidor.
-- Conserva la RPC anterior de un parámetro para compatibilidad.
create or replace function public.aceptar_entrega_repartidor(
  p_pedido_id uuid,
  p_pos_x numeric,
  p_pos_y numeric
)
returns public.pedidos
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.pedidos;
  r public.repartidores;
  carga integer;
  distancia numeric;
  restaurante public.restaurantes;
begin
  if public.mi_rol() <> 'REPARTIDOR' then raise exception 'ROL_NO_AUTORIZADO'; end if;
  if p_pos_x is null or p_pos_x < -180 or p_pos_x > 180 or p_pos_y is null or p_pos_y < -90 or p_pos_y > 90 then
    raise exception 'UBICACION_INVALIDA';
  end if;
  select * into r from public.repartidores where perfil_id = auth.uid() for update;
  if not found or not r.activo or not r.disponible then raise exception 'REPARTIDOR_NO_DISPONIBLE'; end if;
  select * into v from public.pedidos where id = p_pedido_id for update;
  if not found or not v.solicitud_repartidor_publicada or v.estado <> 'LISTO_PARA_RECOGER' then raise exception 'SOLICITUD_NO_DISPONIBLE'; end if;
  if r.zona_id is distinct from v.zona_id then raise exception 'ZONA_NO_AUTORIZADA'; end if;
  if exists (select 1 from public.asignaciones where pedido_id = v.id and terminada_en is null) then raise exception 'SOLICITUD_YA_ACEPTADA'; end if;
  select * into restaurante from public.restaurantes where id = v.restaurante_id;
  select count(*) into carga from public.asignaciones where repartidor_id = r.id and terminada_en is null;
  distancia := coalesce(sqrt(power(p_pos_x - coalesce(restaurante.pos_x, p_pos_x), 2) + power(p_pos_y - coalesce(restaurante.pos_y, p_pos_y), 2)), 0);
  update public.repartidores set pos_x = p_pos_x, pos_y = p_pos_y, updated_at = now() where id = r.id;
  insert into public.asignaciones(pedido_id, repartidor_id, distancia_simulada, carga_antes) values (v.id, r.id, distancia, carga);
  update public.pedidos set estado = 'ASIGNADO', solicitud_repartidor_publicada = false where id = v.id returning * into v;
  insert into public.eventos_pedido(pedido_id, tipo_evento, estado_anterior, estado_nuevo, actor_id, origen, detalle) values (v.id, 'ASIGNACION', 'LISTO_PARA_RECOGER', 'ASIGNADO', auth.uid(), 'REPARTIDOR', 'Primer repartidor elegible que aceptó la solicitud con ubicación inicial seleccionada');
  insert into public.notificaciones(destinatario_id, pedido_id, tipo, titulo, mensaje) values (v.cliente_id, v.id, 'ASIGNACION', 'Repartidor asignado', 'Tu pedido ya tiene un repartidor asignado.');
  return v;
exception when unique_violation then raise exception 'SOLICITUD_YA_ACEPTADA';
end;
$$;

revoke all on function public.aceptar_entrega_repartidor(uuid, numeric, numeric) from public;
grant execute on function public.aceptar_entrega_repartidor(uuid, numeric, numeric) to authenticated;
