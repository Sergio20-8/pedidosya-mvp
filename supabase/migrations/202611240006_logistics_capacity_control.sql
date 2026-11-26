-- Fase 2: control de capacidad logística.
-- Preparada para revisión. No ejecutar automáticamente.

create table if not exists public.configuracion_logistica (
  id boolean primary key default true,
  umbral_advertencia numeric(10,2) not null default 4,
  capacidad_maxima numeric(10,2) not null default 5,
  umbral_reactivacion numeric(10,2) not null default 4,
  updated_by uuid references public.perfiles(id) on delete restrict,
  updated_at timestamptz not null default now(),
  constraint configuracion_logistica_unica check (id = true),
  constraint configuracion_logistica_valida check (
    umbral_reactivacion > 0
    and umbral_reactivacion <= umbral_advertencia
    and umbral_advertencia < capacidad_maxima
  )
);

insert into public.configuracion_logistica (id, umbral_advertencia, capacidad_maxima, umbral_reactivacion)
values (true, 4, 5, 4)
on conflict (id) do nothing;

create table if not exists public.eventos_capacidad_zona (
  id uuid primary key default gen_random_uuid(),
  zona_id uuid not null references public.zonas(id) on delete restrict,
  estado_anterior boolean not null,
  estado_nuevo boolean not null,
  activos bigint not null,
  disponibles bigint not null,
  ratio numeric,
  motivo text not null,
  actor_id uuid references public.perfiles(id) on delete restrict,
  created_at timestamptz not null default now()
);

alter table public.configuracion_logistica enable row level security;
alter table public.eventos_capacidad_zona enable row level security;
drop policy if exists configuracion_logistica_admin_select on public.configuracion_logistica;
create policy configuracion_logistica_admin_select on public.configuracion_logistica for select to authenticated using (public.es_admin());
drop policy if exists eventos_capacidad_zona_admin_select on public.eventos_capacidad_zona;
create policy eventos_capacidad_zona_admin_select on public.eventos_capacidad_zona for select to authenticated using (public.es_admin());
revoke all on public.configuracion_logistica, public.eventos_capacidad_zona from anon, authenticated;
grant select on public.configuracion_logistica, public.eventos_capacidad_zona to authenticated;

create or replace function public.capacidad_zona(p_zona_id uuid, p_incremento integer default 0)
returns table (activos bigint, disponibles bigint, ratio numeric, advertencia boolean, bloqueada boolean, puede_aceptar boolean)
language plpgsql stable security definer set search_path = public
as $$
declare
  c record;
  z public.zonas;
begin
  select * into z from public.zonas where id = p_zona_id;
  if not found then raise exception 'ZONA_NO_ENCONTRADA'; end if;
  select * into c from public.configuracion_logistica where id = true;
  select count(*) into activos from public.pedidos p where p.zona_id = p_zona_id and p.estado in ('PENDIENTE_ACEPTACION','PREPARANDO','LISTO_PARA_RECOGER','PENDIENTE','ASIGNADO','RECOGIDO','EN_CAMINO');
  select count(*) into disponibles from public.repartidores r join public.perfiles f on f.id = r.perfil_id where r.zona_id = p_zona_id and r.activo and r.disponible and f.rol = 'REPARTIDOR' and f.activo;
  ratio := case when disponibles = 0 then null else round(activos::numeric / disponibles, 4) end;
  advertencia := disponibles > 0 and ((activos + p_incremento)::numeric / disponibles) > c.umbral_advertencia;
  bloqueada := z.bloqueada or disponibles = 0 or (disponibles > 0 and ((activos + p_incremento)::numeric / disponibles) > c.capacidad_maxima);
  puede_aceptar := disponibles > 0 and not z.bloqueada and ((activos + p_incremento)::numeric / disponibles) <= c.capacidad_maxima;
  return next;
end;
$$;

create or replace function public.actualizar_bloqueo_zona(p_zona_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  z public.zonas;
  c record;
  v_activos bigint;
  v_disponibles bigint;
  v_ratio numeric;
  v_nuevo boolean;
  v_motivo text;
begin
  select * into z from public.zonas where id = p_zona_id for update;
  if not found then return false; end if;
  select * into c from public.configuracion_logistica where id = true;
  select count(*) into v_activos from public.pedidos where zona_id = p_zona_id and estado in ('PENDIENTE_ACEPTACION','PREPARANDO','LISTO_PARA_RECOGER','PENDIENTE','ASIGNADO','RECOGIDO','EN_CAMINO');
  select count(*) into v_disponibles from public.repartidores r join public.perfiles f on f.id = r.perfil_id where r.zona_id = p_zona_id and r.activo and r.disponible and f.rol = 'REPARTIDOR' and f.activo;
  v_ratio := case when v_disponibles = 0 then null else v_activos::numeric / v_disponibles end;
  v_nuevo := case when v_disponibles = 0 then true when v_ratio > c.capacidad_maxima then true when z.bloqueada and v_ratio < c.umbral_reactivacion then false else z.bloqueada end;
  v_motivo := case when v_disponibles = 0 then 'SIN_REPARTIDORES' when v_ratio > c.capacidad_maxima then 'SATURACION_REAL' when not v_nuevo then 'REACTIVACION' else 'ACTUALIZACION_CAPACIDAD' end;
  if v_nuevo is distinct from z.bloqueada then
    update public.zonas set bloqueada = v_nuevo, bloqueada_desde = case when v_nuevo then coalesce(bloqueada_desde, now()) else null end, updated_at = now() where id = p_zona_id;
    insert into public.eventos_capacidad_zona(zona_id, estado_anterior, estado_nuevo, activos, disponibles, ratio, motivo, actor_id) values (p_zona_id, z.bloqueada, v_nuevo, v_activos, v_disponibles, v_ratio, v_motivo, auth.uid());
  end if;
  return v_nuevo;
end;
$$;

create or replace function public.consultar_capacidad_checkout(p_restaurante_id uuid, p_direccion_id uuid)
returns table (zona_id uuid, bloqueada boolean, puede_confirmar boolean, advertencia boolean, motivo text)
language plpgsql security definer set search_path = public as $$
declare
  v_cliente uuid := auth.uid();
  v_zona uuid;
  c record;
begin
  if v_cliente is null or public.mi_rol() <> 'CLIENTE' then raise exception 'AUTENTICACION_CLIENTE_REQUERIDA'; end if;
  select d.zona_id into v_zona from public.direcciones d where d.id = p_direccion_id and d.cliente_id = v_cliente;
  if not found then raise exception 'DIRECCION_NO_AUTORIZADA'; end if;
  if not exists (select 1 from public.restaurantes r where r.id = p_restaurante_id and r.activo and r.zona_id = v_zona) then raise exception 'ZONA_INCOMPATIBLE'; end if;
  select * into c from public.capacidad_zona(v_zona, 1);
  zona_id := v_zona; bloqueada := c.bloqueada; puede_confirmar := c.puede_aceptar; advertencia := c.advertencia;
  motivo := case when c.disponibles = 0 then 'SIN_REPARTIDORES' when c.bloqueada then 'ZONA_BLOQUEADA' when not c.puede_aceptar then 'CAPACIDAD_SUPERADA' else null end;
  return next;
end;
$$;

create or replace function public.actualizar_configuracion_logistica(p_umbral_advertencia numeric, p_capacidad_maxima numeric, p_umbral_reactivacion numeric)
returns public.configuracion_logistica language plpgsql security definer set search_path = public as $$
declare v public.configuracion_logistica;
begin
  if not public.es_admin() then raise exception 'ROL_NO_AUTORIZADO'; end if;
  if p_umbral_reactivacion <= 0 or p_umbral_reactivacion > p_umbral_advertencia or p_umbral_advertencia >= p_capacidad_maxima then raise exception 'CONFIGURACION_LOGISTICA_INVALIDA'; end if;
  insert into public.configuracion_logistica(id, umbral_advertencia, capacidad_maxima, umbral_reactivacion, updated_by, updated_at) values (true, p_umbral_advertencia, p_capacidad_maxima, p_umbral_reactivacion, auth.uid(), now()) on conflict (id) do update set umbral_advertencia = excluded.umbral_advertencia, capacidad_maxima = excluded.capacidad_maxima, umbral_reactivacion = excluded.umbral_reactivacion, updated_by = excluded.updated_by, updated_at = excluded.updated_at returning * into v;
  perform public.actualizar_bloqueo_zona(id) from public.zonas where activa;
  return v;
end;
$$;

revoke all on function public.capacidad_zona(uuid, integer), public.actualizar_bloqueo_zona(uuid), public.consultar_capacidad_checkout(uuid, uuid), public.actualizar_configuracion_logistica(numeric, numeric, numeric) from public;
grant execute on function public.capacidad_zona(uuid, integer), public.consultar_capacidad_checkout(uuid, uuid) to authenticated;
grant execute on function public.actualizar_configuracion_logistica(numeric, numeric, numeric) to authenticated;

-- Reemplaza confirmar_pedido conservando su firma actual y serializando por zona.
create or replace function public.confirmar_pedido(p_solicitud_id uuid, p_restaurante_id uuid, p_direccion_id uuid, p_items jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_cliente uuid := auth.uid(); v_p public.pedidos; v_direccion public.direcciones; v_restaurante public.restaurantes;
  v_item jsonb; v_producto public.productos; v_cantidad integer; v_subtotal numeric(12,2) := 0; v_linea numeric(12,2); v_cap record;
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
  perform pg_advisory_xact_lock(hashtextextended(v_direccion.zona_id::text, 0));
  select * into v_cap from public.capacidad_zona(v_direccion.zona_id, 1);
  if not v_cap.puede_aceptar then raise exception 'CAPACIDAD_NO_DISPONIBLE:%', case when v_cap.disponibles = 0 then 'SIN_REPARTIDORES' when v_cap.bloqueada then 'ZONA_BLOQUEADA' else 'CAPACIDAD_SUPERADA' end; end if;
  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_producto from public.productos where id = (v_item->>'producto_id')::uuid and restaurante_id = p_restaurante_id and disponible;
    if not found then raise exception 'PRODUCTO_NO_DISPONIBLE'; end if;
    v_cantidad := (v_item->>'cantidad')::integer;
    if v_cantidad is null or v_cantidad <= 0 then raise exception 'CANTIDAD_INVALIDA'; end if;
    v_linea := v_cantidad * v_producto.precio; v_subtotal := v_subtotal + v_linea;
  end loop;
  if v_subtotal <= 0 then raise exception 'CARRITO_VACIO'; end if;
  insert into public.pedidos(solicitud_id, cliente_id, restaurante_id, zona_id, direccion_id, direccion_snapshot, estado, subtotal, costo_envio, total, eta_minutos, confirmado_en)
    values (p_solicitud_id, v_cliente, p_restaurante_id, v_direccion.zona_id, p_direccion_id, v_direccion.detalle, 'PENDIENTE_ACEPTACION', v_subtotal, 0, v_subtotal, v_restaurante.tiempo_preparacion_min + 15, now()) returning * into v_p;
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

grant execute on function public.confirmar_pedido(uuid, uuid, uuid, jsonb) to authenticated;
