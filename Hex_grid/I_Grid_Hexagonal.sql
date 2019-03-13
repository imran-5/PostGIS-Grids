---------------------------------------------------------------------------
-- Query Description:
---------------------------------------------------------------------------
-- PostgreSQL / PostGIS custom function for generating a hexagonal lattice structure grid, hex grid, hexa grid, hexagonal polygon grid inside of Polygon, Multipolygon, Envelope, Extent.
-- The 1st input of function must be valid geometry of polygon, Multipolygon or envelope for grid extent.
-- The 2nd input of function is distance for each step in x, y direction of two hex.
-- The internal algorithm of function generate series based on input x_max to x_min, y_max to y_min values difference and divide by x_side and y_side,
-- and translate the regular polygon to x_side and y_side distance of x and y coordinate.
-- The function handle almost any SRID, internal queries of function render by applying SRID:4326 and output of query transformed back to input SRID.
-- Requirement: PostGIS Full Version
-- Developed by: newton.imran[at]gmail[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------
-- Query Usage Example:
---------------------------------------------------------------------------
-- SELECT I_Grid_Hex(ST_MakeEnvelope(10, 10, 11, 11, 4326), .1);
-- SELECT I_Grid_Hex(geom, .0001) from polygons limit 1
-- SELECT I_Grid_Hex(ST_Envelope(geom), .0001) from polygons limit 1
---------------------------------------------------------------------------

-- DROP FUNCTION IF EXISTS public.I_Grid_Hex(geometry, double precision);

CREATE OR REPLACE FUNCTION public.I_Grid_Hex(geom geometry, radius double precision)
RETURNS SETOF geometry AS $BODY$
DECLARE
	srid INTEGER := 4326;
	input_srid INTEGER;
	x_max DECIMAL;
	y_max DECIMAL;
	x_min DECIMAL;
	y_min DECIMAL;
	x_series DECIMAL;
	y_series DECIMAL;
	b float :=radius/2;
  a float :=b/2; --sin(30)=.5
  c float :=2*a;

 	--temp     GEOMETRY := ST_GeomFromText(FORMAT('POLYGON((0 0, %s %s, %s %s, %s %s, %s %s, %s %s, 0 0))',
    --                       (b), (a), (b), (a+c), (0), (a+c+a), (-1*b), (a+c), (-1*b), (a)), srid);
	geom_grid     GEOMETRY := ST_GeomFromText(FORMAT('POLYGON((0 0, %s %s, %s %s, %s %s, %s %s, %s %s, 0 0))',
                          (radius *  0.5), (radius * 0.25),
                          (radius *  0.5), (radius * 0.75),
                                       0 ,  radius,
                          (radius * -0.5), (radius * 0.75),
                          (radius * -0.5), (radius * 0.25)), srid);

BEGIN
	CASE st_srid(geom) WHEN 0 THEN
		geom := ST_SetSRID(geom, 4326);
		RAISE NOTICE 'SRID Not Found.';
	ELSE
		RAISE NOTICE 'SRID Found.';
	END CASE;
		input_srid:=st_srid(geom);
		geom := st_transform(geom, srid);
		x_max := ST_XMax(geom);
		y_max := ST_YMax(geom);
		x_min := ST_XMin(geom);
		y_min := ST_YMin(geom);
		x_series := ceil ( @( x_max - x_min ) / radius);
		y_series := ceil ( @( y_max - y_min ) / radius);
RETURN QUERY
		With foo as(SELECT
			ST_Translate ( cell, x*(2*a+c)+x_min, y*(2*(c+a))+y_min) AS hexa
		FROM
			generate_series ( 0, x_series, 1) AS x,
			generate_series ( -1, y_series, 1) AS y,
			(
			SELECT ST_Translate(geom_grid::geometry, b , a+c)  as cell
				union
			SELECT geom_grid AS cell
			) AS foo
		) select ST_CollectionExtract(ST_Collect(ST_Transform(ST_Intersection(ST_CollectionExtract(hexa, 3), geom), input_srid)),3)
		from foo where ST_Intersects(hexa, geom);
END;
$BODY$ LANGUAGE 'plpgsql' VOLATILE;