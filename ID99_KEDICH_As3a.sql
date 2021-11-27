-- Andrei Kedich
-- student number: r0865358
-- Master's of Geography
-- Time to execute: 1 sec 386 msec

create extension postgis;
/*IMPORTANT download as a simple geometry roads and subway stations 
(indicate within shapefile import manager on the dowload stage in options page) IMPORTANT
for census blocks and neighborhoods we need multi geometry */

select UpdateGeometrySRID('nyc_census_blocks','geom', 26918);
select UpdateGeometrySRID('nyc_streets','geom', 26918);
select UpdateGeometrySRID('nyc_subway_stations','geom', 26918);
select UpdateGeometrySRID('nyc_neighborhoods','geom', 26918);

--Question 1
--a
/* Here I have decided to use st_centroids instead of st_intersects because we cannot define unique values using second 
function. Use of st_centroids gives us the same values for identical neighborhoods and we can drop repeating ones. */
-- Finally we have 8 unique neighborhoods sorted from south to north along the route

create view question1a as (select name 
from (select distinct d.name, st_ymax(st_centroid(n.geom)) geom --finding centroids to find centers of neighborhoods 
from (select n.name
from (select name, geom
from nyc_streets 
where name = 'Park Ave') s --select only with correct name
inner join (select name, geom --
from nyc_neighborhoods 
where boroname = 'Manhattan') n --select neighborhoods only in Manhattan
on st_crosses(s.geom, n.geom)) d -- join on cross condition 
inner join nyc_neighborhoods n
on d.name = n.name
order by geom) d); --order by centroids (they presented in usual double type)

-- b (start and end points)
/* Here the problem was that we have several segments of Park Ave roads, so we obtain start points for all of them
And on the next step we selecting the southern one. Identical for northern end point */

create view question1b as (
--finding start point
(select n.name
from (select name, st_startpoint(geom) as start
from nyc_streets
where name = 'Park Ave' and st_intersects(geom, (select st_union(geom) --to aggreagte into one geometry
from nyc_neighborhoods
where boroname = 'Manhattan'))) p
inner join nyc_neighborhoods n
on st_within(p.start, n.geom)
order by st_ymax(p.start) -- order and limit to obtain southern point
limit 1) 
union -- union start and last points
--finding last point
(select n.name
from (select name, st_endpoint(geom) as end
from nyc_streets
where name = 'Park Ave' and st_intersects(geom, (select st_union(geom) --to aggreagte into one geometry
from nyc_neighborhoods
where boroname = 'Manhattan'))) p
inner join nyc_neighborhoods n
on st_within(p.end, n.geom)
order by st_ymax(p.end) desc --order to obtain the northern point
limit 1));

--Question 2
/* Here the main idea the start and end point could be reversed, so I decided to include both possible variants */

create view question2 as (select st_length(geom), name
from (select name, st_startpoint(geom) as start, st_endpoint(geom) as end, geom
from nyc_streets
where type = 'motorway') r --selecting only motorways
where (st_within(r.start, (select geom -- creating condition start point within Morris Heights
from nyc_neighborhoods 
where name = 'Morris Heights')) or st_within(r.end, (select geom -- or end point within Morris Heights
from nyc_neighborhoods
where name = 'Morris Heights'))) and (st_within(r.start, (select geom -- start point within Union Port
from nyc_neighborhoods
where name = 'Union Port')) or st_within(r.end, (select geom -- end point within Union Port
from nyc_neighborhoods
where name = 'Union Port')))
limit 1); 

--Question 3
--a
create view question3a as (select n.name
from (select st_startpoint(s.geom) as start, st_endpoint(s.geom) as end
from nyc_streets s
where name = 'Hoyt St') h
inner join nyc_streets n
on st_intersects(h.start, n.geom) or st_intersects(h.end, n.geom) -- searching for roads that intersects at start and end point
where name != 'Hoyt St'); --here we dropping the same street from the table

--b
--289 msec (1st variant)
/* in longer operation we use function st_buffer and join the population data at the same moment*/

create view question3b1 as (select sum(c.popn_total)
from nyc_census_blocks c
inner join (select st_buffer(s.geom, 5000) buffer
from nyc_streets s
where name = 'Hoyt St') h
on st_within(c.geom, h.buffer));

-- 71 msec (faster operation)
/* in faster operation we join only id, and on the second step we join the table with population on id
Also we are using here st_dwithin that faster. */

create view question3b2 as (select sum(popn_total)
from (select c.gid
from nyc_census_blocks c
inner join (select geom as geom
from nyc_streets
where name = 'Hoyt St') h
on st_dwithin(c.geom, h.geom, 5000)) i
inner join nyc_census_blocks c
on i.gid = c.gid);

--functions st_buffer and stdwithin work a bit different, so the result not identical
-- Question 4
/* Firstly as a concentration a defined a total black population in neighborhood
Then I have found a neighborhood with largest black population and calculated the percentage 
Here we could use also functions intersects, because some of census blocks are cutted, 
but here the result is almost the same */

create view question4 as (select black*100/total percentage, name
from (select sum(c.popn_total) total, sum(c.popn_black) black, name 
from nyc_neighborhoods n
inner join nyc_census_blocks c
on st_contains(n.geom,c.geom) -- Neighborhood contains census blocks
group by name
order by black desc
limit 1) r);

-- Question 5
/* Here the problem with choosing the function intersects and within is the same. Some census blocks along the border
are cut (because in st_within they should be fully inside)and could be missed in our calculations. 
But after comparison with actual census data I made a decsion to use intersects. For example, 
with st_within pop. density for bronx is 10433, while for st_intersects is 14276, 
the real one is 13482 (according to the census) */

create view question5 as (select p.pop/a.area density, a.boro
from (select sum(st_area(s.geom))/1000000 area, s.boroname boro 
from nyc_neighborhoods s
group by s.boroname) a
inner join (select b.boroname boro, sum(c.popn_total) pop
from nyc_census_blocks c
inner join nyc_neighborhoods b
on st_intersects(c.geom, b.geom) -- here we are using intersects to include all census blocks
group by boro) p
on a.boro = p.boro
order by density asc);

--visualisation 
-- The next block of code I used to export to QGIS and make a schematic map

create table visualisation_5 as (select b.boro, d.density, b.geom, gid
from (select boroname boro, gid, geom -- we need to add geom to previous table
from nyc_neighborhoods) b
inner join question5 d -- I used created previously view
on d.boro = b.boro);
alter table visualisation_5 add primary key (gid); --we need primary key to export table to QGIS


-- Question 6
/* The main problem here that the Broadway consists of several parts of Manhattan and it was impossible just to merge them
into one line because of the gaps between (linestring should be continious). We need only linestring type to calculate 
middle point.
I explored data in QGIS and found that this road consits of two main divided section (they are longest). I have created a
line between this two sections to unite them correctly into linestring. And then I merged 3 lines into one and finally,
obtained coordinates for this line and joined table with subway stations. */

/* Generally, the query consists of 3 parts, then we use union to make one table. In each of this parts we are finding 
the geometry of lines. For two existing segments and than based on start and end point of each line we are creating
new line. After all parts are in one table I have merged them together. And have found a middle point */

create view question6 as (select s.name
from (select st_lineinterpolatepoint(st_linemerge(st_union(a.geom)), 0.5) point --merging lines from final table and finding middle point
-- in next lines of code we selecting the geometry of second longest section
from ((select geom  
from nyc_streets n
where name = 'Broadway' and st_within(n.geom, (select st_union(geom) --to aggreagte into one geometry
from nyc_neighborhoods
where boroname = 'Manhattan'))
order by st_length(geom) desc
offset 1 limit 1) -- select only second longest road
--next lines of code: creating the middle line
union
(select st_makeline(geom) -- making line between the points
from ((select st_startpoint(geom) as geom  -- select start point of one segment
from nyc_streets n
where name = 'Broadway' and st_within(n.geom, (select st_union(geom) 
from nyc_neighborhoods
where boroname = 'Manhattan'))
order by st_length(geom) desc
limit 1)
Union -- union start and end point into one table
(select st_endpoint(geom)  -- select end point of second segment
from nyc_streets n
where name = 'Broadway' and st_within(n.geom, (select st_union(geom) 
from nyc_neighborhoods
where boroname = 'Manhattan'))
order by st_length(geom) desc
offset 1 limit 1)) l)
-- next lines of code: selecting geometry of the longest road (the same alghorithm)
Union
(select geom 
from nyc_streets n
where name = 'Broadway' and st_within(n.geom, (select st_union(geom) 
from nyc_neighborhoods
where boroname = 'Manhattan'))
order by st_length(geom) desc
limit 1)) a) p
inner join nyc_subway_stations s
on st_dwithin(p.point, s.geom, 1000)
order by st_distance(p.point, s.geom) asc
limit 1);

--Question 7
/* The most optimal variant not to reuse code 5 times is a creation of a function, so I did
I have created a specific function, input variable is boro. All other calculations are inside.
So we need just to call it 5 times after, with the name of each boro */

create or replace function get_areas_ny (boro varchar) 
returns table (boroname varchar, name varchar, dist float, population numeric) 
language plpgsql
as $$
begin
return query 
	select b.boroname, b.name, b.dist, sum(popn_total) population 
	from (select n.boroname, n.name, st_distance(b.st_centroid, (st_centroid(st_makevalid(n.geom)))) dist, st_makevalid(geom) geom
	from (select * 
	from (select n.boroname, st_centroid(st_union(st_makevalid(n.geom)))  --make valid because the geometries intersects in some areas
	from nyc_neighborhoods n
	group by n.boroname) c
	where c.boroname = boro) b -- Here is our input variable
	inner join nyc_neighborhoods n
	on b.boroname = n.boroname
	order by dist desc
	limit 5) b
	inner join nyc_census_blocks c
	on st_intersects(b.geom, c.geom)
	group by b.boroname, b.name, b.dist
	order by b.dist desc;
end;$$;

--Creating schemas and tables for each boro
create schema queens;
create table queens.queens as (select *
from get_areas_ny('Queens'));

create schema bronx;
create table bronx.bronx as (select *
from get_areas_ny('The Bronx'));

create schema statenisland;
create table statenisland.stisland as (select *
from get_areas_ny('Staten Island'));

create schema manhattan;
create table manhattan.manhattan as (select *
from get_areas_ny('Manhattan'));

create schema brooklyn;
create table brooklyn.brooklyn as (select *
from get_areas_ny('Brooklyn'));

/* During question occured the same problem with within and intersects. Some areas if not use intersects do not have
census blocks inside. So, I decided to choose intersects to include even that blocks that are partially inside.
Also some neighboorhoods are cut (as an example Bayside in Queens), so the population for them is 0 */ 