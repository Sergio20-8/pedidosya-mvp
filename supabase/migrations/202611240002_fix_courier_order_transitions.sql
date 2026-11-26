-- Reafirma la transición atómica de estados para repartidores.
-- Permite confirmar recogida, iniciar entrega y marcar entrega sin modificar RLS.
create or replace function public.actualizar_estado_pedido(p_pedido_id uuid, p_nuevo_estado text)
returns public.pedidos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pedido public.pedidos;
  v_estado_anterior text;
  v_origen text;
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    raise exception 'AUTENTICACION_REQUERIDA';
  end if;

  select p.* into v_pedido
  from public.pedidos p
  where p.id = p_pedido_id
  for update;

  if not found then
    raise exception 'PEDIDO_NO_ENCONTRADO';
  end if;

  if public.es_admin() then
    v_origen := 'ADMIN';
  elsif exists (
    select 1
    from public.asignaciones a
    join public.repartidores r on r.id = a.repartidor_id
    where a.pedido_id = p_pedido_id
      and a.terminada_en is null
      and r.perfil_id = v_actor
  ) then
    v_origen := 'REPARTIDOR';
  else
    raise exception 'PEDIDO_NO_AUTORIZADO';
  end if;

  if not (
    (v_pedido.estado = 'ASIGNADO' and p_nuevo_estado = 'RECOGIDO')
    or (v_pedido.estado = 'RECOGIDO' and p_nuevo_estado = 'EN_CAMINO')
    or (v_pedido.estado = 'EN_CAMINO' and p_nuevo_estado = 'ENTREGADO')
  ) then
    raise exception 'TRANSICION_INVALIDA';
  end if;

  v_estado_anterior := v_pedido.estado;

  update public.pedidos
  set estado = p_nuevo_estado,
      finalizado_en = case when p_nuevo_estado = 'ENTREGADO' then now() else finalizado_en end
  where id = p_pedido_id
  returning * into v_pedido;

  update public.asignaciones
  set terminada_en = case when p_nuevo_estado = 'ENTREGADO' then now() else terminada_en end,
      motivo_fin = case when p_nuevo_estado = 'ENTREGADO' then 'ENTREGADO' else motivo_fin end
  where pedido_id = p_pedido_id
    and terminada_en is null;

  insert into public.eventos_pedido(
    pedido_id, tipo_evento, estado_anterior, estado_nuevo, actor_id, origen
  ) values (
    p_pedido_id, 'CAMBIO_ESTADO', v_estado_anterior, p_nuevo_estado, v_actor, v_origen
  );

  insert into public.notificaciones(
    destinatario_id, pedido_id, tipo, titulo, mensaje
  ) values (
    v_pedido.cliente_id,
    p_pedido_id,
    'ESTADO_PEDIDO',
    'Estado actualizado',
    'Tu pedido ahora está en estado ' || p_nuevo_estado || '.'
  );

  perform public.actualizar_bloqueo_zona(v_pedido.zona_id);
  return v_pedido;
end;
$$;

revoke all on function public.actualizar_estado_pedido(uuid, text) from public;
grant execute on function public.actualizar_estado_pedido(uuid, text) to authenticated;
