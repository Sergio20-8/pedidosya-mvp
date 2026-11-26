-- Permite al repartidor asignado consultar el destino de su entrega activa.
-- La dirección sigue sin estar visible para otros repartidores.
drop policy if exists direcciones_courier_assigned_select on public.direcciones;
create policy direcciones_courier_assigned_select
on public.direcciones
for select to authenticated
using (
  exists (
    select 1
    from public.pedidos p
    where p.direccion_id = direcciones.id
      and public.pedido_asignado_al_repartidor(p.id)
  )
);
