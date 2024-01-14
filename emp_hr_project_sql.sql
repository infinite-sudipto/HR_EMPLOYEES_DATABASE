USE EMPLOYEES;
SET @@sql_mode = SYS.LIST_DROP(@@sql_mode, 'ONLY_FULL_GROUP_BY');
SELECT@@sql_mode;

# 1. create a procedure to check the latest salary where input is employee_number.
drop procedure if exists emp_latest_sal ;
delimiter $$
create procedure emp_latest_sal(in emp_id int, out e_salary int)
begin
select salary into e_salary 
from salaries 
where to_date in 
            (select max(to_date) 
            from salaries)
and emp_id  = emp_no;

end $$
delimiter ;

# calling parametric procedure
call employees.emp_latest_sal(10001,@e_salary);
select @e_salary;


#2. create a function to see how many male and female candidates are there.

drop function if exists gender;

delimiter $$
create function gender( sex enum('m','f'))
returns int
deterministic no sql reads sql data
begin
declare no_of_employees int;
select 
count(emp_no) into no_of_employees
from
emp_data as e 
where e.gender = sex ;
return no_of_employees;
end $$
delimiter ;

# calling function
select employees.gender('f');

# 3. extract emploee's all details, latest salry , latest contract who is currently working.

SELECT 
    e.emp_no,
    e.first_name,
    e.last_name,
    e.birth_date,
    e.gender,
    e.hire_date,
    s.salary,
    s.from_date,
    s.to_date
FROM
    salaries AS s
        JOIN
    (SELECT 
        MAX(to_date) AS to_date_c
    FROM
        salaries) AS s1 ON s.to_date = s1.to_date_c
        JOIN
    emp_data AS e ON s.emp_no = e.emp_no;

#4. top 3 highest paid employees who are working currently.

select latest_contract.*
from
(SELECT 
    e.emp_no,
    e.first_name,
    e.last_name,
    e.birth_date,
    e.gender,
    e.hire_date,
    s.salary,
    s.from_date,
    s.to_date,
    dense_rank() over(order by s.salary desc) as sr_no
FROM
    salaries AS s
        JOIN
    (SELECT 
        MAX(to_date) AS to_date_c
    FROM
        salaries) AS s1 ON s.to_date = s1.to_date_c
        JOIN
    emp_data AS e ON s.emp_no = e.emp_no) as latest_contract
    where latest_contract.sr_no <= 3;



#5. 3 highest paid managers who are working currently.

with t1 as 
(
select 
        dense_rank() over(order by s.salary desc) as sr_no,
		dm.emp_no,
		e.first_name,
		e.last_name,
		e.gender,
		e.birth_date,
		e.hire_date,
		s.salary,
		s.to_date,
		s.from_date
from
      (select *
        from
         dept_manager where to_date in (select max(to_date) from dept_manager) )as dm
join
       emp_data as e 
       on e.emp_no = dm.emp_no
join
       salaries as s
       on s.emp_no = dm.emp_no
join
       departments as d 
       on d.dept_no = dm.dept_no
	   where s.to_date in
                         (select max(to_date) 
                         from salaries)
)
         select *
         from t1
         where sr_no <=3   ; 


#6. which department's average salary of all time is highest?

SELECT 
    de.dept_no,
    d.dept_name,
    ROUND(AVG(s.salary), 2) AS average_salary
FROM
    salaries AS s
        JOIN
    dept_emp AS de ON de.emp_no = s.emp_no
        JOIN
    departments AS d ON de.dept_no = d.dept_no
GROUP BY de.dept_no
ORDER BY average_salary DESC;


#7. extract a list about all managers who were hired between 1st jan ,1990 and 1st jan, 1995.
SELECT 
    *
FROM
    (SELECT 
        de.emp_no,
            de.dept_no,
            e.first_name,
            e.last_name,
            e.gender,
            e.birth_date,
            e.hire_date
    FROM
        dept_manager AS de
    JOIN emp_data AS e ON e.emp_no = de.emp_no
    JOIN departments AS d ON de.dept_no = d.dept_no) AS manager_info
WHERE
    manager_info.hire_date BETWEEN '1990-01-01' AND '1995-01-01';

#8. create a procedure to see average salary of male and female.

drop procedure if exists avg_salary_g;
delimiter $$
create procedure avg_salary_g(in sex enum('M','F'),out avg_salary decimal(10,2))
begin 
select avg(salary) into avg_salary
from
emp_data as e 
join
(select emp_no, salary from salaries where to_date in (select max(to_date) from salaries )) as s1
on e.emp_no = s1.emp_no
where e.gender = sex
group by e.gender;
 end $$
 delimiter ;
 
 # CALLING PROCEDURE
 set @avg_salary = 0;
call employees.avg_salary_g('F', @avg_salary);
SELECT @avg_salary;


# 9 . create a view of all employees with a status wheteher he/she is manager or not.
CREATE OR REPLACE VIEW employee_status AS
    SELECT 
        e.emp_no,
        e.first_name,
        e.last_name,
        CASE
            WHEN de.emp_no IS NOT NULL THEN 'MANAGER'
            ELSE 'EMPLOYEES'
        END AS E_STAT
    FROM
        emp_data AS e
            LEFT JOIN
        dept_manager AS de ON e.emp_no = de.emp_no
    ORDER BY e.emp_no ASC;


# calling the view -- 

SELECT 
    *
FROM
    employees.employee_status
WHERE
    e_stat = 'manager';





# 10.EXTRACT a list of all the managers who are currently working and their respective pieces of information with latest salary.

SELECT 
    t1.emp_no,
    t1.first_name,
    t1.last_name,
    t1.gender,
    t1.birth_date,
    t1.hire_date,
    t1.dept_no,
    t1.to_date,
    s1.salary,
    d.dept_name
FROM
    (SELECT 
        e.emp_no,
            e.first_name,
            e.last_name,
            e.gender,
            e.birth_date,
            e.hire_date,
            de.dept_no,
            de.to_date
    FROM
        emp_data AS e
    JOIN dept_manager AS de ON e.emp_no = de.emp_no
    WHERE
        de.to_date IN (SELECT 
                MAX(to_date)
            FROM
                dept_manager)) AS t1
        JOIN
    (SELECT 
        emp_no, salary
    FROM
        salaries
    WHERE
        to_date IN (SELECT 
                MAX(to_date)
            FROM
                salaries)) AS s1 ON t1.emp_no = s1.emp_no
        JOIN
    departments AS d ON d.dept_no = t1.dept_no
ORDER BY s1.salary DESC;

# 11. CREATE A FUNCTION TO SEE THE EMPLOYEE'S BIRTHDATE BY ONLY USING EMPLOYEE ID.

drop function IF EXISTS DOB ;
delimiter $$ 
create function DOB( eno int)
returns date
deterministic no sql reads sql data
begin
declare DOB date;
SELECT 
    birth_date
INTO DOB FROM
    emp_data
WHERE
    emp_no = eno;
return DOB;
end $$
delimiter ;
select employees.DOB(10001) AS DATE_OF_BIRTH;


# 12. CREATE A PROCEDURE TO SEE ALL EMPLOYEES INFORMATION( EX. AND PRESENT ).


DROP PROCEDURE IF EXISTS INFO;
DELIMITER $$
CREATE PROCEDURE INFO (IN ENO INT)
BEGIN
SELECT *
FROM
EMP_DATA AS E 
JOIN SALARIES AS S 
ON E.EMP_NO =S.EMP_NO 
WHERE E.EMP_NO = ENO;
END $$ 
DELIMITER ;



# 13. How many active employees are there in the organisation?
SELECT 
    COUNT(DISTINCT emp_no) AS Total_no_of_employees
FROM
    salaries
WHERE
    to_date IN (SELECT 
            MAX(to_date)
        FROM
            salaries);

# 14. how many employees are listed in organisation's database/
SELECT 
    COUNT(DISTINCT emp_no) AS Total_listed_employees
FROM
    emp_data;













