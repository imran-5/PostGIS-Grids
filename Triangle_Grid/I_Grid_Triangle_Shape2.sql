---------------------------------------------------------------------------
-- Query Description:
---------------------------------------------------------------------------
-- PostgreSQL / PostGIS custom function for generating a equilateral triangles, triangles grid, triangular grid, triangle grid inside of Polygon, Multipolygon, Envelope, Extent.
-- The 1st input of function must be valid geometry of polygon, Multipolygon or envelope for grid extent.
-- The 2nd input of function is cell distance for each step in x, y direction.
-- The 3rd input of function is rotation angle default value 0.
-- The 4th input of function is fit the intersection the envelope default true.
-- The internal algorithm of function generate series based on input x_max to x_min, y_max to y_min values difference and divide by x_side and y_side,
-- and translate the regular polygon to x_side and y_side distance of x and y coordinate.
-- The function handle almost any SRID, internal queries of function render by applying SRID:4326 and output of query transformed back to input SRID.
-- Requirement: PostGIS Full Version
-- Developed by: newton.imran[at]gmail[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------
-- Query Usage Example:
---------------------------------------------------------------------------
-- SELECT I_Grid_Triangle_Shape2(ST_MakeEnvelope(10, 10, 11, 11, 4326), .1, 100, true);
-- SELECT I_Grid_Triangle_Shape2(ST_Envelope(geom), .0001, 0) from polygons limit 1
-- SELECT I_Grid_Triangle_Shape2(geom, .0001, 0) from polygons limit 1
---------------------------------------------------------------------------
-- FUNCTION: public.I_Grid_Triangle_Shape2(geometry, numeric, numeric, boolean)
-- DROP FUNCTION public.I_Grid_Triangle_Shape2(geometry, numeric, numeric, boolean);

CREATE OR REPLACE FUNCTION public.i_grid_triangle_shape2(
	geom geometry,
	distance numeric,
	angle numeric DEFAULT 0,
	fit_envlope boolean DEFAULT true)
    RETURNS SETOF geometry
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE
    ROWS 1000
AS $BODY$
DECLARE
srid INTEGER := 4326;
input_srid INTEGER;
x_max DECIMAL;
y_max DECIMAL;
x_min DECIMAL;
y_min DECIMAL;
x_series DECIMAL; --absolute value
y_series DECIMAL; --absolute value
geom_rotate geometry;
geom_tri GEOMETRY := ST_GeomFromText(FORMAT('MULTIPOINT(%s %s, %s %s, %s %s, %s %s, %s %s)',
											(-distance*.5), (0), (distance*.5), (0), (distance*.5), (0),
											(-distance), (distance*.75), (0), (distance*.75)), srid);
BEGIN
CASE ST_SRID(geom) WHEN 0 THEN
    geom := ST_SetSRID(geom, 4326);
    RAISE NOTICE 'SRID Not Found.';
ELSE
    RAISE NOTICE 'SRID Found.';
END CASE;
    input_srid:=st_srid(geom);
    geom := st_transform(geom, srid);
	  geom_rotate := ST_Rotate(geom, angle, ST_Centroid(geom));
    x_max := ST_XMax(geom_rotate);
    y_max := ST_YMax(geom_rotate);
    x_min := ST_XMin(geom_rotate);
    y_min := ST_YMin(geom_rotate);
	  x_series := CEIL( @( x_max - x_min ) / distance)*.5;
    y_series := CEIL( @( y_max - y_min ) / distance)*.75;

RETURN QUERY with foo as(
SELECT ST_Rotate(ST_Translate (geom_tri, x * (distance*2) + x_min, y * (distance*1.5) + y_min), angle, ST_Centroid(geom)) grid
    FROM
        generate_series ( 0, x_series, 1) AS x,
        generate_series ( 0, y_series, 1) AS y)
SELECT ST_Collect(ST_CollectionExtract(grid, 3))
FROM (SELECT ST_Intersection(grid, geom) grid
FROM (SELECT (ST_Dump(ST_DelaunayTriangles(ST_Collect(grid)))).geom as grid FROM foo) AS bar
WHERE ST_Intersects((grid), geom))as foo2;
END;
$BODY$;