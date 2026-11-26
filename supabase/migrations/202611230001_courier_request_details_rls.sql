-- Permite que un repartidor elegible vea los productos de una solicitud
-- publicada antes de aceptarla. La consulta queda limitada a su zona.
create policy pedido_detalles_courier_request_select on public.pedido_detalles
for select to authenticated
using (
  exists (
    select 1
    from public.pedidos p
    join public.repartidores r on r.zona_id = p.zona_id
    where p.id = pedido_detalles.pedido_id
      and p.solicitud_repartidor_publicada
      and p.estado = 'LISTO_PARA_RECOGER'
      and r.perfil_id = auth.uid()
      and r.activo
      and r.disponible
  )
);
