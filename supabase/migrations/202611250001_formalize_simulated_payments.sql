-- Fase 4.1: formalización de pagos simulados.
-- Preparada para revisión. No ejecutar automáticamente.
-- No se asume que los pedidos históricos hayan sido pagados.

alter table public.pedidos
  drop constraint if exists pedidos_metodo_pago_check;

alter table public.pedidos
  add column if not exists estado_pago varchar(30) not null default 'PENDIENTE',
  add column if not exists pagado_en timestamptz;

-- Los pedidos existentes quedan pendientes por falta de evidencia de cobro.
update public.pedidos
set estado_pago = 'PENDIENTE', pagado_en = null;

update public.pedidos
set estado_pago = 'CANCELADO_SIN_COBRO'
where estado = 'CANCELADO';

alter table public.pedidos
  add constraint pedidos_metodo_pago_check
    check (metodo_pago in ('EFECTIVO', 'TARJETA_SIMULADA')),
  add constraint pedidos_estado_pago_check
    check (estado_pago in ('PENDIENTE', 'PAGADO', 'REEMBOLSADO', 'CANCELADO_SIN_COBRO')),
  add constraint pedidos_pago_fecha_check
    check (pagado_en is null or estado_pago in ('PAGADO', 'REEMBOLSADO'));

-- Nueva firma transaccional. La firma anterior se conserva mediante un wrapper.
create or replace function public.confirmar_pedido(
  p_solicitud_id uuid,
  p_restaurante_id uuid,
  p_direccion_id uuid,
  p_items jsonb,
  p_metodo_pago text,
  p_monto_efectivo numeric default null,
  p_cambio_estimado numeric default null,
  p_instrucciones_entrega text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cliente uuid := auth.uid();
  v_p public.pedidos;
  v_direccion public.direcciones;
  v_restaurante public.restaurantes;
  v_item jsonb;
  v_producto public.productos;
  v_cantidad integer;
  v_subtotal numeric(12,2) := 0;
  v_linea numeric(12,2);
  v_cap record;
  v_metodo varchar(20) := upper(trim(coalesce(p_metodo_pago, '')));
  v_estado_pago varchar(30);
  v_pagado_en timestamptz;
  v_cambio numeric(12,2);
begin
  if v_cliente is null or public.mi_rol() <> 'CLIENTE' then
    raise exception 'AUTENTICACION_CLIENTE_REQUERIDA';
  end if;
  if p_solicitud_id is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'SOLICITUD_INVALIDA';
  end if;
  if v_metodo not in ('EFECTIVO', 'TARJETA_SIMULADA') then
    raise exception 'METODO_PAGO_INVALIDO';
  end if;

  select * into v_p from public.pedidos where solicitud_id = p_solicitud_id;
  if found then
    return jsonb_build_object('pedido_id', v_p.id, 'duplicado', true, 'estado_pago', v_p.estado_pago);
  end if;

  select * into v_direccion from public.direcciones where id = p_direccion_id and cliente_id = v_cliente;
  if not found then raise exception 'DIRECCION_NO_AUTORIZADA'; end if;
  select * into v_restaurante from public.restaurantes where id = p_restaurante_id and activo;
  if not found then raise exception 'RESTAURANTE_NO_DISPONIBLE'; end if;
  if v_direccion.zona_id is distinct from v_restaurante.zona_id then raise exception 'ZONA_INCOMPATIBLE'; end if;

  -- Serializa la decisión con la misma zona utilizada por el control logístico.
  perform pg_advisory_xact_lock(hashtextextended(v_direccion.zona_id::text, 0));
  select * into v_cap from public.capacidad_zona(v_direccion.zona_id, 1);
  if not v_cap.puede_aceptar then
    raise exception 'CAPACIDAD_NO_DISPONIBLE:%', case
      when v_cap.disponibles = 0 then 'SIN_REPARTIDORES'
      when v_cap.bloqueada then 'ZONA_BLOQUEADA'
      else 'CAPACIDAD_SUPERADA'
    end;
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_producto
    from public.productos
    where id = (v_item->>'producto_id')::uuid
      and restaurante_id = p_restaurante_id
      and disponible;
    if not found then raise exception 'PRODUCTO_NO_DISPONIBLE'; end if;
    v_cantidad := (v_item->>'cantidad')::integer;
    if v_cantidad is null or v_cantidad <= 0 then raise exception 'CANTIDAD_INVALIDA'; end if;
    v_linea := v_cantidad * v_producto.precio;
    v_subtotal := v_subtotal + v_linea;
  end loop;
  if v_subtotal <= 0 then raise exception 'CARRITO_VACIO'; end if;

  if v_metodo = 'EFECTIVO' then
    v_estado_pago := 'PENDIENTE';
    v_pagado_en := null;
    if p_monto_efectivo is not null and p_monto_efectivo < v_subtotal then
      raise exception 'MONTO_EFECTIVO_INSUFICIENTE';
    end if;
    v_cambio := case when p_monto_efectivo is null then p_cambio_estimado else round(p_monto_efectivo - v_subtotal, 2) end;
  else
    v_estado_pago := 'PAGADO';
    v_pagado_en := now();
    v_cambio := null;
  end if;

  insert into public.pedidos(
    solicitud_id, cliente_id, restaurante_id, zona_id, direccion_id,
    direccion_snapshot, estado, subtotal, costo_envio, total, eta_minutos,
    confirmado_en, metodo_pago, monto_efectivo, cambio_estimado,
    instrucciones_entrega, estado_pago, pagado_en
  ) values (
    p_solicitud_id, v_cliente, p_restaurante_id, v_direccion.zona_id,
    p_direccion_id, v_direccion.detalle, 'PENDIENTE_ACEPTACION', v_subtotal,
    0, v_subtotal, v_restaurante.tiempo_preparacion_min + 15, now(),
    v_metodo, p_monto_efectivo, v_cambio, p_instrucciones_entrega,
    v_estado_pago, v_pagado_en
  ) returning * into v_p;

  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_producto from public.productos where id = (v_item->>'producto_id')::uuid;
    v_cantidad := (v_item->>'cantidad')::integer;
    insert into public.pedido_detalles(
      pedido_id, producto_id, nombre_producto_snapshot, cantidad,
      precio_base_unitario, subtotal_linea, observaciones, opciones_snapshot
    ) values (
      v_p.id, v_producto.id, v_producto.nombre, v_cantidad, v_producto.precio,
      v_cantidad * v_producto.precio, v_item->>'observaciones',
      coalesce(v_item->'opciones', '[]'::jsonb)
    );
  end loop;

  insert into public.eventos_pedido(
    pedido_id, tipo_evento, estado_nuevo, actor_id, origen, detalle
  ) values (
    v_p.id, 'CONFIRMACION', 'PENDIENTE_ACEPTACION', v_cliente, 'CLIENTE',
    'Pedido creado con pago ' || v_estado_pago
  );

  return jsonb_build_object(
    'aceptado', true,
    'pedido_id', v_p.id,
    'estado', v_p.estado,
    'estado_pago', v_p.estado_pago,
    'metodo_pago', v_p.metodo_pago
  );
exception when unique_violation then
  select * into v_p from public.pedidos where solicitud_id = p_solicitud_id;
  if found then return jsonb_build_object('pedido_id', v_p.id, 'duplicado', true, 'estado_pago', v_p.estado_pago); end if;
  raise;
end;
$$;

-- Compatibilidad con clientes antiguos: no inventa un pago histórico ni efectivo cobrado.
create or replace function public.confirmar_pedido(
  p_solicitud_id uuid,
  p_restaurante_id uuid,
  p_direccion_id uuid,
  p_items jsonb
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.confirmar_pedido(
    p_solicitud_id, p_restaurante_id, p_direccion_id, p_items,
    'EFECTIVO', null, null, null
  );
$$;

-- El efectivo se cobra al completar la entrega. La transición sigue siendo atómica.
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
  if v_actor is null then raise exception 'AUTENTICACION_REQUERIDA'; end if;
  select p.* into v_pedido from public.pedidos p where p.id = p_pedido_id for update;
  if not found then raise exception 'PEDIDO_NO_ENCONTRADO'; end if;
  if public.es_admin() then v_origen := 'ADMIN';
  elsif exists (
    select 1 from public.asignaciones a
    join public.repartidores r on r.id = a.repartidor_id
    where a.pedido_id = p_pedido_id and a.terminada_en is null and r.perfil_id = v_actor
  ) then v_origen := 'REPARTIDOR';
  else raise exception 'PEDIDO_NO_AUTORIZADO'; end if;
  if not ((v_pedido.estado = 'ASIGNADO' and p_nuevo_estado = 'RECOGIDO')
       or (v_pedido.estado = 'RECOGIDO' and p_nuevo_estado = 'EN_CAMINO')
       or (v_pedido.estado = 'EN_CAMINO' and p_nuevo_estado = 'ENTREGADO')) then
    raise exception 'TRANSICION_INVALIDA';
  end if;
  v_estado_anterior := v_pedido.estado;
  update public.pedidos
  set estado = p_nuevo_estado,
      finalizado_en = case when p_nuevo_estado = 'ENTREGADO' then now() else finalizado_en end,
      estado_pago = case when p_nuevo_estado = 'ENTREGADO' and metodo_pago = 'EFECTIVO' and estado_pago = 'PENDIENTE' then 'PAGADO' else estado_pago end,
      pagado_en = case when p_nuevo_estado = 'ENTREGADO' and metodo_pago = 'EFECTIVO' and estado_pago = 'PENDIENTE' then now() else pagado_en end
  where id = p_pedido_id returning * into v_pedido;
  update public.asignaciones
  set terminada_en = case when p_nuevo_estado = 'ENTREGADO' then now() else terminada_en end,
      motivo_fin = case when p_nuevo_estado = 'ENTREGADO' then 'ENTREGADO' else motivo_fin end
  where pedido_id = p_pedido_id and terminada_en is null;
  insert into public.eventos_pedido(pedido_id, tipo_evento, estado_anterior, estado_nuevo, actor_id, origen, detalle)
  values (p_pedido_id, 'CAMBIO_ESTADO', v_estado_anterior, p_nuevo_estado, v_actor, v_origen, 'Estado de pago: ' || v_pedido.estado_pago);
  insert into public.notificaciones(destinatario_id, pedido_id, tipo, titulo, mensaje)
  values (v_pedido.cliente_id, p_pedido_id, 'ESTADO_PEDIDO', 'Estado actualizado', 'Tu pedido ahora está en estado ' || p_nuevo_estado || '.');
  perform public.actualizar_bloqueo_zona(v_pedido.zona_id);
  return v_pedido;
end;
$$;

-- Solo los pedidos pagados generan reembolso. Los no cobrados quedan cancelados sin cobro.
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
  v_reembolso public.reembolsos;
  v_pago_confirmado boolean;
begin
  select * into v_p from public.pedidos where id = p_pedido_id for update;
  if not found then raise exception 'PEDIDO_NO_ENCONTRADO'; end if;
  if p_motivo = 'SIN_REPARTIDORES_EN_AREA' and not public.es_admin() then
    raise exception 'CAUSA_SISTEMA_REQUIERE_OPERACION_AUTORIZADA';
  end if;
  if v_p.estado in ('ENTREGADO', 'CANCELADO') then
    return jsonb_build_object('cancelado', false, 'duplicado', v_p.estado = 'CANCELADO');
  end if;
  if public.es_admin() then v_origen := 'ADMIN';
  elsif v_p.cliente_id = v_actor and v_p.estado in ('PENDIENTE', 'PENDIENTE_ACEPTACION', 'ASIGNADO') then v_origen := 'CLIENTE';
  else raise exception 'CANCELACION_NO_AUTORIZADA'; end if;

  v_pago_confirmado := v_p.estado_pago = 'PAGADO';
  update public.pedidos
  set estado = 'CANCELADO', finalizado_en = now(),
      estado_pago = case when v_pago_confirmado then estado_pago else 'CANCELADO_SIN_COBRO' end
  where id = p_pedido_id;
  update public.asignaciones set terminada_en = now(), motivo_fin = 'CANCELADO'
  where pedido_id = p_pedido_id and terminada_en is null;
  insert into public.cancelaciones(pedido_id, motivo_codigo, descripcion, origen, actor_id)
  values (p_pedido_id, p_motivo, p_descripcion, v_origen, v_actor);

  if v_pago_confirmado and p_motivo = 'SIN_REPARTIDORES_EN_AREA' then
    insert into public.reembolsos(pedido_id, cancelacion_id, motivo_codigo, monto, automatico, estado)
    select p_pedido_id, c.id, p_motivo, v_p.total, true, 'SIMULADO_COMPLETADO'
    from public.cancelaciones c where c.pedido_id = p_pedido_id returning * into v_reembolso;
    update public.pedidos set estado_pago = 'REEMBOLSADO' where id = p_pedido_id;
  elsif v_pago_confirmado then
    insert into public.reembolsos(pedido_id, cancelacion_id, motivo_codigo, monto, automatico, estado)
    select p_pedido_id, c.id, p_motivo, v_p.total, false, 'REVISION_MANUAL'
    from public.cancelaciones c where c.pedido_id = p_pedido_id returning * into v_reembolso;
  end if;

  insert into public.eventos_pedido(pedido_id, tipo_evento, estado_anterior, estado_nuevo, actor_id, origen, detalle)
  values (p_pedido_id, 'CANCELACION', v_p.estado, 'CANCELADO', v_actor, v_origen,
          p_motivo || case when v_pago_confirmado then ' · pago confirmado' else ' · sin cobro' end);
  insert into public.notificaciones(destinatario_id, pedido_id, tipo, titulo, mensaje)
  values (v_p.cliente_id, p_pedido_id, 'CANCELACION', 'Pedido cancelado', 'Tu pedido fue cancelado.');
  perform public.actualizar_bloqueo_zona(v_p.zona_id);
  return jsonb_build_object(
    'cancelado', true,
    'reembolso_id', v_reembolso.id,
    'reembolso_estado', v_reembolso.estado,
    'pago_confirmado', v_pago_confirmado
  );
exception when unique_violation then
  return jsonb_build_object('cancelado', false, 'duplicado', true);
end;
$$;

-- La aprobación manual completa el reembolso y actualiza el estado formal de pago.
create or replace function public.resolver_reembolso(p_reembolso_id uuid, p_aprobar boolean)
returns public.reembolsos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reembolso public.reembolsos;
  v_actor uuid := auth.uid();
begin
  if v_actor is null or not public.es_admin() then
    raise exception 'SOLO_ADMIN puede resolver reembolsos';
  end if;

  update public.reembolsos
  set estado = case when p_aprobar then 'REVISION_APROBADA' else 'REVISION_RECHAZADA' end,
      revisado_por = v_actor,
      updated_at = now()
  where id = p_reembolso_id and estado = 'REVISION_MANUAL'
  returning * into v_reembolso;

  if not found then raise exception 'REEMBOLSO_NO_DISPONIBLE'; end if;

  if p_aprobar then
    update public.pedidos
    set estado_pago = 'REEMBOLSADO'
    where id = v_reembolso.pedido_id and estado_pago = 'PAGADO';
  end if;

  insert into public.notificaciones(destinatario_id, pedido_id, tipo, titulo, mensaje)
  select p.cliente_id, p.id, 'REEMBOLSO', 'Reembolso actualizado',
         case when p_aprobar then 'Tu reembolso fue aprobado.' else 'Tu solicitud de reembolso fue rechazada.' end
  from public.pedidos p where p.id = v_reembolso.pedido_id;

  return v_reembolso;
end;
$$;

revoke all on function public.confirmar_pedido(uuid, uuid, uuid, jsonb, text, numeric, numeric, text) from public;
revoke all on function public.confirmar_pedido(uuid, uuid, uuid, jsonb) from public;
revoke all on function public.actualizar_estado_pedido(uuid, text) from public;
revoke all on function public.cancelar_pedido(uuid, text, text) from public;
grant execute on function public.confirmar_pedido(uuid, uuid, uuid, jsonb, text, numeric, numeric, text) to authenticated;
grant execute on function public.confirmar_pedido(uuid, uuid, uuid, jsonb) to authenticated;
grant execute on function public.actualizar_estado_pedido(uuid, text) to authenticated;
grant execute on function public.cancelar_pedido(uuid, text, text) to authenticated;
revoke all on function public.resolver_reembolso(uuid, boolean) from public;
grant execute on function public.resolver_reembolso(uuid, boolean) to authenticated;
