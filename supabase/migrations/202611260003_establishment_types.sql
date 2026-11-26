-- Ampliación de catálogo: restaurantes, supermercados y farmacias.
-- Preparada para revisión. No ejecutar sin autorización.

alter table public.restaurantes
  add column if not exists tipo_establecimiento text not null default 'RESTAURANTE';

update public.restaurantes
set tipo_establecimiento = 'RESTAURANTE'
where tipo_establecimiento is null or btrim(tipo_establecimiento) = '';

alter table public.restaurantes
  drop constraint if exists restaurantes_tipo_establecimiento_check;

alter table public.restaurantes
  add constraint restaurantes_tipo_establecimiento_check
  check (tipo_establecimiento in ('RESTAURANTE', 'SUPERMERCADO', 'FARMACIA'));

create index if not exists restaurantes_tipo_activo_idx
  on public.restaurantes(tipo_establecimiento, activo);
