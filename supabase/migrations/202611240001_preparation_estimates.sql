-- Tiempo estimado de preparación del pedido.
-- Preparada para revisión; no ejecutar automáticamente.

alter table public.pedidos
  add column if not exists preparacion_minutos_estimados integer,
  add column if not exists preparacion_iniciada_en timestamptz,
  add column if not exists preparacion_lista_estimada_en timestamptz,
  add column if not exists preparacion_lista_en timestamptz;

alter table public.pedidos
  drop constraint if exists pedidos_preparacion_minutos_check;

alter table public.pedidos
  add constraint pedidos_preparacion_minutos_check
  check (preparacion_minutos_estimados is null or preparacion_minutos_estimados between 1 and 1440);

create or replace function public.aceptar_pedido(p_pedido_id uuid, p_preparacion_minutos integer)
returns public.pedidos
language plpgsql security definer set search_path = public as $$
declare
  v public.pedidos;
  old_state text;
begin
  if not public.es_admin() then raise exception 'ROL_NO_AUTORIZADO'; end if;
  if p_preparacion_minutos is null or p_preparacion_minutos < 1 or p_preparacion_minutos > 1440 then
    raise exception 'TIEMPO_PREPARACION_INVALIDO';
  end if;
  select * into v from public.pedidos where id = p_pedido_id for update;
  if v.estado <> 'PENDIENTE_ACEPTACION' then raise exception 'TRANSICION_INVALIDA'; end if;
  old_state := v.estado;
  update public.pedidos
    set estado = 'PREPARANDO',
        preparacion_minutos_estimados = p_preparacion_minutos,
        preparacion_iniciada_en = statement_timestamp(),
        preparacion_lista_estimada_en = statement_timestamp() + make_interval(mins => p_preparacion_minutos),
        preparacion_lista_en = null,
        updated_at = statement_timestamp()
    where id = p_pedido_id
    returning * into v;
  insert into public.eventos_pedido(pedido_id, tipo_evento, estado_anterior, estado_nuevo, actor_id, origen, detalle)
    values (v.id, 'CAMBIO_ESTADO', old_state, v.estado, auth.uid(), 'ADMIN', format('Preparación estimada en %s minutos', p_preparacion_minutos));
  insert into public.notificaciones(destinatario_id, pedido_id, tipo, titulo, mensaje)
    values (v.cliente_id, v.id, 'ESTADO_PEDIDO', 'Pedido aceptado', 'El restaurante está preparando tu pedido.');
  return v;
end; $$;

create or replace function public.actualizar_tiempo_preparacion(p_pedido_id uuid, p_minutos_restantes integer)
returns public.pedidos
language plpgsql security definer set search_path = public as $$
declare
  v public.pedidos;
  v_anterior timestamptz;
begin
  if not public.es_admin() then raise exception 'ROL_NO_AUTORIZADO'; end if;
  if p_minutos_restantes is null or p_minutos_restantes < 1 or p_minutos_restantes > 1440 then
    raise exception 'TIEMPO_PREPARACION_INVALIDO';
  end if;
  select * into v from public.pedidos where id = p_pedido_id for update;
  if v.estado <> 'PREPARANDO' then raise exception 'TRANSICION_INVALIDA'; end if;
  v_anterior := v.preparacion_lista_estimada_en;
  update public.pedidos
    set preparacion_minutos_estimados = p_minutos_restantes,
        preparacion_lista_estimada_en = statement_timestamp() + make_interval(mins => p_minutos_restantes),
        updated_at = statement_timestamp()
    where id = p_pedido_id
    returning * into v;
  insert into public.eventos_pedido(pedido_id, tipo_evento, estado_anterior, estado_nuevo, actor_id, origen, detalle)
    values (v.id, 'ACTUALIZACION_PREPARACION', v.estado, v.estado, auth.uid(), 'ADMIN', format('Tiempo actualizado a %s minutos; anterior: %s', p_minutos_restantes, coalesce(v_anterior::text, 'sin estimación')));
  insert into public.notificaciones(destinatario_id, pedido_id, tipo, titulo, mensaje)
    values (v.cliente_id, v.id, 'ESTADO_PEDIDO', 'Tiempo de preparación actualizado', 'El restaurante actualizó el tiempo estimado de tu pedido.');
  return v;
end; $$;

create or replace function public.marcar_pedido_listo(p_pedido_id uuid) returns public.pedidos
language plpgsql security definer set search_path = public as $$
declare v public.pedidos;
begin
  if not public.es_admin() then raise exception 'ROL_NO_AUTORIZADO'; end if;
  update public.pedidos set estado='LISTO_PARA_RECOGER', preparacion_lista_en=coalesce(preparacion_lista_en, statement_timestamp()), updated_at=statement_timestamp() where id=p_pedido_id and estado='PREPARANDO' returning * into v;
  if not found then raise exception 'TRANSICION_INVALIDA'; end if;
  insert into public.eventos_pedido(pedido_id,tipo_evento,estado_anterior,estado_nuevo,actor_id,origen) values (v.id,'CAMBIO_ESTADO','PREPARANDO',v.estado,auth.uid(),'ADMIN'); return v;
end; $$;

grant execute on function public.aceptar_pedido(uuid, integer), public.actualizar_tiempo_preparacion(uuid, integer), public.marcar_pedido_listo(uuid) to authenticated;
