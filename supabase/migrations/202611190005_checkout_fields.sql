-- Preparada, no ejecutar sin autorización.
-- Campos adicionales para persistir datos propios del checkout.

alter table public.pedidos
  add column if not exists metodo_pago varchar(20) not null default 'EFECTIVO'
    check (metodo_pago in ('EFECTIVO')),
  add column if not exists monto_efectivo numeric(12,2)
    check (monto_efectivo is null or monto_efectivo >= 0),
  add column if not exists cambio_estimado numeric(12,2)
    check (cambio_estimado is null or cambio_estimado >= 0),
  add column if not exists instrucciones_entrega text;

