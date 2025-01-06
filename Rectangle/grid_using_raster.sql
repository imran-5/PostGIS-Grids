----- Raw PostGIS queries to generate reqular grid


SELECT row_number() over() id, geom from (select (ST_PixelAsPolygons(ST_AddBand(ST_MakeEmptyRaster(100, 100, 1.1, 1.1, 1.0), '8BSI'::text, 1, 0), 1, false)).geom) as g
SELECT (ST_PixelAsPolygons(ST_AddBand(ST_MakeEmptyRaster(100, 100, 1.1, 1.1, 1.0), '8BSI'::text, 1, 0), 1, false)).geom
SELECT (ST_PixelAsPolygons(ST_AddBand(tile, '8BSI'::text, 1, 0))).geom FROM ST_MakeEmptyCoverage(1, 1, 4, 4, 22, 33, (55 - 22)/(4)::float, (33 - 77)/(4)::float, 0., 0., 4326) tile;