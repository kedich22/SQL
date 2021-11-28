-- Andrei Kedich
-- r0865358
-- Masters of Geography
-- Time to execute: 51 msec

-- Preliminary step
-- creating table with VMF values (that we need to further to calculate bulk density)
create table bulk_density ( 
id int,
texture varchar(8),
density float(20));
-- populating created table with VMF values
insert into bulk_density (id, texture, density) values (1, 'U', 1.350); 
insert into bulk_density (id, texture, density) values (2, 'E', 1.410);
insert into bulk_density (id, texture, density) values (3, 'Z', 1.550);
insert into bulk_density (id, texture, density) values (4, 'S', 1.410);
insert into bulk_density (id, texture, density) values (5, 'P', 1.410);
insert into bulk_density (id, texture, density) values (6, 'A', 1.410);
insert into bulk_density (id, texture, density) values (7, 'L', 1.300);

-- Main step
-- Here we are using a series of nested queries not to create new tables in the db on each step

create view Question_result as (select f.soil soil, (f.carbon*a.area_soiltype)/1000 carbon_tonns 
/* computing final result based on virtual table with soil type and average carbon stock in profile and total area of soil type
multiplying by total area of soil type and dividing by 1000 to obtain tonns instead of kg */
from (select s.bodemserie soil, avg(carbon) carbon -- calculating average for each of soil types
from (select c.kapro_nr, c.geom, sum(c.carbon_conc) carbon -- creating table with sum of stock carbon for each profile
from (select f.koolstof*(100/((f.koolstof*1.32*2)/0.224 + (100-f.koolstof*1.32*2)/f.density))*0.2*10 carbon_conc,  
/* computing carbon stock of each horizon based on "virtual table" with carbon data (koolstof) and VMF, assuming thickness is 0.2 m*/
f.kapro_nr kapro_nr,
f.gid gid,
f.geom geom,
f.prof_nr prof_nr,
f.koolstof carbon
from (select *
from (select s.serie, s.textuur, s.prof_nr, s.geom, s.kapro_nr, sn.gid, sn.koolstof 
from sprof37e s
inner join shornorth sn -- join shapefile of profiles (175 points) with corresponding soil horizons that refer to profiles
on s.kapro_nr = sn.kapro_nr) c
inner join bulk_density b -- join of manually created table bulk density (by field textuur) to table with all horizons for 175 profiles 
on b.texture = c.textuur) f) c
group by c.kapro_nr, c.geom) c
inner join smu37e s -- joining soil areas to final profiles virtual table (with data about carbon stock) based on geometry
on st_within(c.geom, s.geom)
group by soil) f -- grouping by soil type to leave only unique types (and compute average carbon content for each type)
inner join (select sum(st_area(s.geom)) as area_soiltype, s.bodemserie as name -- joining the area of each soil type
from smu37e s
group by s.bodemserie) a -- grouping by soil types to calculate their total area
on f.soil = a.name
order by carbon_tonns asc);







