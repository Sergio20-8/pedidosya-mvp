-- PedidosYa MVP v2 - autorización y RLS

create or replace function public.mi_rol()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select rol from public.perfiles where id = auth.uid() and activo;
$$;

create or replace function public.es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.mi_rol() = 'ADMIN', false);
$$;

create or replace function public.es_repartidor()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.mi_rol() = 'REPARTIDOR', false);
$$;

revoke all on function public.mi_rol() from public;
revoke all on function public.es_admin() from public;
revoke all on function public.es_repartidor() from public;
grant execute on function public.mi_rol() to anon, authenticated;
grant execute on function public.es_admin() to authenticated;
grant execute on function public.es_repartidor() to authenticated;

create policy zonas_catalogo_select on public.zonas for select to anon, authenticated using (activa);
create policy zonas_authenticated_select on public.zonas for select to authenticated using (activa or public.es_admin());
create policy restaurantes_catalogo_select on public.restaurantes for select to anon, authenticated using (activo);
create policy categorias_catalogo_select on public.categorias for select to anon, authenticated using (activa);
create policy productos_catalogo_select on public.productos for select to anon, authenticated using (disponible);
create policy grupos_opciones_catalogo_select on public.grupos_opciones for select to anon, authenticated using (true);
create policy opciones_catalogo_select on public.opciones_producto for select to anon, authenticated using (disponible);
create policy promociones_catalogo_select on public.promociones for select to anon, authenticated using (
  activa and (inicio is null or inicio <= now()) and (fin is null or fin > now())
);

create policy perfiles_self_select on public.perfiles for select to authenticated using (id = auth.uid() or public.es_admin());
create policy perfiles_self_update on public.perfiles for update to authenticated
  using (id = auth.uid() and rol = 'CLIENTE')
  with check (id = auth.uid() and rol = 'CLIENTE' and activo);

create policy direcciones_owner_select on public.direcciones for select to authenticated using (cliente_id = auth.uid() or public.es_admin());
create policy direcciones_owner_insert on public.direcciones for insert to authenticated with check (cliente_id = auth.uid() and public.mi_rol() = 'CLIENTE');
create policy direcciones_owner_update on public.direcciones for update to authenticated using (cliente_id = auth.uid()) with check (cliente_id = auth.uid());
create policy direcciones_owner_delete on public.direcciones for delete to authenticated using (cliente_id = auth.uid());

create policy repartidor_self_select on public.repartidores for select to authenticated using (perfil_id = auth.uid() or public.es_admin());
create policy repartidor_admin_update on public.repartidores for update to authenticated using (public.es_admin()) with check (public.es_admin());

create policy pedidos_owner_or_ops_select on public.pedidos for select to authenticated using (
  cliente_id = auth.uid()
  or public.es_admin()
  or exists (
    select 1 from public.asignaciones a
    where a.pedido_id = pedidos.id
      and exists (select 1 from public.repartidores r where r.id = a.repartidor_id and r.perfil_id = auth.uid())
  )
);
create policy detalles_owner_or_ops_select on public.pedido_detalles for select to authenticated using (
  exists (select 1 from public.pedidos p where p.id = pedido_id and (p.cliente_id = auth.uid() or public.es_admin()))
  or exists (
    select 1 from public.asignaciones a join public.repartidores r on r.id = a.repartidor_id
    where a.pedido_id = pedido_detalles.pedido_id and r.perfil_id = auth.uid()
  )
);
create policy asignaciones_owner_or_ops_select on public.asignaciones for select to authenticated using (
  public.es_admin() or exists (select 1 from public.pedidos p where p.id = pedido_id and p.cliente_id = auth.uid())
  or exists (select 1 from public.repartidores r where r.id = repartidor_id and r.perfil_id = auth.uid())
);
create policy eventos_owner_or_ops_select on public.eventos_pedido for select to authenticated using (
  public.es_admin() or exists (select 1 from public.pedidos p where p.id = pedido_id and p.cliente_id = auth.uid())
  or exists (
    select 1 from public.asignaciones a join public.repartidores r on r.id = a.repartidor_id
    where a.pedido_id = eventos_pedido.pedido_id and r.perfil_id = auth.uid()
  )
);

create policy cancelaciones_owner_or_admin_select on public.cancelaciones for select to authenticated using (
  public.es_admin() or exists (select 1 from public.pedidos p where p.id = pedido_id and p.cliente_id = auth.uid())
);
create policy reembolsos_owner_or_admin_select on public.reembolsos for select to authenticated using (
  public.es_admin() or exists (select 1 from public.pedidos p where p.id = pedido_id and p.cliente_id = auth.uid())
);

create policy notificaciones_owner_select on public.notificaciones for select to authenticated using (destinatario_id = auth.uid());
create policy notificaciones_owner_update on public.notificaciones for update to authenticated using (destinatario_id = auth.uid()) with check (destinatario_id = auth.uid());

create policy escenarios_admin_select on public.escenarios_demo for select to authenticated using (public.es_admin());
create policy ejecuciones_admin_select on public.ejecuciones_demo for select to authenticated using (public.es_admin());

revoke all on all tables in schema public from anon, authenticated;
grant select on public.zonas, public.restaurantes, public.categorias, public.productos, public.grupos_opciones, public.opciones_producto, public.promociones to anon, authenticated;
grant select (id, nombre, telefono, created_at, updated_at) on public.perfiles to authenticated;
grant update (nombre, telefono) on public.perfiles to authenticated;
grant select on public.direcciones, public.repartidores, public.pedidos, public.pedido_detalles, public.asignaciones, public.eventos_pedido, public.cancelaciones, public.reembolsos, public.notificaciones, public.escenarios_demo, public.ejecuciones_demo to authenticated;
grant update on public.direcciones, public.notificaciones to authenticated;
