-- Corrige permisos administrativos de productos.
-- No modifica registros ni altera el flujo de pedidos.

grant select, insert, update, delete on public.productos to authenticated;

drop policy if exists productos_admin_select on public.productos;
drop policy if exists productos_admin_insert on public.productos;
drop policy if exists productos_admin_update on public.productos;
drop policy if exists productos_admin_delete on public.productos;

create policy productos_admin_select on public.productos
  for select to authenticated using (public.es_admin());

create policy productos_admin_insert on public.productos
  for insert to authenticated with check (
    public.es_admin()
    and exists (select 1 from public.restaurantes r where r.id = productos.restaurante_id)
    and exists (
      select 1 from public.categorias c
      where c.id = productos.categoria_id
        and (c.restaurante_id = productos.restaurante_id or c.restaurante_id is null)
    )
  );

create policy productos_admin_update on public.productos
  for update to authenticated
  using (public.es_admin())
  with check (
    public.es_admin()
    and exists (select 1 from public.restaurantes r where r.id = productos.restaurante_id)
    and exists (
      select 1 from public.categorias c
      where c.id = productos.categoria_id
        and (c.restaurante_id = productos.restaurante_id or c.restaurante_id is null)
    )
  );

create policy productos_admin_delete on public.productos
  for delete to authenticated using (public.es_admin());
