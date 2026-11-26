-- Seed adicional preparado para autorización explícita.
-- No ejecutar automáticamente: agrega 5 restaurantes ficticios y 30 productos.
-- No elimina ni sobrescribe filas existentes.

insert into public.categorias (nombre, orden) values
  ('Pastas', 5), ('Pollo', 6), ('Comida mexicana', 7), ('Comida asiática', 8), ('Combos', 9), ('Bebidas', 10)
on conflict (nombre) do update set orden = excluded.orden, activa = true;

insert into public.restaurantes (zona_id, nombre, descripcion, imagen_url, tiempo_preparacion_min, pos_x, pos_y)
select z.id, x.nombre, x.descripcion, x.imagen_url, x.preparacion, x.pos_x, x.pos_y
from (values
  ('Centro', 'Pasta Studio', 'Pastas y salsas preparadas al momento', 'https://www.themealdb.com/images/media/meals/syqypv1486981727.jpg', 24, 2.0, 2.0),
  ('Escalón', 'Pollo al Punto', 'Pollo asado, bowls y acompañamientos', 'https://www.themealdb.com/images/media/meals/1529444830.jpg', 27, 3.0, 1.0),
  ('Santa Tecla', 'Taco Patio', 'Tacos y sabores mexicanos para compartir', 'https://www.themealdb.com/images/media/meals/ypxvwv1505333929.jpg', 21, 2.0, 3.0),
  ('Centro', 'Asia Wok', 'Recetas asiáticas salteadas al wok', 'https://www.themealdb.com/images/media/meals/1529443236.jpg', 26, 3.0, 2.0),
  ('Escalón', 'Dulce Parada', 'Postres, café y opciones dulces', 'https://www.themealdb.com/images/media/meals/qtqvys1468573168.jpg', 18, 4.0, 1.0)
) as x(zona, nombre, descripcion, imagen_url, preparacion, pos_x, pos_y)
join public.zonas z on z.nombre = x.zona
where not exists (select 1 from public.restaurantes r where r.nombre = x.nombre);

insert into public.productos (restaurante_id, categoria_id, nombre, descripcion, precio)
select r.id, c.id, x.producto, x.descripcion, x.precio
from (values
  ('Pasta Studio', 'Pastas', 'Penne al pesto', 'Pasta con pesto de albahaca y queso', 8.50),
  ('Pasta Studio', 'Pastas', 'Spaghetti pomodoro', 'Spaghetti con salsa de tomate casera', 7.75),
  ('Pasta Studio', 'Pastas', 'Lasagna de la casa', 'Capas de pasta, salsa y queso gratinado', 9.50),
  ('Pasta Studio', 'Pastas', 'Fettuccine cremoso', 'Fettuccine con salsa cremosa y hierbas', 8.95),
  ('Pasta Studio', 'Combos', 'Combo pasta y bebida', 'Pasta del día con bebida', 10.25),
  ('Pasta Studio', 'Postres', 'Tiramisú', 'Postre suave de café y cacao', 4.25),
  ('Pollo al Punto', 'Pollo', 'Pollo asado', 'Pollo asado con especias de la casa', 8.25),
  ('Pollo al Punto', 'Pollo', 'Pechuga grill', 'Pechuga a la plancha con vegetales', 8.75),
  ('Pollo al Punto', 'Pollo', 'Alitas BBQ', 'Alitas bañadas en salsa BBQ', 7.95),
  ('Pollo al Punto', 'Combos', 'Combo pollo familiar', 'Pollo, papas y ensalada para compartir', 18.50),
  ('Pollo al Punto', 'Combos', 'Bowl de pollo', 'Arroz, pollo, vegetales y salsa', 9.25),
  ('Pollo al Punto', 'Postres', 'Pastel de chocolate', 'Porción de pastel de chocolate', 4.00),
  ('Taco Patio', 'Comida mexicana', 'Tacos al pastor', 'Tacos con cerdo, piña y cebolla', 7.50),
  ('Taco Patio', 'Comida mexicana', 'Tacos de pollo', 'Tacos de pollo con vegetales frescos', 7.25),
  ('Taco Patio', 'Comida mexicana', 'Burrito de la casa', 'Burrito grande con arroz, frijoles y proteína', 8.95),
  ('Taco Patio', 'Comida mexicana', 'Quesadilla mixta', 'Tortilla dorada con queso y relleno mixto', 6.75),
  ('Taco Patio', 'Combos', 'Combo tacos', 'Tacos con acompañamiento y bebida', 10.50),
  ('Taco Patio', 'Postres', 'Churros', 'Churros con azúcar y canela', 3.50),
  ('Asia Wok', 'Comida asiática', 'Arroz frito', 'Arroz salteado con vegetales y huevo', 7.25),
  ('Asia Wok', 'Comida asiática', 'Noodles al wok', 'Noodles salteados con vegetales', 7.95),
  ('Asia Wok', 'Comida asiática', 'Pollo teriyaki', 'Pollo glaseado con salsa teriyaki', 9.25),
  ('Asia Wok', 'Comida asiática', 'Ramen de la casa', 'Caldo, noodles, vegetales y proteína', 9.75),
  ('Asia Wok', 'Comida asiática', 'Gyozas', 'Gyozas doradas con salsa de la casa', 5.95),
  ('Asia Wok', 'Combos', 'Combo wok', 'Plato al wok con bebida', 10.25),
  ('Dulce Parada', 'Postres', 'Cheesecake', 'Porción cremosa con frutos rojos', 5.25),
  ('Dulce Parada', 'Postres', 'Brownie', 'Brownie de chocolate horneado', 3.75),
  ('Dulce Parada', 'Postres', 'Tiramisú clásico', 'Café, cacao y crema suave', 4.50),
  ('Dulce Parada', 'Postres', 'Crepa dulce', 'Crepa con fruta y crema', 5.95),
  ('Dulce Parada', 'Bebidas', 'Café latte', 'Café espresso con leche vaporizada', 3.25),
  ('Dulce Parada', 'Bebidas', 'Chocolate caliente', 'Bebida caliente de chocolate', 3.50)
) as x(restaurante, categoria, producto, descripcion, precio)
join public.restaurantes r on r.nombre = x.restaurante
join public.categorias c on c.nombre = x.categoria
where not exists (
  select 1 from public.productos p where p.restaurante_id = r.id and p.nombre = x.producto
);
