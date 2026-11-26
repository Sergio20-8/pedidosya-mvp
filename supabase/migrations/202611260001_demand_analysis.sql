-- Fase 5: análisis histórico de demanda.
-- Preparada para revisión. No ejecutar sin autorización.
-- El MVP calcula contra los datos actuales cada vez que el administrador abre,
-- filtra o actualiza el análisis. No requiere pg_cron ni una tabla de ejecuciones.

create or replace function public.analizar_demanda_historica(p_zona_id uuid default null, p_dias integer default 90)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_fin timestamptz := now();
  v_inicio timestamptz := now() - make_interval(days => greatest(1, least(coalesce(p_dias, 90), 90)));
  v_periodo_inicio timestamptz;
  v_periodo_fin timestamptz;
  v_dias_disponibles integer;
  v_total integer;
  v_entregados integer;
  v_cancelados integer;
  v_zona record;
  v_result jsonb;
begin
  if v_actor is null or not public.es_admin() then raise exception 'SOLO_ADMIN puede consultar el análisis'; end if;

  select min(p.created_at), max(p.created_at), count(*)::integer,
         count(*) filter (where p.estado = 'ENTREGADO')::integer,
         count(*) filter (where p.estado = 'CANCELADO')::integer
    into v_periodo_inicio, v_periodo_fin, v_total, v_entregados, v_cancelados
  from public.pedidos p
  where p.created_at >= v_inicio and p.created_at <= v_fin
    and p.es_demo = false and (p_zona_id is null or p.zona_id = p_zona_id);

  v_dias_disponibles := case when v_periodo_inicio is null then 0 else greatest(1, ceil(extract(epoch from (least(v_fin, v_periodo_fin) - greatest(v_inicio, v_periodo_inicio))) / 86400)::integer + 1) end;

  v_result := jsonb_build_object(
    'meta', jsonb_build_object(
      'periodo_inicio', v_inicio,
      'periodo_fin', v_fin,
      'datos_desde', v_periodo_inicio,
      'datos_hasta', v_periodo_fin,
      'dias_disponibles', v_dias_disponibles,
      'dias_solicitados', 90,
      'historial_insuficiente', v_dias_disponibles < 90,
      'ultima_actualizacion', v_fin,
      'modo_actualizacion', 'TIEMPO_REAL'
    ),
    'indicadores', jsonb_build_object(
      'total_pedidos', coalesce(v_total, 0),
      'promedio_diario', case when v_dias_disponibles > 0 then round(v_total::numeric / v_dias_disponibles, 2) else 0 end,
      'entregados', coalesce(v_entregados, 0),
      'cancelados', coalesce(v_cancelados, 0),
      'porcentaje_cancelaciones', case when coalesce(v_total, 0) > 0 then round(v_cancelados::numeric * 100 / v_total, 2) else 0 end
    ),
    'zona_mayor_demanda', coalesce((select jsonb_build_object('nombre', z.nombre, 'total', count(*)) from public.pedidos p join public.zonas z on z.id=p.zona_id where p.created_at between v_inicio and v_fin and p.es_demo=false and (p_zona_id is null or p.zona_id=p_zona_id) group by z.id,z.nombre order by count(*) desc limit 1), '{}'::jsonb),
    'dia_mayor_demanda', coalesce((select jsonb_build_object('dia', extract(isodow from (p.created_at at time zone 'America/El_Salvador'))::integer, 'total', count(*)) from public.pedidos p where p.created_at between v_inicio and v_fin and p.es_demo=false and (p_zona_id is null or p.zona_id=p_zona_id) group by extract(isodow from (p.created_at at time zone 'America/El_Salvador'))::integer order by count(*) desc limit 1), '{}'::jsonb),
    'franja_mayor_demanda', coalesce((select jsonb_build_object('hora', floor(extract(hour from (p.created_at at time zone 'America/El_Salvador')) / 3)::integer * 3, 'total', count(*)) from public.pedidos p where p.created_at between v_inicio and v_fin and p.es_demo=false and (p_zona_id is null or p.zona_id=p_zona_id) group by floor(extract(hour from (p.created_at at time zone 'America/El_Salvador')) / 3)::integer * 3 order by count(*) desc limit 1), '{}'::jsonb),
    'zonas', coalesce((select jsonb_agg(x order by x.total desc) from (select z.id, z.nombre, count(p.id)::integer total from public.zonas z left join public.pedidos p on p.zona_id=z.id and p.created_at between v_inicio and v_fin and p.es_demo=false where p_zona_id is null or z.id=p_zona_id group by z.id,z.nombre) x), '[]'::jsonb),
    'dias', coalesce((select jsonb_agg(jsonb_build_object('dia', d.dia, 'total', coalesce(x.total,0)) order by d.dia) from generate_series(1,7) d(dia) left join (select extract(isodow from (p.created_at at time zone 'America/El_Salvador'))::integer dia,count(*)::integer total from public.pedidos p where p.created_at between v_inicio and v_fin and p.es_demo=false and (p_zona_id is null or p.zona_id=p_zona_id) group by 1) x using(dia)), '[]'::jsonb),
    'franjas', coalesce((select jsonb_agg(jsonb_build_object('hora', h.hora, 'total', coalesce(x.total,0)) order by h.hora) from generate_series(0,21,3) h(hora) left join (select floor(extract(hour from (p.created_at at time zone 'America/El_Salvador')) / 3)::integer * 3 hora,count(*)::integer total from public.pedidos p where p.created_at between v_inicio and v_fin and p.es_demo=false and (p_zona_id is null or p.zona_id=p_zona_id) group by 1) x using(hora)), '[]'::jsonb),
    'calor', coalesce((select jsonb_agg(jsonb_build_object('dia', d.dia, 'hora', h.hora, 'total', coalesce(x.total,0)) order by h.hora,d.dia) from generate_series(0,21,3) h(hora) cross join generate_series(1,7) d(dia) left join (select extract(isodow from (p.created_at at time zone 'America/El_Salvador'))::integer dia,floor(extract(hour from (p.created_at at time zone 'America/El_Salvador')) / 3)::integer * 3 hora,count(*)::integer total from public.pedidos p where p.created_at between v_inicio and v_fin and p.es_demo=false and (p_zona_id is null or p.zona_id=p_zona_id) group by 1,2) x using(dia,hora)), '[]'::jsonb),
    'cancelaciones_zona', coalesce((select jsonb_agg(x order by x.cancelados desc) from (select z.id,z.nombre,count(p.id)::integer total,count(p.id) filter(where p.estado='CANCELADO')::integer cancelados,count(p.id) filter(where p.estado='CANCELADO' and c.motivo_codigo='SIN_REPARTIDORES_EN_AREA')::integer sin_repartidores from public.zonas z left join public.pedidos p on p.zona_id=z.id and p.created_at between v_inicio and v_fin and p.es_demo=false left join public.cancelaciones c on c.pedido_id=p.id where p_zona_id is null or z.id=p_zona_id group by z.id,z.nombre) x), '[]'::jsonb)
  );

  return v_result;
end;
$$;

revoke all on function public.analizar_demanda_historica(uuid, integer) from public;
grant execute on function public.analizar_demanda_historica(uuid, integer) to authenticated;
