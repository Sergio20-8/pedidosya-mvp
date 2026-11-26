-- Preparado, no ejecutar sin autorización.
-- Limpia exclusivamente el catálogo de demostración conocido.
-- No elimina usuarios, perfiles, zonas, pedidos, detalles, funciones, triggers ni políticas.

do $$
declare
  demo_restaurant_ids uuid[];
begin
  select coalesce(array_agg(id), '{}'::uuid[]) into demo_restaurant_ids
  from public.restaurantes
  where nombre in ('Burger Aula', 'Pizza MVP', 'Sabor Local', 'Pasta Studio', 'Pollo al Punto', 'Taco Patio', 'Asia Wok', 'Dulce Parada');

  if exists (
    select 1 from public.pedidos where restaurante_id = any(demo_restaurant_ids)
  ) then
    raise exception 'LIMPIEZA_DEMO_BLOQUEADA_PEDIDOS_EXISTENTES';
  end if;

  if exists (
    select 1 from public.pedido_detalles d
    join public.productos p on p.id = d.producto_id
    where p.restaurante_id = any(demo_restaurant_ids)
  ) then
    raise exception 'LIMPIEZA_DEMO_BLOQUEADA_DETALLES_EXISTENTES';
  end if;

  delete from public.productos where restaurante_id = any(demo_restaurant_ids);
  delete from public.promociones where restaurante_id = any(demo_restaurant_ids);
  delete from public.restaurantes where id = any(demo_restaurant_ids);
  delete from public.categorias
  where nombre in ('Hamburguesas', 'Pizza', 'Comida típica', 'Postres', 'Pastas', 'Pollo', 'Comida mexicana', 'Comida asiática', 'Combos', 'Bebidas')
    and not exists (select 1 from public.productos p where p.categoria_id = categorias.id);
end $$;
