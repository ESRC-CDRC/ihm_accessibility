
-- Should be possible to run this script in one go. Main requirement is that
-- the year is changed to reflect the data that have been imported from QGIS.

-- 1 ------------------------------------------------------------------------------------------------------
-- Create a routing table from road links --

--DROP SCHEMA  itn2016 CASCADE;
CREATE SCHEMA itn_2016_out;
-- DROP TABLE IF EXISTS itn_2016_out.itn_routing;

CREATE TABLE itn_2016_out.itn_routing
(gid serial NOT NULL,
fid character varying,
node0 character varying,
node1 character varying,
gradesep0 integer,
gradesep1 integer,
dir_drive character varying,
dir_walk character varying,
source integer,
target integer,
cost_drive double precision,
reverse_cost_drive double precision,
cost_walk double precision,
reverse_cost_walk double precision,
filename character varying,
x1 double precision,
y1 double precision,
x2 double precision,
y2 double precision,
to_cost double precision,
rule text,
the_geom geometry,
CONSTRAINT edges_pk PRIMARY KEY (gid),
CONSTRAINT enforce_dims_the_geom CHECK (st_ndims(the_geom) = 2),
CONSTRAINT enforce_geotype_the_geom CHECK (geometrytype(the_geom) = 'LINESTRING'::text OR the_geom IS NULL),
CONSTRAINT enforce_srid_the_geom CHECK (st_srid(the_geom) = 27700))
WITH (OIDS=FALSE);

-- 2 ------------------------------------------------------------------------------------------------------
-- Insert data from roadlinks --

INSERT INTO itn_2016_out.itn_routing (fid, node0, node1, gradesep0, gradesep1, the_geom)
SELECT DISTINCT ON (l.ogc_fid)
l.fid,
l.directednoderefneg,
l.directednoderefpos,
l.gradeseparationneg,
l.gradeseparationpos,
--l.filename,
l.wkb_geometry
FROM itn_2016.roadlink AS l;








CREATE INDEX i_itn_2016_out_fid ON itn_2016_out.itn_routing(fid);
CREATE INDEX i_itn_2016_out_node0 ON itn_2016_out.itn_routing(node0);
CREATE INDEX i_itn_2016_out_node1 ON itn_2016_out.itn_routing(node1);
CREATE INDEX i_itn_2016_out_gradesep0 ON itn_2016_out.itn_routing(gradesep0);
CREATE INDEX i_itn_2016_out_gradesep1 ON itn_2016_out.itn_routing(gradesep1);
CREATE INDEX i_itn_2016_out_dir_drive ON itn_2016_out.itn_routing(dir_drive);
CREATE INDEX i_itn_2016_out_dir_walk ON itn_2016_out.itn_routing(dir_walk);
CREATE INDEX i_itn_2016_out_source ON itn_2016_out.itn_routing(source);
CREATE INDEX i_itn_2016_out_target ON itn_2016_out.itn_routing(target);
CREATE INDEX i_itn_2016_out_filename ON itn_2016_out.itn_routing(filename);
CREATE INDEX i_itn_2016_out_routing_the_geom ON itn_2016_out.itn_routing USING gist(the_geom);



-----------------------------


DROP TABLE IF EXISTS itn_2016_out.itn_restrict;
CREATE TABLE itn_2016_out.itn_restrict (
id serial NOT NULL,
fromgrade_sep boolean NOT NULL,
direction character(1) NOT NULL,
to_cost double precision NOT NULL DEFAULT 1000000.0, -- 1000km
teid integer,
feid integer,
tefid _varchar,
fefid _varchar,
via text,
CONSTRAINT restrictions_pk PRIMARY KEY (id)
);
CREATE INDEX i_itn_2016_out_tefid ON itn_2016_out.itn_restrict(tefid);
CREATE INDEX i_itn_2016_out_fefid ON itn_2016_out.itn_restrict(fefid);


----


INSERT INTO itn_2016_out.itn_restrict (fromgrade_sep, direction, fefid, tefid)
SELECT FALSE,
'F',
route_info.directedlinkorientation,
route_info.directedlinkref
FROM
itn_2016.roadrouteinformation AS route_info
WHERE route_info.environmentqualifier_instruction[1] = 'No Turn';

UPDATE itn_2016_out.itn_restrict a SET teid = b.gid FROM itn_2016_out.itn_routing b WHERE
a.tefid[1] = b.fid;

UPDATE itn_2016_out.itn_restrict a SET feid = b.gid FROM itn_2016_out.itn_routing b WHERE
a.fefid[1] = b.fid;
---------------------


UPDATE itn_2016_out.itn_routing a SET source = ogc_fid FROM itn_2016.roadnode b
WHERE a.node0=b.fid;
UPDATE itn_2016_out.itn_routing a SET target = ogc_fid FROM itn_2016.roadnode b
WHERE a.node1=b.fid;


-----

UPDATE itn_2016_out.itn_routing SET cost_drive = ST_Length(the_geom);
UPDATE itn_2016_out.itn_routing SET reverse_cost_drive = cost_drive;
UPDATE itn_2016_out.itn_routing SET cost_walk = cost_drive;
UPDATE itn_2016_out.itn_routing SET reverse_cost_walk = cost_drive;

-------


UPDATE itn_2016_out.itn_routing a SET reverse_cost_drive = -1
FROM (SELECT * FROM itn_2016.roadrouteinformation
      WHERE 'One Way' = any(environmentqualifier_instruction) AND '"+"' = ANY(directedlinkorientation)) AS b
WHERE a.fid = ANY(b.directedlinkref);

UPDATE itn_2016_out.itn_routing a SET reverse_cost_drive = -1
FROM (SELECT * FROM itn_2016.roadrouteinformation
      WHERE 'One Way' = any(environmentqualifier_instruction) AND '"-"' = ANY(directedlinkorientation)) AS b
WHERE a.fid = ANY(b.directedlinkref);


CREATE INDEX i_itn_2016_out_cost_drive ON itn_2016_out.itn_routing(cost_drive);
CREATE INDEX i_itn_2016_out_reverse_cost_drive ON itn_2016_out.itn_routing(reverse_cost_drive);

UPDATE itn_2016_out.itn_routing SET dir_walk = 'B';
UPDATE itn_2016_out.itn_routing SET dir_drive = 'B';
UPDATE itn_2016_out.itn_routing SET dir_drive = 'TF' WHERE cost_drive <0 AND reverse_cost_drive >0;




DROP TABLE IF EXISTS itn_2016_out.itn_nodes;
CREATE TABLE itn_2016_out.itn_nodes AS
	SELECT ogc_fid, fid, wkb_geometry, 0 AS elev FROM itn_2016.roadnode
UNION ALL
	SELECT DISTINCT ON (b.fid, b.wkb_geometry, a.elev)
    nextval('itn_2016.roadnode_ogc_fid_seq'::regclass), b.fid, b.wkb_geometry, a.elev
	FROM (
		SELECT DISTINCT source node, gradesep0 elev from itn_2016_out.itn_routing WHERE gradesep0 >0
		UNION ALL
		SELECT DISTINCT target node, gradesep1 elev from itn_2016_out.itn_routing WHERE gradesep1 >0
	) a
	JOIN itn_2016.roadnode b ON a.node=b.ogc_fid
    ORDER BY ogc_fid;
CREATE INDEX i_itn_2016_out_nodes_elev ON itn_2016_out.itn_nodes (elev);




---
create index on itn_2016_out.itn_nodes using gist(wkb_geometry);
create index on itn_2016_out.itn_routing using gist(the_geom);

 UPDATE itn_2016_out.itn_routing a SET source = ogc_fid FROM itn_2016_out.itn_nodes b WHERE
 st_intersects (b.wkb_geometry, (st_startpoint(a.the_geom)));

UPDATE itn_2016_out.itn_routing a SET target = ogc_fid FROM itn_2016_out.itn_nodes b WHERE
 st_intersects (b.wkb_geometry, (st_endpoint (a.the_geom)));

----

UPDATE itn_2016_out.itn_routing a SET target = ogc_fid FROM itn_2016_out.itn_nodes b
WHERE a.node1 = b.fid AND a.gradesep1 = b.elev AND b.elev > 0;

UPDATE itn_2016_out.itn_routing a SET source = ogc_fid FROM itn_2016_out.itn_nodes b
WHERE a.node0 = b.fid AND a.gradesep0 = b.elev AND b.elev > 0;
