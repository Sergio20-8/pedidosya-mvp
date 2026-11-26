-- PedidosYa MVP v2 - funciones transaccionales
-- Todas las mutaciones de negocio pasan por RPC; no se concede INSERT/DELETE directo.

create or replace function public.capacidad_zona(p_zona_id uuid, p_incremento integer default 0)
returns table (activos bigint, disponibles bigint, ratio numeric, advertencia boolean, bloqueada boolean, puede_aceptar boolean)
language plpgsql stable security definer set search_path = public
as $$
declare
  v_bloqueada boolean;
begin
  select z.bloqueada into v_bloqueada from public.zonas z where z.id = p_zona_id;
  if not found then raise exception 'ZONA_NO_ENCONTRADA'; end if;
  select count(*) into activos from public.pedidos p where p.zona_id = p_zona_id and p.estado in ('PENDIENTE','ASIGNADO','RECOGIDO','EN_CAMINO');
  select count(*) into disponibles from public.repartidores r join public.perfiles f on f.id = r.perfil_id
    where r.zona_id = p_zona_id and r.activo and r.disponible and f.rol = 'REPARTIDOR' and f.activo;
  ratio := case when disponibles = 0 then null else round(activos::numeric / disponibles, 4) end;
  advertencia := disponibles > 0 and ratio > 4 and ratio <= 5 and not v_bloqueada;
  bloqueada := v_bloqueada or disponibles = 0 or (disponibles > 0 and ((activos + p_incremento)::numeric / disponibles) > 5);
  puede_aceptar := disponibles > 0 and not v_bloqueada and ((activos + p_incremento)::numeric / disponibles) <= 5;
  return next;
end;
$$;

create or replace function public.actualizar_bloqueo_zona(p_zona_id uuid)
returns boolean
language plpgsql security definer set search_path = public
as $$
declare v_activos bigint; v_disponibles bigint; v_bloqueada boolean;
begin
  select bloqueada into v_bloqueada from public.zonas where id = p_zona_id for update;
  select count(*) into v_activos from public.pedidos where zona_id = p_zona_id and estado in ('PENDIENTE','ASIGNADO','RECOGIDO','EN_CAMINO');
  select count(*) into v_disponibles from public.repartidores r join public.perfiles f on f.id = r.perfil_id where r.zona_id = p_zona_id and r.activo and r.disponible and f.rol = 'REPARTIDOR' and f.activo;
  if v_disponibles = 0 or (v_activos::numeric / greatest(v_disponibles, 1)) > 5 then
    update public.zonas set bloqueada = true, bloqueada_desde = coalesce(bloqueada_desde, now()) where id = p_zona_id;
  elsif v_bloqueada and (v_activos::numeric / v_disponibles) < 4 then
    update public.zonas set bloqueada = false, bloqueada_desde = null where id = p_zona_id;
  end if;
  return (select bloqueada from public.zonas where id = p_zona_id);
end;
$$;

create or replace function public.seleccionar_zona_repartidor(p_zona_id uuid)
returns public.repartidores
language plpgsql security definer set search_path = public
as $$
declare v_repartidor public.repartidores; v_zona_anterior uuid;
begin
  if public.mi_rol() <> 'REPARTIDOR' then raise exception 'ROL_NO_AUTORIZADO'; end if;
  select r.* into v_repartidor from public.repartidores r where r.perfil_id = auth.uid() for update;
  v_zona_anterior := v_repartidor.zona_id;
  if exists (select 1 from public.asignaciones a where a.repartidor_id = v_repartidor.id and a.terminada_en is null) then raise exception 'TIENE_ASIGNACIONES_ACTIVAS'; end if;
  if not exists (select 1 from public.zonas where id = p_zona_id and activa) then raise exception 'ZONA_NO_DISPONIBLE'; end if;
  update public.repartidores set zona_id = p_zona_id where id = v_repartidor.id returning * into v_repartidor;
  if v_zona_anterior is not null then perform public.actualizar_bloqueo_zona(v_zona_anterior); end if;
  perform public.actualizar_bloqueo_zona(p_zona_id);
  return v_repartidor;
end;
$$;

create or replace function public.cambiar_disponibilidad_repartidor(p_disponible boolean)
returns public.repartidores
language plpgsql security definer set search_path = public
as $$
declare v_repartidor public.repartidores;
begin
  if public.mi_rol() <> 'REPARTIDOR' then raise exception 'ROL_NO_AUTORIZADO'; end if;
  select r.* into v_repartidor from public.repartidores r where r.perfil_id = auth.uid() for update;
  if not p_disponible and exists (select 1 from public.asignaciones where repartidor_id = v_repartidor.id and terminada_en is null) then raise exception 'TIENE_ASIGNACIONES_ACTIVAS'; end if;
  update public.repartidores set disponible = p_disponible where id = v_repartidor.id returning * into v_repartidor;
  perform public.actualizar_bloqueo_zona(v_repartidor.zona_id) where v_repartidor.zona_id is not null;
  return v_repartidor;
end;
$$;

create or replace function public.confirmar_pedido(p_solicitud_id uuid, p_restaurante_id uuid, p_direccion_id uuid, p_items jsonb)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_cliente uuid := auth.uid(); v_rol text; v_direccion public.direcciones; v_restaurante public.restaurantes; v_zona public.zonas;
  v_pedido public.pedidos; v_item jsonb; v_producto public.productos; v_grupo public.grupos_opciones; v_opcion public.opciones_producto;
  v_cantidad integer; v_base numeric(12,2); v_opciones numeric(12,2); v_subtotal numeric(12,2) := 0; v_linea numeric(12,2); v_activos bigint; v_disponibles bigint; v_repartidor public.repartidores; v_repartidor_id uuid; v_carga integer; v_distancia numeric(12,3); v_eta integer;
begin
  if v_cliente is null or public.mi_rol() <> 'CLIENTE' then raise exception 'AUTENTICACION_CLIENTE_REQUERIDA'; end if;
  if p_solicitud_id is null or p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'SOLICITUD_INVALIDA'; end if;
  select * into v_pedido from public.pedidos where solicitud_id = p_solicitud_id;
  if found then return jsonb_build_object('pedido_id', v_pedido.id, 'duplicado', true); end if;
  select * into v_direccion from public.direcciones where id = p_direccion_id and cliente_id = v_cliente;
  if not found then raise exception 'DIRECCION_NO_AUTORIZADA'; end if;
  select * into v_restaurante from public.restaurantes where id = p_restaurante_id and activo;
  if not found then raise exception 'RESTAURANTE_NO_DISPONIBLE'; end if;
  if v_direccion.zona_id is distinct from v_restaurante.zona_id then raise exception 'ZONA_INCOMPATIBLE'; end if;
  select * into v_zona from public.zonas where id = v_direccion.zona_id and activa for update;
  if not found then raise exception 'ZONA_NO_DISPONIBLE'; end if;
  select count(*) into v_activos from public.pedidos where zona_id = v_zona.id and estado in ('PENDIENTE','ASIGNADO','RECOGIDO','EN_CAMINO');
  select count(*) into v_disponibles from public.repartidores r join public.perfiles f on f.id = r.perfil_id where r.zona_id = v_zona.id and r.activo and r.disponible and f.rol = 'REPARTIDOR' and f.activo;
  if v_disponibles = 0 then update public.zonas set bloqueada = true, bloqueada_desde = coalesce(bloqueada_desde, now()) where id = v_zona.id; return jsonb_build_object('aceptado', false, 'codigo', 'SIN_REPARTIDORES', 'advertencia', false); end if;
  if v_zona.bloqueada and (v_activos::numeric / v_disponibles) < 4 then update public.zonas set bloqueada = false, bloqueada_desde = null where id = v_zona.id; v_zona.bloqueada := false; end if;
  if v_zona.bloqueada or ((v_activos + 1)::numeric / v_disponibles) > 5 then update public.zonas set bloqueada = true, bloqueada_desde = coalesce(bloqueada_desde, now()) where id = v_zona.id; return jsonb_build_object('aceptado', false, 'codigo', 'ZONA_BLOQUEADA', 'ratio_actual', round(v_activos::numeric / v_disponibles, 4)); end if;
  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_producto from public.productos where id = (v_item ->> 'producto_id')::uuid and restaurante_id = p_restaurante_id and disponible;
    if not found then raise exception 'PRODUCTO_NO_DISPONIBLE'; end if;
    if (v_item ? 'cantidad') is not true or (v_item ->> 'cantidad') !~ '^[0-9]+$' or (v_item ->> 'cantidad')::integer <= 0 then raise exception 'CANTIDAD_INVALIDA'; end if;
    v_cantidad := (v_item ->> 'cantidad')::integer; v_base := v_producto.precio; v_opciones := 0;
    if jsonb_typeof(coalesce(v_item -> 'opciones', '[]'::jsonb)) <> 'array' then raise exception 'OPCIONES_INVALIDAS'; end if;
    if (select count(*) from jsonb_array_elements_text(coalesce(v_item -> 'opciones', '[]'::jsonb))) <> (select count(distinct value) from jsonb_array_elements_text(coalesce(v_item -> 'opciones', '[]'::jsonb))) then raise exception 'OPCIONES_DUPLICADAS'; end if;
    if exists (select 1 from jsonb_array_elements_text(coalesce(v_item -> 'opciones', '[]'::jsonb)) x(value) where value !~* '^[0-9a-f-]{36}$') then raise exception 'OPCION_ID_INVALIDO'; end if;
    if exists (select 1 from jsonb_array_elements_text(coalesce(v_item -> 'opciones', '[]'::jsonb)) x(value) left join public.opciones_producto o on o.id = x.value::uuid and o.disponible left join public.grupos_opciones g on g.id = o.grupo_id and g.producto_id = v_producto.id where o.id is null) then raise exception 'OPCION_NO_DISPONIBLE_O_NO_PERTENECE'; end if;
    if exists (select 1 from public.grupos_opciones g where g.producto_id = v_producto.id and (select count(*) from jsonb_array_elements_text(coalesce(v_item -> 'opciones', '[]'::jsonb)) x(value) join public.opciones_producto o on o.id=x.value::uuid where o.grupo_id=g.id) < g.min_selecciones) then raise exception 'MIN_OPCIONES_NO_CUMPLIDO'; end if;
    if exists (select 1 from public.grupos_opciones g where g.producto_id = v_producto.id and (select count(*) from jsonb_array_elements_text(coalesce(v_item -> 'opciones', '[]'::jsonb)) x(value) join public.opciones_producto o on o.id=x.value::uuid where o.grupo_id=g.id) > g.max_selecciones) then raise exception 'MAX_OPCIONES_EXCEDIDO'; end if;
    for v_opcion in select o.* from public.opciones_producto o where o.id in (select value::uuid from jsonb_array_elements_text(coalesce(v_item -> 'opciones', '[]'::jsonb))) loop v_opciones := v_opciones + v_opcion.precio_extra; end loop;
    v_linea := v_cantidad * (v_base + v_opciones); v_subtotal := v_subtotal + v_linea;
  end loop;
  if v_subtotal <= 0 then raise exception 'CARRITO_VACIO'; end if;
  select r.id, count(a.id), coalesce(sqrt(power(coalesce(r.pos_x,0)-coalesce(v_restaurante.pos_x,0),2)+power(coalesce(r.pos_y,0)-coalesce(v_restaurante.pos_y,0),2)),0) into v_repartidor_id, v_carga, v_distancia
    from public.repartidores r join public.perfiles f on f.id = r.perfil_id left join public.asignaciones a on a.repartidor_id = r.id and a.terminada_en is null
    where r.zona_id = v_zona.id and r.activo and r.disponible and f.rol = 'REPARTIDOR' and f.activo group by r.id order by count(a.id), sqrt(power(coalesce(r.pos_x,0)-coalesce(v_restaurante.pos_x,0),2)+power(coalesce(r.pos_y,0)-coalesce(v_restaurante.pos_y,0),2)), r.id limit 1;
  if v_repartidor_id is null then raise exception 'SIN_REPARTIDOR_ELEGIBLE'; end if;
  select r.* into v_repartidor from public.repartidores r where r.id = v_repartidor_id;
  v_eta := v_restaurante.tiempo_preparacion_min + 15 + (v_distancia::integer);
  insert into public.pedidos(solicitud_id, cliente_id, restaurante_id, zona_id, direccion_id, direccion_snapshot, estado, subtotal, costo_envio, total, eta_minutos, confirmado_en)
    values (p_solicitud_id, v_cliente, p_restaurante_id, v_zona.id, p_direccion_id, v_direccion.detalle, 'ASIGNADO', v_subtotal, 0, v_subtotal, v_eta, now()) returning * into v_pedido;
  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_producto from public.productos where id = (v_item ->> 'producto_id')::uuid;
    v_cantidad := (v_item ->> 'cantidad')::integer; v_opciones := 0;
    for v_opcion in select o.* from public.opciones_producto o where o.id in (select value::uuid from jsonb_array_elements_text(coalesce(v_item -> 'opciones', '[]'::jsonb))) loop v_opciones := v_opciones + v_opcion.precio_extra; end loop;
    insert into public.pedido_detalles(pedido_id, producto_id, nombre_producto_snapshot, cantidad, precio_base_unitario, precio_opciones_unitario, subtotal_linea, observaciones, opciones_snapshot) values (v_pedido.id, v_producto.id, v_producto.nombre, v_cantidad, v_producto.precio, v_opciones, v_cantidad * (v_producto.precio + v_opciones), v_item ->> 'observaciones', coalesce(v_item -> 'opciones', '[]'::jsonb));
  end loop;
  insert into public.asignaciones(pedido_id, repartidor_id, distancia_simulada, carga_antes) values (v_pedido.id, v_repartidor.id, v_distancia, v_carga);
  insert into public.eventos_pedido(pedido_id, tipo_evento, estado_nuevo, actor_id, origen, detalle) values (v_pedido.id, 'CONFIRMACION', 'ASIGNADO', v_cliente, 'CLIENTE', 'Pedido confirmado y asignado automáticamente');
  insert into public.notificaciones(destinatario_id, pedido_id, tipo, titulo, mensaje) values (v_repartidor.perfil_id, v_pedido.id, 'ASIGNACION', 'Nuevo pedido asignado', 'Tienes un nuevo pedido asignado.');
  perform public.actualizar_bloqueo_zona(v_zona.id);
  return jsonb_build_object('aceptado', true, 'pedido_id', v_pedido.id, 'advertencia', v_activos > 4 * v_disponibles, 'ratio_actual', round(v_activos::numeric / v_disponibles, 4));
exception when unique_violation then
  select * into v_pedido from public.pedidos where solicitud_id = p_solicitud_id;
  if found then return jsonb_build_object('pedido_id', v_pedido.id, 'duplicado', true); end if;
  raise;
end;
$$;

create or replace function public.actualizar_estado_pedido(p_pedido_id uuid, p_nuevo_estado text)
returns public.pedidos
language plpgsql security definer set search_path = public
as $$
declare v_p public.pedidos; v_estado_anterior text; v_origen text; v_actor uuid := auth.uid();
begin
  select p.* into v_p from public.pedidos p where p.id = p_pedido_id for update;
  if not found then raise exception 'PEDIDO_NO_ENCONTRADO'; end if;
  if public.es_admin() then v_origen := 'ADMIN'; elsif exists (select 1 from public.asignaciones a join public.repartidores r on r.id=a.repartidor_id where a.pedido_id=p_pedido_id and a.terminada_en is null and r.perfil_id=v_actor) then v_origen := 'REPARTIDOR'; else raise exception 'PEDIDO_NO_AUTORIZADO'; end if;
  if not ((v_p.estado='ASIGNADO' and p_nuevo_estado='RECOGIDO') or (v_p.estado='RECOGIDO' and p_nuevo_estado='EN_CAMINO') or (v_p.estado='EN_CAMINO' and p_nuevo_estado='ENTREGADO')) then raise exception 'TRANSICION_INVALIDA'; end if;
  v_estado_anterior := v_p.estado;
  update public.pedidos set estado=p_nuevo_estado, finalizado_en=case when p_nuevo_estado='ENTREGADO' then now() else finalizado_en end where id=p_pedido_id returning * into v_p;
  update public.asignaciones set terminada_en=case when p_nuevo_estado='ENTREGADO' then now() else terminada_en end, motivo_fin=case when p_nuevo_estado='ENTREGADO' then 'ENTREGADO' else motivo_fin end where pedido_id=p_pedido_id and terminada_en is null;
  insert into public.eventos_pedido(pedido_id,tipo_evento,estado_anterior,estado_nuevo,actor_id,origen) values (p_pedido_id,'CAMBIO_ESTADO',v_estado_anterior,p_nuevo_estado,v_actor,v_origen);
  insert into public.notificaciones(destinatario_id,pedido_id,tipo,titulo,mensaje) values (v_p.cliente_id,p_pedido_id,'ESTADO_PEDIDO','Estado actualizado','Tu pedido ahora está en estado ' || p_nuevo_estado || '.');
  perform public.actualizar_bloqueo_zona(v_p.zona_id);
  return v_p;
end;
$$;

create or replace function public.cancelar_pedido(p_pedido_id uuid, p_motivo text, p_descripcion text default null)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare v_p public.pedidos; v_actor uuid := auth.uid(); v_origen text; v_reembolso public.reembolsos;
begin
  select * into v_p from public.pedidos where id=p_pedido_id for update;
  if not found then raise exception 'PEDIDO_NO_ENCONTRADO'; end if;
  if p_motivo = 'SIN_REPARTIDORES_EN_AREA' and not public.es_admin() then raise exception 'CAUSA_SISTEMA_REQUIERE_OPERACION_AUTORIZADA'; end if;
  if v_p.estado in ('ENTREGADO','CANCELADO') then return jsonb_build_object('cancelado', false, 'duplicado', v_p.estado='CANCELADO'); end if;
  if public.es_admin() then v_origen := 'ADMIN'; elsif v_p.cliente_id = v_actor and v_p.estado in ('PENDIENTE','ASIGNADO') then v_origen := 'CLIENTE'; else raise exception 'CANCELACION_NO_AUTORIZADA'; end if;
  update public.pedidos set estado='CANCELADO', finalizado_en=now() where id=p_pedido_id;
  update public.asignaciones set terminada_en=now(), motivo_fin='CANCELADO' where pedido_id=p_pedido_id and terminada_en is null;
  insert into public.cancelaciones(pedido_id,motivo_codigo,descripcion,origen,actor_id) values (p_pedido_id,p_motivo,p_descripcion,v_origen,v_actor);
  if p_motivo = 'SIN_REPARTIDORES_EN_AREA' then insert into public.reembolsos(pedido_id,cancelacion_id,motivo_codigo,monto,automatico,estado) select p_pedido_id,c.id,p_motivo,v_p.total,true,'SIMULADO_COMPLETADO' from public.cancelaciones c where c.pedido_id=p_pedido_id returning * into v_reembolso; else insert into public.reembolsos(pedido_id,cancelacion_id,motivo_codigo,monto,automatico,estado) select p_pedido_id,c.id,p_motivo,v_p.total,false,'REVISION_MANUAL' from public.cancelaciones c where c.pedido_id=p_pedido_id returning * into v_reembolso; end if;
  insert into public.eventos_pedido(pedido_id,tipo_evento,estado_anterior,estado_nuevo,actor_id,origen,detalle) values (p_pedido_id,'CANCELACION',v_p.estado,'CANCELADO',v_actor,v_origen,p_motivo);
  insert into public.notificaciones(destinatario_id,pedido_id,tipo,titulo,mensaje) values (v_p.cliente_id,p_pedido_id,'CANCELACION','Pedido cancelado','Tu pedido fue cancelado.');
  perform public.actualizar_bloqueo_zona(v_p.zona_id);
  return jsonb_build_object('cancelado',true,'reembolso_id',v_reembolso.id,'reembolso_estado',v_reembolso.estado);
exception when unique_violation then return jsonb_build_object('cancelado',false,'duplicado',true);
end;
$$;

create or replace function public.ejecutar_escenario_demo(p_codigo text, p_configuracion jsonb default '{}'::jsonb)
returns public.ejecuciones_demo
language plpgsql security definer set search_path = public
as $$
declare v_esc public.escenarios_demo; v_ejec public.ejecuciones_demo; v_zona uuid; v_restaurante uuid; v_cliente uuid := auth.uid(); v_n integer; v_pedido public.pedidos; v_repartidor public.repartidores; v_i integer;
begin
  if not public.es_admin() then raise exception 'ROL_NO_AUTORIZADO'; end if;
  select * into v_esc from public.escenarios_demo where codigo=p_codigo and activo;
  if not found then raise exception 'ESCENARIO_NO_ENCONTRADO'; end if;
  -- Los escenarios solo operan sobre repartidores/pedidos marcados es_demo.
  select coalesce((p_configuracion->>'zona_id')::uuid, (select zona_id from public.repartidores where es_demo and zona_id is not null limit 1), (select id from public.zonas where activa order by nombre limit 1)) into v_zona;
  select id into v_restaurante from public.restaurantes where zona_id=v_zona and activo order by nombre limit 1;
  if v_restaurante is null then raise exception 'ESCENARIO_SIN_RESTAURANTE'; end if;
  delete from public.notificaciones where pedido_id in (select id from public.pedidos where es_demo);
  delete from public.reembolsos where pedido_id in (select id from public.pedidos where es_demo);
  delete from public.cancelaciones where pedido_id in (select id from public.pedidos where es_demo);
  delete from public.eventos_pedido where pedido_id in (select id from public.pedidos where es_demo);
  delete from public.asignaciones where pedido_id in (select id from public.pedidos where es_demo);
  delete from public.pedido_detalles where pedido_id in (select id from public.pedidos where es_demo);
  delete from public.pedidos where es_demo;
  update public.repartidores set zona_id=v_zona, disponible=false where es_demo;
  if p_codigo = 'SIN_REPARTIDORES' then
    null;
  elsif p_codigo = 'ADVERTENCIA' then
    update public.repartidores set disponible=true where es_demo and id=(select id from public.repartidores where es_demo order by id limit 1);
    v_n := 5;
  elsif p_codigo = 'BLOQUEO' then
    update public.repartidores set disponible=true where es_demo and id=(select id from public.repartidores where es_demo order by id limit 1);
    v_n := 6;
  elsif p_codigo = 'RECUPERACION' then
    update public.repartidores set disponible=true where es_demo and id=(select id from public.repartidores where es_demo order by id limit 1);
    v_n := 3;
  elsif p_codigo = 'EQUILIBRIO' then
    update public.repartidores set disponible=true where es_demo;
    v_n := greatest(2, (select count(*)::integer from public.repartidores where es_demo and zona_id=v_zona) * 2);
  elsif p_codigo = 'NORMAL' then
    update public.repartidores set disponible=true where es_demo;
    v_n := 1;
  else
    raise exception 'ESCENARIO_NO_IMPLEMENTADO';
  end if;
  for v_i in 1..coalesce(v_n,0) loop
    insert into public.pedidos(solicitud_id,cliente_id,restaurante_id,zona_id,direccion_snapshot,estado,subtotal,costo_envio,total,eta_minutos,confirmado_en,es_demo)
      values (gen_random_uuid(),v_cliente,v_restaurante,v_zona,'Dirección ficticia del escenario','PENDIENTE',10,0,10,30,now(),true) returning * into v_pedido;
  end loop;
  if p_codigo = 'EQUILIBRIO' then
    for v_pedido in select * from public.pedidos where es_demo order by created_at loop
      select r.* into v_repartidor from public.repartidores r
        where r.es_demo and r.zona_id=v_zona and r.disponible
        order by (select count(*) from public.asignaciones a where a.repartidor_id=r.id and a.terminada_en is null), r.id limit 1;
      insert into public.asignaciones(pedido_id,repartidor_id,distancia_simulada,carga_antes)
        values (v_pedido.id, v_repartidor.id, 0, (select count(*) from public.asignaciones a where a.repartidor_id=v_repartidor.id and a.terminada_en is null));
      update public.pedidos set estado='ASIGNADO' where id=v_pedido.id;
    end loop;
  end if;
  perform public.actualizar_bloqueo_zona(v_zona);
  insert into public.ejecuciones_demo(escenario_id, ejecutado_por, resultado) values (v_esc.id, auth.uid(), jsonb_build_object('codigo',p_codigo,'zona_id',v_zona,'pedidos_demo',coalesce(v_n,0),'registros','solo_es_demo')) returning * into v_ejec;
  return v_ejec;
end;
$$;

create or replace function public.restablecer_escenario_demo()
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare v_pedidos uuid[]; v_zona uuid;
begin
  if not public.es_admin() then raise exception 'ROL_NO_AUTORIZADO'; end if;
  select coalesce(array_agg(id), '{}') into v_pedidos from public.pedidos where es_demo;
  delete from public.notificaciones where pedido_id = any(v_pedidos);
  delete from public.reembolsos where pedido_id = any(v_pedidos);
  delete from public.cancelaciones where pedido_id = any(v_pedidos);
  delete from public.eventos_pedido where pedido_id = any(v_pedidos);
  delete from public.asignaciones where pedido_id = any(v_pedidos);
  delete from public.pedido_detalles where pedido_id = any(v_pedidos);
  delete from public.pedidos where id = any(v_pedidos);
  update public.repartidores set disponible=false where es_demo;
  for v_zona in select id from public.zonas loop perform public.actualizar_bloqueo_zona(v_zona); end loop;
  return jsonb_build_object('restablecido',true,'pedidos_demo_eliminados',coalesce(array_length(v_pedidos,1),0));
end;
$$;

create or replace function public.resolver_reembolso(p_reembolso_id uuid, p_aprobar boolean)
returns public.reembolsos
language plpgsql security definer set search_path = public
as $$
declare v public.reembolsos;
begin
  if not public.es_admin() then raise exception 'ROL_NO_AUTORIZADO'; end if;
  update public.reembolsos set estado=case when p_aprobar then 'REVISION_APROBADA' else 'REVISION_RECHAZADA' end, revisado_por=auth.uid() where id=p_reembolso_id and estado='REVISION_MANUAL' returning * into v;
  if not found then raise exception 'REEMBOLSO_NO_DISPONIBLE'; end if;
  insert into public.notificaciones(destinatario_id,pedido_id,tipo,titulo,mensaje) select p.cliente_id,p.id,'REEMBOLSO','Reembolso actualizado','El reembolso simulado fue actualizado.' from public.pedidos p join public.reembolsos r on r.pedido_id=p.id where r.id=p_reembolso_id;
  return v;
end;
$$;

revoke all on function public.capacidad_zona(uuid, integer) from public;
revoke all on function public.actualizar_bloqueo_zona(uuid) from public;
revoke all on function public.seleccionar_zona_repartidor(uuid) from public;
revoke all on function public.cambiar_disponibilidad_repartidor(boolean) from public;
revoke all on function public.confirmar_pedido(uuid, uuid, uuid, jsonb) from public;
revoke all on function public.actualizar_estado_pedido(uuid, text) from public;
revoke all on function public.cancelar_pedido(uuid, text, text) from public;
revoke all on function public.resolver_reembolso(uuid, boolean) from public;
revoke all on function public.ejecutar_escenario_demo(text, jsonb) from public;
revoke all on function public.restablecer_escenario_demo() from public;
grant execute on function public.capacidad_zona(uuid, integer) to authenticated;
grant execute on function public.seleccionar_zona_repartidor(uuid), public.cambiar_disponibilidad_repartidor(boolean), public.confirmar_pedido(uuid, uuid, uuid, jsonb), public.actualizar_estado_pedido(uuid, text), public.cancelar_pedido(uuid, text, text), public.resolver_reembolso(uuid, boolean) to authenticated;
grant execute on function public.ejecutar_escenario_demo(text, jsonb), public.restablecer_escenario_demo() to authenticated;
