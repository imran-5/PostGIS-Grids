---------------------------------------------------------------------------
-- Query Description:
---------------------------------------------------------------------------
-- PostgreSQL / PostGIS custom function for generating a equilateral triangles, triangles grid, triangular grid, triangle grid inside of Polygon, Multipolygon, Envelope, Extent.
-- The 1st input of function must be valid geometry of polygon, Multipolygon or envelope for grid extent.
-- The 2nd input of function is cell distance for each step in x, y direction.
-- The 3rd input of function is rotation angle.
-- The 4th input of function is fit the intersection the envelope.
-- The internal algorithm of function generate series based on input x_max to x_min, y_max to y_min values difference and divide by x_side and y_side,
-- and translate the regular polygon to x_side and y_side distance of x and y coordinate.
-- The function handle almost any SRID, internal queries of function render by applying SRID:4326 and output of query transformed back to input SRID.
-- Requirement: PostGIS Full Version
-- Licence: MIT
---------------------------------------------------------------------------
-- Query Usage Example:
---------------------------------------------------------------------------
-- SELECT I_Grid_TriAngle(ST_MakeEnvelope(10, 10, 11, 11, 4326), .1, 100, true);
-- SELECT I_Grid_TriAngle(ST_Envelope(geom), .0001) from polygons
-- SELECT I_Grid_TriAngle(geom, .0001) from polygons limit 1
---------------------------------------------------------------------------
-- FUNCTION: public.I_Grid_Triangle(geometry, numeric, numeric, boolean)
-- DROP FUNCTION public.I_Grid_Triangle(geometry, numeric, numeric, boolean);

CREATE OR REPLACE FUNCTION public.I_Grid_Triangle(
	geom geometry,
	distance numeric,
	angle numeric default 0,
	fit_envlope boolean default true)
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
geom_tri GEOMETRY := ST_GeomFromText(FORMAT('POLYGON((0 0, %s %s, %s %s, 0 0))',(distance * .5), (distance), (-distance * .5), (distance) ), srid);
BEGIN
CASE st_srid(geom) WHEN 0 THEN
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
    x_series := CEIL( @( x_max - x_min ) / distance);
    y_series := CEIL( @( y_max - y_min ) / distance);
RETURN QUERY
    with foo as(SELECT
        ST_Rotate(ST_Translate (cell, x * distance + x_min, y * distance + y_min), angle, ST_Centroid(geom)) AS grid
    FROM
        generate_series ( 0, x_series, 1) AS x,
        generate_series ( 0, y_series, 1) AS y,
        (
        SELECT geom_tri AS cell
            union
        SELECT st_rotate(geom_tri, pi(), distance * .25, distance * .5)  as cell
        ) as foo
    )
	SELECT CASE WHEN fit_envlope THEN
	ST_CollectionExtract(ST_transform(st_collect(st_intersection(grid, geom)), input_srid), 3)
	ELSE
	ST_transform(st_collect(grid), input_srid) END FROM foo WHERE CASE WHEN fit_envlope THEN st_intersects(grid, geom) ELSE st_intersects(grid, geom) END;
END;
$BODY$;

ALTER FUNCTION public.I_Grid_Triangle(geometry, numeric, numeric, boolean)
    OWNER TO postgres;