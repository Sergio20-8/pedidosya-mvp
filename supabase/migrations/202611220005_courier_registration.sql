-- Registro y aprobación segura de repartidores. Preparada, no ejecutar automáticamente.
create table if not exists public.solicitudes_repartidor (
  id uuid primary key default gen_random_uuid(),
  perfil_id uuid not null unique references public.perfiles(id) on delete restrict,
  zona_id uuid not null references public.zonas(id) on delete restrict,
  tipo_vehiculo varchar(20) not null check (tipo_vehiculo in ('MOTOCICLETA','BICICLETA','AUTOMOVIL')),
  estado varchar(20) not null default 'PENDIENTE' check (estado in ('PENDIENTE','APROBADA','RECHAZADA')),
  motivo_rechazo text,
  solicitada_en timestamptz not null default now(),
  revisada_en timestamptz,
  revisado_por uuid references public.perfiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists solicitudes_repartidor_estado_idx on public.solicitudes_repartidor(estado, solicitada_en desc);
create index if not exists solicitudes_repartidor_zona_idx on public.solicitudes_repartidor(zona_id);
drop trigger if exists solicitudes_repartidor_updated_at on public.solicitudes_repartidor;
create trigger solicitudes_repartidor_updated_at before update on public.solicitudes_repartidor for each row execute function public.set_updated_at();
alter table public.solicitudes_repartidor enable row level security;

create policy solicitudes_repartidor_self_select on public.solicitudes_repartidor for select to authenticated using (perfil_id = auth.uid() or public.es_admin());
create policy solicitudes_repartidor_self_insert on public.solicitudes_repartidor for insert to authenticated with check (perfil_id = auth.uid() and public.mi_rol() = 'CLIENTE');

grant select on public.solicitudes_repartidor to authenticated;
grant insert (perfil_id, zona_id, tipo_vehiculo) on public.solicitudes_repartidor to authenticated;

create or replace function public.enviar_solicitud_repartidor(p_zona_id uuid, p_tipo_vehiculo text)
returns public.solicitudes_repartidor language plpgsql security definer set search_path = public as $$
declare v public.solicitudes_repartidor;
begin
  if auth.uid() is null or public.mi_rol() <> 'CLIENTE' then raise exception 'CLIENTE_REQUERIDO'; end if;
  if p_tipo_vehiculo not in ('MOTOCICLETA','BICICLETA','AUTOMOVIL') then raise exception 'TIPO_VEHICULO_INVALIDO'; end if;
  if not exists (select 1 from public.zonas where id = p_zona_id and activa) then raise exception 'ZONA_NO_DISPONIBLE'; end if;
  if exists (select 1 from public.solicitudes_repartidor where perfil_id = auth.uid() and estado = 'PENDIENTE') then raise exception 'SOLICITUD_PENDIENTE_EXISTENTE'; end if;
  update public.solicitudes_repartidor set zona_id = p_zona_id, tipo_vehiculo = p_tipo_vehiculo, estado = 'PENDIENTE', motivo_rechazo = null, solicitada_en = now(), revisada_en = null, revisado_por = null where perfil_id = auth.uid() and estado = 'RECHAZADA' returning * into v;
  if not found then insert into public.solicitudes_repartidor(perfil_id, zona_id, tipo_vehiculo) values (auth.uid(), p_zona_id, p_tipo_vehiculo) returning * into v; end if;
  return v;
end; $$;

create or replace function public.aprobar_solicitud_repartidor(p_solicitud_id uuid)
returns public.solicitudes_repartidor language plpgsql security definer set search_path = public as $$
declare v public.solicitudes_repartidor; v_repartidor public.repartidores;
begin
  if not public.es_admin() then raise exception 'ROL_NO_AUTORIZADO'; end if;
  select * into v from public.solicitudes_repartidor where id = p_solicitud_id for update;
  if not found or v.estado <> 'PENDIENTE' then raise exception 'SOLICITUD_NO_PENDIENTE'; end if;
  update public.perfiles set rol = 'REPARTIDOR' where id = v.perfil_id;
  insert into public.repartidores(perfil_id, zona_id, disponible, activo) values (v.perfil_id, v.zona_id, false, true)
    on conflict (perfil_id) do update set zona_id = excluded.zona_id, activo = true, disponible = false returning * into v_repartidor;
  update public.solicitudes_repartidor set estado = 'APROBADA', revisada_en = now(), revisado_por = auth.uid(), motivo_rechazo = null where id = v.id returning * into v;
  return v;
end; $$;

create or replace function public.rechazar_solicitud_repartidor(p_solicitud_id uuid, p_motivo text)
returns public.solicitudes_repartidor language plpgsql security definer set search_path = public as $$
declare v public.solicitudes_repartidor;
begin
  if not public.es_admin() then raise exception 'ROL_NO_AUTORIZADO'; end if;
  if nullif(trim(coalesce(p_motivo, '')), '') is null then raise exception 'MOTIVO_REQUERIDO'; end if;
  update public.solicitudes_repartidor set estado = 'RECHAZADA', motivo_rechazo = trim(p_motivo), revisada_en = now(), revisado_por = auth.uid() where id = p_solicitud_id and estado = 'PENDIENTE' returning * into v;
  if not found then raise exception 'SOLICITUD_NO_PENDIENTE'; end if;
  return v;
end; $$;

grant execute on function public.enviar_solicitud_repartidor(uuid, text), public.aprobar_solicitud_repartidor(uuid), public.rechazar_solicitud_repartidor(uuid, text) to authenticated;
