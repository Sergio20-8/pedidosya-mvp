-- Coordenadas opcionales para direcciones existentes.
-- Esta migración es incremental y no modifica ni elimina registros.
alter table public.direcciones
  add column if not exists latitud numeric(9,6),
  add column if not exists longitud numeric(9,6);

alter table public.direcciones
  drop constraint if exists direcciones_latitud_rango,
  drop constraint if exists direcciones_longitud_rango;

alter table public.direcciones
  add constraint direcciones_latitud_rango
    check (latitud is null or latitud between -90 and 90),
  add constraint direcciones_longitud_rango
    check (longitud is null or longitud between -180 and 180),
  add constraint direcciones_coordenadas_completas
    check ((latitud is null and longitud is null) or (latitud is not null and longitud is not null));
