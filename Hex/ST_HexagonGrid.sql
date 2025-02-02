---------------------------------------------------------------------------
-- Query Description:
---------------------------------------------------------------------------
-- PostgreSQL / PostGIS custom function for generating a hexagonal lattice structure grid inside of Polygon, Multipolygon, Envelope, Extent.
-- The 1st input of function must be valid geometry of Polygon, Multipolygon or Envelope for grid extent.
-- The 2nd input of function is radius in meters.
-- The internal algorithm of function generate series based on input x_max to x_min, y_max to y_min values difference and divide by x_side and y_side,
-- and translate the regular polygon to x_side and y_side distance of x and y coordinate.
-- Licence: MIT
---------------------------------------------------------------------------
-- Query Usage Example:
---------------------------------------------------------------------------
-- SELECT * FROM public.ST_HexagonGrid(
--     ST_MakeEnvelope(10, 10, 10.2, 10.2, 4326), -- Input geometry
--     100                                      -- Radius in meters
-- );
---------------------------------------------------------------------------

-- DROP FUNCTION IF EXISTS public.ST_HexagonGrid(geom GEOMETRY, radius_meters DOUBLE PRECISION);

CREATE OR REPLACE FUNCTION public.ST_HexagonGrid(input_geom GEOMETRY, radius_meters DOUBLE PRECISION)
RETURNS TABLE(id BIGINT, geom GEOMETRY) AS $BODY$
DECLARE
	
	srid INTEGER := 4326;
	input_srid INTEGER;
	x_max DECIMAL;
	y_max DECIMAL;
	x_min DECIMAL;
	y_min DECIMAL;
	x_series DECIMAL;
	y_series DECIMAL;
	radius_degrees DOUBLE PRECISION := radius_meters / 111320; -- Convert radius from meters to degrees
	b float := radius_degrees / 2;
	a float := b / 2; --sin(30)=.5
	c float := 2 * a;

 	--temp     GEOMETRY := ST_GeomFromText(FORMAT('POLYGON((0 0, %s %s, %s %s, %s %s, %s %s, %s %s, 0 0))',
    --                       (b), (a), (b), (a+c), (0), (a+c+a), (-1*b), (a+c), (-1*b), (a)), srid);
	-- geom_grid	GEOMETRY := ST_GeomFromText(FORMAT('POLYGON((0 0, %s %s, %s %s, %s %s, %s %s, %s %s, 0 0))',
    --                       (radius_degrees *  0.5), (radius_degrees * 0.25),
    --                       (radius_degrees *  0.5), (radius_degrees * 0.75),
    --                                    0 ,  radius_degrees,
    --                       (radius_degrees * -0.5), (radius_degrees * 0.75),
    --                       (radius_degrees * -0.5), (radius_degrees * 0.25)), srid);
	geom_grid GEOMETRY;

BEGIN
	-- Set SRID if not already defined
	IF ST_SRID(input_geom) IS NULL THEN
		input_geom := ST_SetSRID(input_geom, 4326);
		RAISE NOTICE 'Geometry SRID set to 4326.';
	ELSE
		RAISE NOTICE 'Geometry SRID Found.';
	END IF;
	-- Transform to target SRID for calculations
	input_srid := ST_SRID(input_geom);
	input_geom := ST_Transform(input_geom, srid);
	-- Get a bounding box
	x_max := ST_XMax(input_geom);
	y_max := ST_YMax(input_geom);
	x_min := ST_XMin(input_geom);
	y_min := ST_YMin(input_geom);
	-- Calculate grid dimensions
	-- x_series := ceil ( @( x_max - x_min ) / radius_degrees);
	-- y_series := ceil ( @( y_max - y_min ) / radius_degrees);
	-- Calculate the number of hexagons required in x and y directions
    x_series := CEIL(ABS(x_max - x_min) / (2 * a + c));
    y_series := CEIL(ABS(y_max - y_min) / (2 * (c + a)));
	-- Define a single hexagon geometry
	geom_grid := ST_GeomFromText(
		FORMAT(
			'POLYGON((0 0, %s %s, %s %s, %s %s, %s %s, %s %s, 0 0))',
			(radius_degrees * 0.5), (radius_degrees * 0.25),
			(radius_degrees * 0.5), (radius_degrees * 0.75),
			0, radius_degrees,
			(radius_degrees * -0.5), (radius_degrees * 0.75),
			(radius_degrees * -0.5), (radius_degrees * 0.25)
		), srid
	);
	
	-- Generate hexagonal grid
	RETURN QUERY 
		SELECT
			row_number() OVER() AS id,
			h.geom
		FROM (
			SELECT
				ST_Translate( cell, x * ( 2 * a + c ) + x_min, y * ( 2 * ( c + a )) + y_min) AS geom
			FROM
				generate_series ( 0, x_series, 1) AS x,
				generate_series ( -1, y_series, 1) AS y,
				(
					SELECT ST_Translate(geom_grid::GEOMETRY, b , a + c)  AS cell
						UNION
					SELECT geom_grid AS cell
				) AS foo
		) AS h WHERE ST_Intersects(h.geom, input_geom);
END;
$BODY$ LANGUAGE 'plpgsql' VOLATILE;