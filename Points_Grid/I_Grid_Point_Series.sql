---------------------------------------------------------------------------
-- Query Description:
---------------------------------------------------------------------------
-- PostgreSQL / PostGIS custom function for generating a regular point grid inside of Polygon, Multipolygon, Envelope, Extent.
-- The 1st input of function must be valid geometry of polygon, Multipolygon or envelope for grid extent.
-- The 2nd and 3rd input param of function are x_side step (x_coordinate distance between two points) and y_side step (y_coordinate distance between two points).
-- The 4th input param of the function is boolean to measure the distance of x and y coordinate in spheroid datum.
-- The internal algorithm of function generate series based on input x_max to x_min, y_max to y_min values difference and divide by x_side and y_side,
-- and translate the points to x_side and y_side distance of x and y coordinate.
-- The function handle almost any SRID, internal queries of function render by applying SRID:4326 and output of query transformed back to input SRID.
-- Requirement: PostGIS Full Version
-- Developed by: newton.imran[at]gmail[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------
-- Query Usage Example:
---------------------------------------------------------------------------
-- SELECT I_Grid_Point_Series(geom, .0001, .0001, false) from polygons limit 1;
-- SELECT I_Grid_Point_Series(st_envelope(geom), .0001, .0001, false) from polygons limit 1;
---------------------------------------------------------------------------


-----DROP FUNCTION IF EXISTS I_Grid_Point_Series(geometry, decimal, decimal, boolean);

CREATE OR REPLACE FUNCTION I_Grid_Point_Series(geom geometry, x_side decimal, y_side decimal, spheroid boolean default false)
RETURNS SETOF geometry AS $BODY$
DECLARE
x_max decimal;
y_max decimal;
x_min decimal;
y_min decimal;
srid integer := 4326;
input_srid integer;

x_series DECIMAL;
y_series DECIMAL;

BEGIN
    CASE st_srid(geom) WHEN 0 THEN
      geom := ST_SetSRID(geom, srid);
      RAISE NOTICE 'SRID Not Found.';
		ELSE
			RAISE NOTICE 'SRID Found.';
		END CASE;

		CASE spheroid WHEN false THEN
			RAISE NOTICE 'Spheroid False';
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

		x_series := CEIL ( @( x_max - x_min ) / x_side);
		y_series := CEIL ( @( y_max - y_min ) / y_side );
RETURN QUERY
SELECT st_collect(st_setsrid(ST_MakePoint(x * x_side + x_min, y*y_side + y_min), srid)) FROM
	generate_series(0, x_series) as x,
	generate_series(0, y_series) as y
	WHERE st_intersects(st_setsrid(ST_MakePoint(x*x_side + x_min, y*y_side + y_min), srid), geom);
END;
$BODY$ LANGUAGE plpgsql IMMUTABLE STRICT;