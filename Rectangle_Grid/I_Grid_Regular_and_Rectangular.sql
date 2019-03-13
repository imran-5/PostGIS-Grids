---------------------------------------------------------------------------
-- Query Description:
---------------------------------------------------------------------------
-- PostgreSQL / PostGIS custom function for generating a regular line grid, regular polygon grid, regular fishnet grid, rectangular grid, regular grid inside of Polygon, Multipolygon, Envelope, Extent.
-- The 1st input of function must be valid geometry of polygon, Multipolygon or envelope for grid extent.
-- The 2nd and 3rd input param of function are the x_side x_coordinate distance between two points) and the y_side (y_coordinate distance between two points).
-- The internal algorithm of function generate series based on input x_max to x_min, y_max to y_min values difference and divide by x_side and y_side,
-- and translate the regular polygon to x_side and y_side distance of x and y coordinate.
-- The function handle almost any SRID, internal queries of function render by applying SRID:4326 and output of query transformed back to input SRID.
-- Requirement: PostGIS Full Version
-- Developed by: newton.imran[at]gmail[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------
-- Query Usage Example:
---------------------------------------------------------------------------
-- SELECT I_Grid_Regular(ST_MakeEnvelope(10, 10, 11, 11, 4326), .1, .1)
-- SELECT I_Grid_Regular(geom, .0001, .0001) from polygons limit 1
-- SELECT I_Grid_Regular(ST_Envelope(geom), .0001, .0001) from polygons limit 1
---------------------------------------------------------------------------


----DROP FUNCTION IF EXISTS I_Grid_Regular(geometry, float8, float8);

CREATE OR REPLACE FUNCTION PUBLIC.I_Grid_Regular
( geom geometry, x_side float8, y_side float8, OUT geometry )
RETURNS SETOF geometry AS $BODY$ DECLARE
x_max DECIMAL;
y_max DECIMAL;
x_min DECIMAL;
y_min DECIMAL;
srid INTEGER := 4326;
input_srid INTEGER;
x_series DECIMAL;
y_series DECIMAL;
geom_cell geometry := ST_GeomFromText(FORMAT('POLYGON((0 0, 0 %s, %s %s, %s 0,0 0))',
											$3, $2, $3, $2), srid);
BEGIN
	CASE ST_SRID (geom) WHEN 0 THEN
		geom := ST_SetSRID (geom, srid);
		RAISE NOTICE'SRID Not Found.';
	ELSE
		RAISE NOTICE'SRID Found.';
	END CASE;
	input_srid := ST_srid ( geom );
	geom := ST_Transform ( geom, srid );
	x_max := ST_XMax ( geom );
	y_max := ST_YMax ( geom );
	x_min := ST_XMin ( geom );
	y_min := ST_YMin ( geom );
	x_series := CEIL ( @( x_max - x_min ) / x_side );
	y_series := CEIL ( @( y_max - y_min ) / y_side );

	RETURN QUERY With foo AS (
		SELECT
		ST_Translate( geom_cell, j * $2 + x_min, i * $3 + y_min ) AS cell
		FROM
			generate_series ( 0, x_series ) AS j,
			generate_series ( 0, y_series ) AS i
		) SELECT ST_CollectionExtract(ST_Collect(ST_Transform ( ST_Intersection(cell, geom), input_srid)), 3)
		FROM foo where ST_intersects (cell, geom);
END;
$BODY$ LANGUAGE plpgsql IMMUTABLE STRICT;