create database hr_data_analysis;

use hr_data_analysis;

select * from hr_data;

--checking data types--
select column_name, data_type from INFORMATION_SCHEMA.COLUMNS;

--correcting data types--
alter table hr_data
alter column [training times last year] int; 

alter table hr_data
alter column age int; 

alter table hr_data
alter column [daily rate] int; 

alter table hr_data
alter column [distance from home] int; 

alter table hr_data
alter column [employee count] int; 

alter table hr_data
alter column [environment satisfaction] int;

alter table hr_data
alter column [hourly rate] int;  

alter table hr_data
alter column [job involvement] int;

alter table hr_data
alter column [job level] int; 

alter table hr_data
alter column [job satisfaction] int; 

alter table hr_data
alter column [monthly income] int; 

alter table hr_data
alter column [monthly rate] int; 

alter table hr_data
alter column [num companies worked] int; 

alter table hr_data
alter column [percent salary hike] int;  

alter table hr_data
alter column [performance rating] int; 

alter table hr_data
alter column [relationship satisfaction] int; 

alter table hr_data
alter column [standard hours] int; 

alter table hr_data
alter column [stock option level] int; 

alter table hr_data
alter column [total working years] int; 

alter table HR_DATA
alter column [work life balance] int; 

alter table hr_data
alter column [years at company] int; 

alter table hr_data
alter column [years in current role] int; 

alter table hr_data
alter column [years since last promotion] int; 

alter table hr_data
alter column [years with curr manager] int; 

--checking duplicates--
select *, ROW_NUMBER() over (order by [employee number]) from hr_data;
--none found--

--1. Compare an employee's performance rating with the average rating of their peers in the same department--
select hr.[employee number], hr.department, hr.[performance rating],
	   avg(hr_1.[performance rating]) as 'average_rating_in_department',
	   case 
			when hr.[performance rating] < avg(hr_1.[performance rating]) then 'below average'
			when hr.[performance rating] = avg(hr_1.[performance rating]) then 'average'
			when hr.[performance rating] > avg(hr_1.[performance rating]) then 'above average'
		end 
		as 'performance'
from 
	hr_data hr
inner join 
	hr_data hr_1
on 
	hr.department = hr_1.department
group by 
	hr.[employee number],hr.department,hr.[performance rating]
order by 
	hr.department;

--2. Analyze the trend of employee attrition over time--

declare @MaxYOE int;
set @MaxYOE=(Select max([Years At Company]) from hr_data);

while @MaxYOE>=1
begin
if ((select count(*) from hr_data where [years at company] = @MaxYOE)>0)
begin
	select  @MaxYOE as 'year_of_exp',(select count(*) from hr_data where [CF_current Employee]=0 and [Years At Company]=@MaxYOE) * 100.0/
	(select count(*) from hr_data where [Years At Company]=@MaxYOE)as attrition_rate 

end
set @MaxYOE=@MaxYOE-1;
end;


--3. Predict the likelihood of an employee leaving based on their age, job role, and performance rating--

--analysing attrition as per ageband, jobprofile and performance rating

create view job_based_attrition
as
select [job role],
    round(sum(case when attrition = 'yes' then 1 else 0 end)/ cast(count(*)as float) *100,1) as 'job_attrition_rate'
from hr_data
group by [job role];

create view age_based_attrition
as
select [cf_age band] ,
	round(sum(case when attrition = 'yes' then 1 else 0 end)/ cast(sum([Employee Count])as float) *100,1) as 'age_attrition_rate'
from hr_data 
group by [cf_age band],[Employee Count];

create view performance_based_attrition
as
select [performance rating],
    round(sum(case when attrition = 'yes' then 1 else 0 end)/ cast(count([Employee Count])as float)*100,1) as 'performance_attrition_rate'
from hr_data
group by [performance rating],[Employee Count];

select * from job_based_attrition
order by 
	job_attrition_rate desc;
select * from age_based_attrition
order by 
	age_attrition_rate desc;
select * from performance_based_attrition
order by 
	performance_attrition_rate desc;

--here we can see that
--on the basis of job roles sales representative, laboratry technician & human resources are highly likely 
--and sales executive, research scientist are likely to leave the org as compared to other job roles.

--on the similar note, the same trend is seen on the basis of age group where people under the age of 25 are highly likely
--while those in the bracket of 25-34 and over 55 are likely to leave when compared to rest of the age groups

--however, there is very less variation(almost neglible) in the attrition rate when we measure it on the performance rating of 3 and 4

--this would become the basis of further prediction

create function emp_leave_likely (@ageband as varchar (10), @jp as varchar(30), @rating as int)
returns varchar (20)
as
begin
	 declare @likelihood as varchar (20)
set @likelihood =
	case when @ageband = 'under 25' and
			  @jp in ('sales representative', 'laboratry technician','human resourcess') and
			  @rating = 4
			  then 'highly likely'
		 when @ageband in ('25 - 34', 'over 55') and 
			  @jp in ('sales executive','research scientist') 
			  then 'likely'
		 when @ageband not in ('under 25', '25 - 34', '35 - 44','45 - 54', 'over 55') or
			  @jp not in ('sales representative','laboratry technician','human resources','sales executive',
						  'research scientist','healthcare representative','manufacturing director', 'manager') or
			  @rating not in (3,4) 
			  then 'enter valid details'
		 else 'less likely'
	end
return @likelihood;
end;

select dbo.emp_leave_likely('over 55','healthcare representative',3) as 'likelihood to leave';

--4. Compare the attrition rate between different departments--
select department,
	   sum(case when attrition = 'yes' then 1 else 0 end) as 'count_of_attrition',count(*) as 'total_employees_in_department',
			concat(round(sum(case when attrition = 'yes' then 1 else 0 end)/ cast(count(*)as float) *100,1),'%') as 'attrition_rate'
from hr_data 
group by department
order by attrition_rate;

--5.Create Notification Alerts: Set up notification alerts in the database system to trigger when specific conditions are met
-- (e.g., sudden increase in attrition rate, take a threshold of >=10%)--

create table notifications
(
date_of_alert DATE,
alert varchar (100),
);

create trigger attrition_increase
on hr_data
after insert, update
as
begin
    declare @total_employees int;
    declare @attrition_count int;
    declare @attrition_rate decimal(5,2);
    
    set @total_employees = (select count(*) from hr_data);
    set @attrition_count = (select count(*) from hr_data where attrition = 'yes')
    SET @attrition_rate = (@attrition_count * 100.0 / nullif(@total_employees, 0));
    
    if @attrition_rate >= 10
    begin
		insert into notifications
				values(GETDATE(),('There is a sudden increase in attrition rate by: ' + cast(@attrition_rate as varchar) + '%'));
    end
end;

--6. Pivot data to compare the average hourly rate across different education fields--
select [education field],
       avg([hourly rate]) as average_hourly_rate
from hr_data
group by 
	[education field]
order by 
	average_hourly_rate desc;