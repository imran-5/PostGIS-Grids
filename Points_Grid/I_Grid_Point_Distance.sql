---------------------------------------------------------------------------
-- Query Description:
---------------------------------------------------------------------------
-- PostgreSQL / PostGIS custom function for generating a regular point grid inside of Polygon, Multipolygon, Envelope, Extent.
-- The 1st input of function must be valid geometry of polygon, Multipolygon or envelope for grid extent.
-- The 2nd and 3rd input param of function are x_side (x_coordinate distance between two points) and y_side (y_coordinate distance between two points).
-- The internal algorithm of function run loop from x_min to x_max, y_min to y_max by increment of input x_side and y_side distance,
-- and project the points to x_side and y_side based on actual/true distance and angle.
-- The function handle almost any SRID, internal queries of function render by applying SRID:4326 and output of query transformed back to input SRID.
-- Requirement: PostGIS Full Version
-- Developed by: newton.imran[at]gmail[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------
-- Query Usage Example:
---------------------------------------------------------------------------
-- SELECT I_Grid_Point_Distance(geom, 50, 61) from polygons limit 1;
-- SELECT I_Grid_Point_Distance(st_envelope(geom), 50, 61) from polygons limit 1;
---------------------------------------------------------------------------

----DROP FUNCTION IF EXISTS public.I_Grid_Point_Distance(geometry, decimal, decimal);

CREATE OR REPLACE FUNCTION public.I_Grid_Point_Distance( geom public.geometry, x_side decimal, y_side decimal)
RETURNS public.geometry AS $BODY$
DECLARE
  x_min decimal;
  x_max decimal;
  y_max decimal;
  x decimal;
  y decimal;
  returnGeom public.geometry[];
  i integer := -1;
  srid integer := 4326;
  input_srid integer;
BEGIN
    CASE st_srid(geom) WHEN 0 THEN
		geom := ST_SetSRID(geom, srid);
    		----RAISE NOTICE 'No SRID Found.';
		ELSE
			----RAISE NOTICE 'SRID Found.';
	END CASE;
		input_srid:=st_srid(geom);
		geom := st_transform(geom, srid);
		x_min := ST_XMin(geom);
		x_max := ST_XMax(geom);
		y_max := ST_YMax(geom);
		y := ST_YMin(geom);
		x := x_min;
		i := i + 1;
		returnGeom[i] := st_setsrid(ST_MakePoint(x, y), srid);
  <<yloop>>
  LOOP
    IF (y > y_max) THEN
        EXIT;
    END IF;
	
	CASE i WHEN 0 THEN 
		y := ST_Y(returnGeom[0]);
	ELSE 
		y := ST_Y(ST_Project(st_setsrid(ST_MakePoint(x, y), srid), y_side, radians(0))::geometry);
	END CASE;

	x := x_min;
    <<xloop>>
    LOOP
      IF (x > x_max) THEN
          EXIT;
      END IF;
		i := i + 1;
		returnGeom[i] := st_setsrid(ST_MakePoint(x, y), srid);
		x := ST_X(ST_Project(st_setsrid(ST_MakePoint(x, y), srid), x_side, radians(90))::geometry);	
    END LOOP xloop;

  END LOOP yloop;
  RETURN ST_CollectionExtract(st_transform(ST_Intersection(st_collect(returnGeom), geom), input_srid), 1);
END;
$BODY$ LANGUAGE plpgsql IMMUTABLE;