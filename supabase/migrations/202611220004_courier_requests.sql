-- Solicitudes de entrega publicadas y aceptación atómica del primer repartidor.
alter table public.pedidos add column if not exists solicitud_repartidor_publicada boolean not null default false;
alter table public.pedidos add column if not exists solicitud_repartidor_publicada_en timestamptz;

create or replace function public.pedido_visible_solicitud_repartidor(p_pedido_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.pedidos p
    join public.repartidores r on r.zona_id = p.zona_id
    where p.id = p_pedido_id and p.solicitud_repartidor_publicada and p.estado = 'LISTO_PARA_RECOGER'
      and r.perfil_id = auth.uid() and r.activo and r.disponible
  );
$$;

drop policy if exists pedidos_courier_requests_select on public.pedidos;
create policy pedidos_courier_requests_select on public.pedidos for select to authenticated
using (public.pedido_visible_solicitud_repartidor(id));

create or replace function public.solicitar_repartidor(p_pedido_id uuid)
returns public.pedidos language plpgsql security definer set search_path = public as $$
declare v public.pedidos;
begin
  if not public.es_admin() then raise exception 'ROL_NO_AUTORIZADO'; end if;
  update public.pedidos set solicitud_repartidor_publicada=true, solicitud_repartidor_publicada_en=coalesce(solicitud_repartidor_publicada_en, now())
    where id=p_pedido_id and estado='LISTO_PARA_RECOGER' and not exists (select 1 from public.asignaciones a where a.pedido_id=p_pedido_id and a.terminada_en is null)
    returning * into v;
  if not found then raise exception 'PEDIDO_NO_PUBLICABLE'; end if;
  insert into public.eventos_pedido(pedido_id,tipo_evento,estado_anterior,estado_nuevo,actor_id,origen,detalle) values (v.id,'SOLICITUD_REPARTIDOR','LISTO_PARA_RECOGER','LISTO_PARA_RECOGER',auth.uid(),'ADMIN','Solicitud publicada para repartidores elegibles');
  return v;
end; $$;

create or replace function public.aceptar_entrega_repartidor(p_pedido_id uuid)
returns public.pedidos language plpgsql security definer set search_path = public as $$
declare v public.pedidos; r public.repartidores; carga integer; distancia numeric; restaurante public.restaurantes;
begin
  if public.mi_rol() <> 'REPARTIDOR' then raise exception 'ROL_NO_AUTORIZADO'; end if;
  select * into r from public.repartidores where perfil_id=auth.uid() for update;
  if not found or not r.activo or not r.disponible then raise exception 'REPARTIDOR_NO_DISPONIBLE'; end if;
  select * into v from public.pedidos where id=p_pedido_id for update;
  if not found or not v.solicitud_repartidor_publicada or v.estado <> 'LISTO_PARA_RECOGER' then raise exception 'SOLICITUD_NO_DISPONIBLE'; end if;
  if r.zona_id is distinct from v.zona_id then raise exception 'ZONA_NO_AUTORIZADA'; end if;
  if exists (select 1 from public.asignaciones where pedido_id=v.id and terminada_en is null) then raise exception 'SOLICITUD_YA_ACEPTADA'; end if;
  select * into restaurante from public.restaurantes where id=v.restaurante_id;
  select count(*) into carga from public.asignaciones where repartidor_id=r.id and terminada_en is null;
  distancia := coalesce(sqrt(power(coalesce(r.pos_x,0)-coalesce(restaurante.pos_x,0),2)+power(coalesce(r.pos_y,0)-coalesce(restaurante.pos_y,0),2)),0);
  insert into public.asignaciones(pedido_id,repartidor_id,distancia_simulada,carga_antes) values(v.id,r.id,distancia,carga);
  update public.pedidos set estado='ASIGNADO', solicitud_repartidor_publicada=false where id=v.id returning * into v;
  insert into public.eventos_pedido(pedido_id,tipo_evento,estado_anterior,estado_nuevo,actor_id,origen,detalle) values(v.id,'ASIGNACION','LISTO_PARA_RECOGER','ASIGNADO',auth.uid(),'REPARTIDOR','Primer repartidor elegible que aceptó la solicitud');
  insert into public.notificaciones(destinatario_id,pedido_id,tipo,titulo,mensaje) values(v.cliente_id,v.id,'ASIGNACION','Repartidor asignado','Tu pedido ya tiene un repartidor asignado.');
  return v;
exception when unique_violation then raise exception 'SOLICITUD_YA_ACEPTADA';
end; $$;

grant execute on function public.solicitar_repartidor(uuid), public.aceptar_entrega_repartidor(uuid) to authenticated;
