---------------------------------------------------------------------------
-- Query Description:
---------------------------------------------------------------------------
-- PostgreSQL / PostGIS custom function for generating a regular point grid inside of Polygon, Multipolygon, Envelope, Extent.
-- The 1st input of function must be valid geometry of Polygon, Multipolygon or envelope for grid extent.
-- The 2nd and 3rd input param of function are x_side (x_coordinate distance between two points) and y_side (y_coordinate distance between two points).
-- The 4th input param of the function is boolean to measure the distance of x and y coordinate in spheroid datum.
-- The internal algorithm of function generate series based on input x_side and y_side distance by applying coordinate distance.
-- The function handle almost any SRID, internal queries of function render by applying SRID:4326, SRID:900913 and output of query transformed back to input SRID.
-- Requirement: PostGIS Full Version
-- Developed by: newton.imran[at]gmail[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------
-- Query Usage Example:
---------------------------------------------------------------------------
-- SELECT I_Grid_Point(geom, 22, 15, true) from polygons limit 1;
-- SELECT I_Grid_Point(st_envelope(geom), 22, 15, true) from polygons limit 1;
---------------------------------------------------------------------------

-----DROP FUNCTION IF EXISTS I_Grid_Point(geometry, decimal, decimal, boolean);

CREATE OR REPLACE FUNCTION I_Grid_Point(geom geometry, x_side decimal, y_side decimal, spheroid boolean default false)
RETURNS SETOF geometry AS $BODY$
DECLARE
x_max decimal;
y_max decimal;
x_min decimal;
y_min decimal;
srid integer := 4326;
input_srid integer;
BEGIN
    CASE st_srid(geom) WHEN 0 THEN
      geom := ST_SetSRID(geom, srid);
      RAISE NOTICE 'SRID Not Found.';
		ELSE
			RAISE NOTICE 'SRID Found.';
		END CASE;

		CASE spheroid WHEN false THEN
			RAISE NOTICE 'Spheroid False';
			srid := 4326;
			x_side := x_side / 100000;
			y_side := y_side / 100000;
		else
			srid := 900913;
			RAISE NOTICE 'Spheroid True';
		END CASE;
		input_srid:=st_srid(geom);
		geom := st_transform(geom, srid);
		x_max := ST_XMax(geom);
		y_max := ST_YMax(geom);
		x_min := ST_XMin(geom);
		y_min := ST_YMin(geom);
RETURN QUERY
WITH res as (SELECT ST_SetSRID(ST_MakePoint(x, y), srid) point FROM
	generate_series(x_min, x_max, x_side) as x,
	generate_series(y_min, y_max, y_side) as y
	WHERE st_intersects(geom, ST_SetSRID(ST_MakePoint(x, y), srid))
	) select ST_TRANSFORM(ST_COLLECT(point), input_srid) from res;
END;
$BODY$ LANGUAGE plpgsql IMMUTABLE STRICT;