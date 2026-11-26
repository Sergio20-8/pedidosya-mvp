-- Fase 4.2: reglas de cancelación por rol y motivo.
-- Preparada para revisión. No ejecutar sin autorización.

create or replace function public.cancelar_pedido(p_pedido_id uuid, p_motivo text, p_descripcion text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_p public.pedidos;
  v_actor uuid := auth.uid();
  v_origen text;
  v_motivo text := upper(trim(coalesce(p_motivo, '')));
  v_descripcion text := nullif(trim(coalesce(p_descripcion, '')), '');
  v_reembolso public.reembolsos;
  v_pago_confirmado boolean;
begin
  select * into v_p from public.pedidos where id = p_pedido_id for update;
  if not found then raise exception 'PEDIDO_NO_ENCONTRADO'; end if;
  if v_actor is null then raise exception 'AUTENTICACION_REQUERIDA'; end if;
  if v_p.estado in ('ENTREGADO', 'CANCELADO') then
    return jsonb_build_object('cancelado', false, 'duplicado', v_p.estado = 'CANCELADO');
  end if;
  if v_motivo = 'OTRO' and v_descripcion is null then
    raise exception 'DESCRIPCION_REQUERIDA';
  end if;

  if public.es_admin() then
    if v_motivo not in (
      'SIN_REPARTIDORES_EN_AREA', 'RESTAURANTE_RECHAZA',
      'PRODUCTOS_NO_DISPONIBLES', 'PROBLEMAS_DE_ENTREGA',
      'SOLICITUD_CLIENTE', 'OTRO'
    ) then raise exception 'MOTIVO_CANCELACION_INVALIDO'; end if;
    v_origen := 'ADMIN';
  elsif v_p.cliente_id = v_actor then
    if v_p.estado <> 'PENDIENTE_ACEPTACION' then
      raise exception 'CANCELACION_NO_AUTORIZADA';
    end if;
    if v_motivo not in (
      'CAMBIO_DE_OPINION', 'ERROR_EN_PEDIDO',
      'DIRECCION_INCORRECTA', 'DEMORA_EN_PEDIDO', 'OTRO'
    ) then raise exception 'MOTIVO_CANCELACION_INVALIDO'; end if;
    v_origen := 'CLIENTE';
  else
    raise exception 'CANCELACION_NO_AUTORIZADA';
  end if;

  -- El pedido permanece bloqueado mientras se valida y cancela, evitando carrera
  -- con aceptación, asignación o una segunda solicitud de cancelación.
  v_pago_confirmado := v_p.estado_pago = 'PAGADO';
  update public.pedidos
  set estado = 'CANCELADO', finalizado_en = now(),
      estado_pago = case when v_pago_confirmado then estado_pago else 'CANCELADO_SIN_COBRO' end
  where id = p_pedido_id;

  update public.asignaciones
  set terminada_en = now(), motivo_fin = 'CANCELADO'
  where pedido_id = p_pedido_id and terminada_en is null;

  insert into public.cancelaciones(pedido_id, motivo_codigo, descripcion, origen, actor_id)
  values (p_pedido_id, v_motivo, v_descripcion, v_origen, v_actor);

  if v_pago_confirmado and v_motivo = 'SIN_REPARTIDORES_EN_AREA' then
    insert into public.reembolsos(pedido_id, cancelacion_id, motivo_codigo, monto, automatico, estado)
    select p_pedido_id, c.id, v_motivo, v_p.total, true, 'SIMULADO_COMPLETADO'
    from public.cancelaciones c where c.pedido_id = p_pedido_id returning * into v_reembolso;
    update public.pedidos set estado_pago = 'REEMBOLSADO' where id = p_pedido_id;
  elsif v_pago_confirmado then
    insert into public.reembolsos(pedido_id, cancelacion_id, motivo_codigo, monto, automatico, estado)
    select p_pedido_id, c.id, v_motivo, v_p.total, false, 'REVISION_MANUAL'
    from public.cancelaciones c where c.pedido_id = p_pedido_id returning * into v_reembolso;
  end if;

  insert into public.eventos_pedido(pedido_id, tipo_evento, estado_anterior, estado_nuevo, actor_id, origen, detalle)
  values (p_pedido_id, 'CANCELACION', v_p.estado, 'CANCELADO', v_actor, v_origen,
          v_motivo || case when v_pago_confirmado then ' · pago confirmado' else ' · sin cobro' end);
  insert into public.notificaciones(destinatario_id, pedido_id, tipo, titulo, mensaje)
  values (v_p.cliente_id, p_pedido_id, 'CANCELACION', 'Pedido cancelado', 'Tu pedido fue cancelado.');
  perform public.actualizar_bloqueo_zona(v_p.zona_id);

  return jsonb_build_object(
    'cancelado', true,
    'reembolso_id', v_reembolso.id,
    'reembolso_estado', v_reembolso.estado,
    'pago_confirmado', v_pago_confirmado,
    'motivo_codigo', v_motivo
  );
exception when unique_violation then
  return jsonb_build_object('cancelado', false, 'duplicado', true);
end;
$$;

revoke all on function public.cancelar_pedido(uuid, text, text) from public;
grant execute on function public.cancelar_pedido(uuid, text, text) to authenticated;
