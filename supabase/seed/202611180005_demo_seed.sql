-- Datos ficticios idempotentes para la demostración académica.
-- No crea usuarios ni inserta filas en auth.users.

insert into public.zonas (nombre, descripcion) values
  ('Centro', 'Zona ficticia del centro de la ciudad'),
  ('Escalón', 'Zona ficticia de demostración'),
  ('Santa Tecla', 'Zona ficticia de demostración')
on conflict (nombre) do update set descripcion = excluded.descripcion, activa = true;

insert into public.categorias (nombre, orden) values
  ('Hamburguesas', 1), ('Pizza', 2), ('Comida típica', 3), ('Postres', 4)
on conflict (nombre) do update set orden = excluded.orden, activa = true;

insert into public.restaurantes (zona_id, nombre, descripcion, tiempo_preparacion_min, pos_x, pos_y)
select z.id, x.nombre, x.descripcion, x.preparacion, x.pos_x, x.pos_y
from (values
  ('Centro','Burger Aula','Hamburguesas para la demostración',20,1.0,1.0),
  ('Escalón','Pizza MVP','Pizzas ficticias del escenario',25,2.0,1.0),
  ('Santa Tecla','Sabor Local','Comida típica ficticia',22,1.0,2.0)
) as x(zona,nombre,descripcion,preparacion,pos_x,pos_y)
join public.zonas z on z.nombre=x.zona
where not exists (select 1 from public.restaurantes r where r.nombre=x.nombre);

insert into public.productos (restaurante_id, categoria_id, nombre, descripcion, precio)
select r.id, c.id, x.nombre, x.descripcion, x.precio
from (values
  ('Burger Aula','Hamburguesa clásica','Carne, queso y vegetales',6.50,'Hamburguesas'),
  ('Burger Aula','Papas fritas','Porción individual',2.25,'Hamburguesas'),
  ('Pizza MVP','Pizza personal','Pizza de queso para demo',7.00,'Pizza'),
  ('Sabor Local','Pupusas mixtas','Orden ficticia de pupusas',5.00,'Comida típica'),
  ('Sabor Local','Tres leches','Postre de demostración',3.25,'Postres')
) as x(restaurante,nombre,descripcion,precio,categoria)
join public.restaurantes r on r.nombre=x.restaurante
join public.categorias c on c.nombre=x.categoria
where not exists (select 1 from public.productos p where p.restaurante_id=r.id and p.nombre=x.nombre);

insert into public.promociones (restaurante_id, titulo, descripcion, tipo, activa)
select r.id, 'Demostración académica', 'Banner ficticio sin descuento aplicado', 'BANNER', true
from public.restaurantes r
where not exists (select 1 from public.promociones p where p.restaurante_id=r.id and p.titulo='Demostración académica');

insert into public.escenarios_demo (codigo, nombre, descripcion, configuracion) values
  ('NORMAL','Operación normal','Disponibilidad suficiente de repartidores','{}'),
  ('ADVERTENCIA','Advertencia de saturación','Relación superior a 4:1','{}'),
  ('BLOQUEO','Zona bloqueada','Relación superior a 5:1','{}'),
  ('RECUPERACION','Recuperación','Relación inferior a 4:1','{}'),
  ('EQUILIBRIO','Reparto equilibrado','Distribución de pedidos entre repartidores','{}'),
  ('SIN_REPARTIDORES','Sin repartidores','Incidencia sin repartidores disponibles','{}')
on conflict (codigo) do update set nombre=excluded.nombre, descripcion=excluded.descripcion, activo=true;
