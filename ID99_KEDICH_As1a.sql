-- Andrei Kedich
-- student number: r0865358
-- Time to execute: 701 msec


-- Importing table with soil_observations

-- Before importing the table all No data values were changed to the same type of representation - NA 
-- Also from the table were manually deleted cells - 22634-AA; 22635-AA that should be numeric to further calculations

-- Creating table and defining types of data in different columns
create table tbl_soil_observations (
	gid integer NOT NULL,
	id integer,
	permkey char(100),
	soilsite_id integer,
	soilsite_pk char(100),
	soilsite_name char(100),
	soillocation_id integer,
	soillocation_pk char(100),
	soillocation_name char(100),
	depthinterval_id integer,
	depthinterval_pk char(100),
	depthinterval_name char(100),
	depthinterval_number integer,
	depthinterval_ul1 integer,
	depthinterval_ll1 integer,
	depthinterval_ul2 integer, 
	depthinterval_ll2 integer,
	monster_id integer, 
	monster_pk char(100),
	monster_identification char(100),
	parenttype char(100), 
	origin char(100), 
	date_analysis char(100),
	parameter_code char(100),
	analysis_method char(100),
	detection_condition char(100), 
	measured_value_num float(50),
	measured_value_txt char(300),
	labo_field char(100),
	depth_from integer,
	depth_to integer,
	number_comments integer,
	organization integer,
	status integer);  

-- Download the existing data from csv. file to the created table
copy tbl_soil_observations(gid,id,permkey,soilsite_id,soilsite_pk,soilsite_name,soillocation_id,soillocation_pk,soillocation_name,depthinterval_id, depthinterval_pk, depthinterval_name, depthinterval_number, depthinterval_ul1, depthinterval_ll1, depthinterval_ul2,
depthinterval_ll2, monster_id, monster_pk, monster_identification, parenttype, origin, date_analysis, parameter_code, analysis_method, detection_condition, measured_value_num, measured_value_txt, labo_field, depth_from, depth_to, number_comments, organization, status)             
from 'C:\Data\Geospatial_Databases\Assignment_1\Tbl_soil_observations.csv'
with(format csv, delimiter ';', NULL 'NA', header, encoding 'windows-1251');

--Question 1
create view question1 as (select sum(st_area(s.geom) / a.total_area) * 100 as area_percentage, s.bodemtype as name -- Sum(st_area) calculates total area for soil type
from smu89e s
cross join (select sum(st_area(geom)) as total_area -- Creating virtually a table for total area
from smu89e) a
group by s.bodemtype, a.total_area
order by area_percentage asc);

/*Here we used a nested query, so the table with overall area was created on the fly (virtually) and joined to the initiial table
On the next step I computed the percentage of all soil types regarding the whole area */

--Question 2
-- question a
create view question2_a as (select area, name 
from (select st_area(geom) as area, bodemtype as name --creating top 10 table virtually
from smu89e 
where st_area(geom) is not null -- use not null because we have null values presented in column
order by area desc
limit 10) area_top 
union -- allows us to bind two tables with top10 and least 10 areas
select area_2, name 
from (select st_area(geom) as area_2, bodemtype as name
from smu89e 
order by area_2 asc
limit 10) area_low -- creating smallest 10 table virtually
order by area asc); 

-- Here we creating firstly 2 tables (on a fly) with largest and smallest 10 areas. Then with union we bind them

-- question b 
create view question2_b as (select sum(s.area) / a.total_area *100  as area_percentage
from question2_a s
cross join (select sum(st_area(geom)) as total_area -- virtually creating table with total area and joining it
from smu89e) a
group by a.total_area);

/*For solving this question we are using created in first part view (that contains area of 20 soil types)
Next we obtained a total area like in exercise 1 and divided sum of our 20 types by whole area*/

-- Question 3
select name -- Obtaining name of created virtually table
from (select sum(st_area(s.geom) / a.total_area) * 100 as area_percentage, s.bodemtype as name --calculating percentages for all soil types
from smu89e s
cross join (select sum(st_area(geom)) as total_area -- virtual table for whole area
from smu89e) a
group by s.bodemtype, a.total_area
order by area_percentage desc
limit 1) top_soil;

-- Firstly we define which soil type have the largest area (by calculating percentage for all)
-- And by later implementing function limit to leave only first row

/* So were claculated that the largest soil type with around 12% out of total area is "OB"
-- In the next code we spatially join soil_location table (with all profiles) to the map
-- And making a condition to show only within OB layer type */

create view question3 as (select distinct l.name as name, l.soil_type as soil
from soil_locations l
inner join smu89e s 
on st_within(l.geom, s.geom)
where s.bodemtype = 'OB');

-- Question 4
create view question4 as (select soil, count(*) AS total_count
from (select l.name as name, s.bodemtype as soil
from soil_locations l
inner join smu89e s
on st_within(l.geom, s.geom)) profiles --here defining that soil locations within all soil types
group by soil 
order by total_count asc 
limit 5); -- leaving only 5 rows with least values

-- here we used a nested query to create a table: within which soil type profile is located

-- Question 5
-- IMPORTANT: In input table I made the sign for all No data identical - NA, as well as manually changed two values in cells
-- 22634-AA; 22635-AA, that had to be numeric for further calculations

-- Here we have several nested queries that allows us not to create new tables and to make all operations directly in one query

create view question5 as (select distinct ps.soil as soil_type -- using distinct to get unique values
from (select name as prof, s.id as id, s.geom as geom, s.soil_type as type 
from (select id from 
(select meausure, id, gid
from (Select measured_value_num as meausure, soillocation_id as id, gid as gid
from tbl_soil_observations
where parameter_code = '1525') carbon_concentration -- creating a subset with only carbon concentration parameter (1525)
where meausure > (select avg(meausure)  -- calculating average for subset and selecting horizons more than average
from (Select measured_value_num as meausure, soillocation_id as id, gid as gid
from tbl_soil_observations
where parameter_code = '1525') carbon_concentration) -- defining virtual table to obtain average again (to comapre values)
order by id asc) table_carbon) p
inner join soil_locations s
on p.id = s.gid) p
inner join (select distinct l.name as name, s.bodemtype as soil
from soil_locations l
left join smu89e s
on st_within(l.geom, s.geom)) ps
on p.prof = ps.name);

--Question 6
-- IMPORTANT Here we are counting soil locations for all area for selected soil types (not only for touching polygons)
-- It was not clear which locations we need to count from the guidelines

create view question6_1 as (select s.soil as soil, count(s.soil) AS total_count 
from (select sl.name as name, s.soil as soil -- some soil locations refer to one profile
from soil_locations sl
inner join (select s.soil as soil, sm.geom as geom -- add geometry to soil types (soil_touch virtual table)
from smu89e sm
inner join (select soil as soil
from (select sm.bodemtype as soil, sm.geom as geom
from smu89e s
inner join smu89e sm
on st_touches(sm.geom, s.geom) -- St_touches shows objects that share at least one point at the border
where s.bodemtype = 'Zcg') soil_touch -- virtual table wih soil types that are neighbours to Zcg
group by soil) s
on soil = bodemtype) s
on st_within(sl.geom, s.geom)) s -- this operation in order to connect soil types and soil location within
group by soil
order by total_count asc);

-- IMPORTANT
-- The next chunck of code provides the same operation but counts only for touching soil polygons
create view question6_2 as (select s.soil as soil, count(s.soil) AS total_count
from soil_locations sl
inner join (select sm.bodemtype as soil, sm.geom as geom
from smu89e s
inner join smu89e sm
on st_touches(sm.geom, s.geom) 
where s.bodemtype = 'Zcg') s
on st_within(sl.geom, s.geom)
group by soil
order by total_count asc);
--Question 7
create view question7 as (select name as name, distance as distance 
from (select distinct sl.name as name, st_distance(s.geom, sl.geom) as distance 
from soil_locations s
cross join soil_locations sl
where s.name = 'KART_PROF_074E/18' and sl.type = 'PROF'
order by distance asc
limit 6) five_sites -- due to cross join we also have the distance between the same profile that is 0, that why we selecting 6 rows
where name != 'KART_PROF_074E/18'); -- here we deleting first row, where the same profiles are presented

--Question 8
create view question8 as (select distinct sl.name as name -- we use distinct to show only unique values
from soil_locations s
inner join soil_locations sl  -- to complete it we need to join the same table
on st_dwithin(s.geom, sl.geom, 750) -- here we define join with a buffer 750 m 
where s.type = 'PROF' and sl.type = 'PROF') -- here we define that the type should be only = profile