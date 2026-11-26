-- Preparada, no ejecutar sin autorización.
-- Extiende el catálogo para administración segura y categorías por restaurante.

alter table public.restaurantes
  add column if not exists calificacion numeric(2,1) not null default 0
    check (calificacion >= 0 and calificacion <= 5),
  add column if not exists cantidad_resenas integer not null default 0
    check (cantidad_resenas >= 0);

alter table public.categorias
  add column if not exists restaurante_id uuid references public.restaurantes(id) on delete restrict;

alter table public.categorias drop constraint if exists categorias_nombre_key;
create unique index if not exists categorias_restaurante_nombre_uidx
  on public.categorias(restaurante_id, nombre);

create policy restaurantes_admin_select on public.restaurantes
  for select to authenticated using (public.es_admin());
create policy restaurantes_admin_insert on public.restaurantes
  for insert to authenticated with check (public.es_admin());
create policy restaurantes_admin_update on public.restaurantes
  for update to authenticated using (public.es_admin()) with check (public.es_admin());
create policy restaurantes_admin_delete on public.restaurantes
  for delete to authenticated using (public.es_admin());

create policy categorias_admin_select on public.categorias
  for select to authenticated using (public.es_admin());
create policy categorias_admin_insert on public.categorias
  for insert to authenticated with check (public.es_admin());
create policy categorias_admin_update on public.categorias
  for update to authenticated using (public.es_admin()) with check (public.es_admin());
create policy categorias_admin_delete on public.categorias
  for delete to authenticated using (public.es_admin());

create policy productos_admin_select on public.productos
  for select to authenticated using (public.es_admin());
create policy productos_admin_insert on public.productos
  for insert to authenticated with check (
    public.es_admin()
    and exists (select 1 from public.restaurantes r where r.id = restaurante_id)
    and exists (select 1 from public.categorias c where c.id = categoria_id and (c.restaurante_id = productos.restaurante_id or c.restaurante_id is null))
  );
create policy productos_admin_update on public.productos
  for update to authenticated using (public.es_admin()) with check (public.es_admin());
create policy productos_admin_delete on public.productos
  for delete to authenticated using (public.es_admin());

grant select, insert, update, delete on public.restaurantes to authenticated;
grant select, insert, update, delete on public.categorias to authenticated;
grant select, insert, update, delete on public.productos to authenticated;
grant select (id, nombre, telefono, rol, activo, created_at, updated_at) on public.perfiles to authenticated;
