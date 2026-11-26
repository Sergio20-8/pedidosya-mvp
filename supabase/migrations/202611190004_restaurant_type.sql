-- Preparada, no ejecutar sin autorización.
-- Agrega el tipo de comida propio de cada restaurante.

alter table public.restaurantes
  add column if not exists tipo_comida text not null default 'Otros'
    check (char_length(trim(tipo_comida)) between 2 and 60);

