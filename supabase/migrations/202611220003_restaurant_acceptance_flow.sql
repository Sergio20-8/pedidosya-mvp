-- Flujo explícito: cliente confirma -> restaurante acepta/prepara -> listo ->
-- admin asigna repartidor. No ejecutar sin autorización.

alter table public.pedidos drop constraint if exists pedidos_estado_check;
alter table public.pedidos add constraint pedidos_estado_check check (estado in (
  'PENDIENTE_ACEPTACION','PREPARANDO','LISTO_PARA_RECOGER',
  'PENDIENTE','ASIGNADO','RECOGIDO','EN_CAMINO','ENTREGADO','CANCELADO'
));

create or replace function public.confirmar_pedido(p_solicitud_id uuid, p_restaurante_id uuid, p_direccion_id uuid, p_items jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_cliente uuid := auth.uid(); v_p public.pedidos; v_direccion public.direcciones; v_restaurante public.restaurantes;
  v_item jsonb; v_producto public.productos; v_cantidad integer; v_subtotal numeric(12,2) := 0; v_linea numeric(12,2);
begin
  if v_cliente is null or public.mi_rol() <> 'CLIENTE' then raise exception 'AUTENTICACION_CLIENTE_REQUERIDA'; end if;
  if p_solicitud_id is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'SOLICITUD_INVALIDA'; end if;
  select * into v_p from public.pedidos where solicitud_id = p_solicitud_id;
  if found then return jsonb_build_object('pedido_id', v_p.id, 'duplicado', true); end if;
  select * into v_direccion from public.direcciones where id = p_direccion_id and cliente_id = v_cliente;
  if not found then raise exception 'DIRECCION_NO_AUTORIZADA'; end if;
  select * into v_restaurante from public.restaurantes where id = p_restaurante_id and activo;
  if not found then raise exception 'RESTAURANTE_NO_DISPONIBLE'; end if;
  if v_direccion.zona_id is distinct from v_restaurante.zona_id then raise exception 'ZONA_INCOMPATIBLE'; end if;
  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_producto from public.productos where id = (v_item->>'producto_id')::uuid and restaurante_id = p_restaurante_id and disponible;
    if not found then raise exception 'PRODUCTO_NO_DISPONIBLE'; end if;
    v_cantidad := (v_item->>'cantidad')::integer;
    if v_cantidad is null or v_cantidad <= 0 then raise exception 'CANTIDAD_INVALIDA'; end if;
    v_linea := v_cantidad * v_producto.precio; v_subtotal := v_subtotal + v_linea;
  end loop;
  if v_subtotal <= 0 then raise exception 'CARRITO_VACIO'; end if;
  insert into public.pedidos(solicitud_id, cliente_id, restaurante_id, zona_id, direccion_id, direccion_snapshot, estado, subtotal, costo_envio, total, eta_minutos, confirmado_en)
    values (p_solicitud_id, v_cliente, p_restaurante_id, v_restaurante.zona_id, p_direccion_id, v_direccion.detalle, 'PENDIENTE_ACEPTACION', v_subtotal, 0, v_subtotal, v_restaurante.tiempo_preparacion_min + 15, now()) returning * into v_p;
  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_producto from public.productos where id = (v_item->>'producto_id')::uuid;
    v_cantidad := (v_item->>'cantidad')::integer;
    insert into public.pedido_detalles(pedido_id, producto_id, nombre_producto_snapshot, cantidad, precio_base_unitario, subtotal_linea, observaciones, opciones_snapshot)
      values (v_p.id, v_producto.id, v_producto.nombre, v_cantidad, v_producto.precio, v_cantidad * v_producto.precio, v_item->>'observaciones', coalesce(v_item->'opciones','[]'::jsonb));
  end loop;
  insert into public.eventos_pedido(pedido_id, tipo_evento, estado_nuevo, actor_id, origen, detalle) values (v_p.id, 'CONFIRMACION', 'PENDIENTE_ACEPTACION', v_cliente, 'CLIENTE', 'Pedido pendiente de aceptación del restaurante');
  return jsonb_build_object('aceptado', true, 'pedido_id', v_p.id, 'estado', v_p.estado);
exception when unique_violation then
  select * into v_p from public.pedidos where solicitud_id = p_solicitud_id;
  if found then return jsonb_build_object('pedido_id', v_p.id, 'duplicado', true); end if; raise;
end; $$;

create or replace function public.aceptar_pedido(p_pedido_id uuid) returns public.pedidos
language plpgsql security definer set search_path = public as $$
declare v public.pedidos; old_state text;
begin
  if not public.es_admin() then raise exception 'ROL_NO_AUTORIZADO'; end if;
  select * into v from public.pedidos where id = p_pedido_id for update;
  if v.estado <> 'PENDIENTE_ACEPTACION' then raise exception 'TRANSICION_INVALIDA'; end if;
  old_state := v.estado; update public.pedidos set estado='PREPARANDO' where id=p_pedido_id returning * into v;
  insert into public.eventos_pedido(pedido_id,tipo_evento,estado_anterior,estado_nuevo,actor_id,origen) values (v.id,'CAMBIO_ESTADO',old_state,v.estado,auth.uid(),'ADMIN');
  insert into public.notificaciones(destinatario_id,pedido_id,tipo,titulo,mensaje) values (v.cliente_id,v.id,'ESTADO_PEDIDO','Pedido aceptado','El restaurante está preparando tu pedido.'); return v;
end; $$;

create or replace function public.marcar_pedido_listo(p_pedido_id uuid) returns public.pedidos
language plpgsql security definer set search_path = public as $$
declare v public.pedidos;
begin
  if not public.es_admin() then raise exception 'ROL_NO_AUTORIZADO'; end if;
  update public.pedidos set estado='LISTO_PARA_RECOGER' where id=p_pedido_id and estado='PREPARANDO' returning * into v;
  if not found then raise exception 'TRANSICION_INVALIDA'; end if;
  insert into public.eventos_pedido(pedido_id,tipo_evento,estado_anterior,estado_nuevo,actor_id,origen) values (v.id,'CAMBIO_ESTADO','PREPARANDO',v.estado,auth.uid(),'ADMIN'); return v;
end; $$;

create or replace function public.asignar_repartidor_admin(p_pedido_id uuid) returns public.pedidos
language plpgsql security definer set search_path = public as $$
declare v public.pedidos; r public.repartidores; carga integer; distancia numeric; restaurante public.restaurantes;
begin
  if not public.es_admin() then raise exception 'ROL_NO_AUTORIZADO'; end if;
  select * into v from public.pedidos where id=p_pedido_id for update;
  if v.estado <> 'LISTO_PARA_RECOGER' then raise exception 'PEDIDO_NO_LISTO'; end if;
  select * into restaurante from public.restaurantes where id=v.restaurante_id;
  select r0.* into r
    from public.repartidores r0 join public.perfiles f on f.id=r0.perfil_id
    where r0.zona_id=v.zona_id and r0.activo and r0.disponible and f.rol='REPARTIDOR' and f.activo
      and not exists (select 1 from public.asignaciones ax where ax.pedido_id=v.id and ax.terminada_en is null)
    order by (select count(*) from public.asignaciones ax where ax.repartidor_id=r0.id and ax.terminada_en is null), r0.id limit 1;
  if r.id is not null then
    select count(*) into carga from public.asignaciones ax where ax.repartidor_id=r.id and ax.terminada_en is null;
    distancia := coalesce(sqrt(power(coalesce(r.pos_x,0)-coalesce(restaurante.pos_x,0),2)+power(coalesce(r.pos_y,0)-coalesce(restaurante.pos_y,0),2)),0);
  end if;
  if r.id is null then raise exception 'SIN_REPARTIDOR_ELEGIBLE'; end if;
  insert into public.asignaciones(pedido_id,repartidor_id,distancia_simulada,carga_antes) values (v.id,r.id,distancia,carga);
  update public.pedidos set estado='ASIGNADO' where id=v.id returning * into v;
  insert into public.eventos_pedido(pedido_id,tipo_evento,estado_anterior,estado_nuevo,actor_id,origen,detalle) values (v.id,'ASIGNACION','LISTO_PARA_RECOGER','ASIGNADO',auth.uid(),'ADMIN','Asignación manual desde panel ADMIN');
  return v;
end; $$;

grant execute on function public.aceptar_pedido(uuid), public.marcar_pedido_listo(uuid), public.asignar_repartidor_admin(uuid) to authenticated;
