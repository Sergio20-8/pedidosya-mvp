-- Permite al repartidor autenticado y elegible consultar la ubicación exacta
-- únicamente mientras la solicitud está publicada y aún no fue aceptada.
create policy direcciones_courier_request_select on public.direcciones
for select to authenticated
using (
  exists (
    select 1
    from public.pedidos p
    where p.direccion_id = direcciones.id
      and public.pedido_visible_solicitud_repartidor(p.id)
  )
);
