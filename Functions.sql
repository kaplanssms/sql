/*
List of all TSQL Functions
*/

/*
=================
Numeric Functions
=================
*/
--The ABS() function returns the absolute value of X.
SELECT ABS(-2);

--These functions return the smallest integer value that is not smaller than X
-- Select rows from a Table or View '[TableOrViewName]' in schema '[dbo]'
SELECT CEILING(3.46);

--This function returns the largest integer value that is not greater than X.
SELECT FLOOR(7.55);

--The FORMAT() function is used to format the number X in the following format
SELECT FORMAT( GETDATE(), 'dd/MM/yyyy', 'en-US' ) AS 'DateTime Result'  
       , FORMAT(123456789,'###-##-####') AS 'Custom Number Result';

--Returns the remainder of one number divided by another.
SELECT 29 % 3;

--This function simply returns the value of pi.
SELECT PI();

--This functions return the value of X raised to the power of Y.
SELECT POWER(3,3);

--This function returns X rounded to the nearest integer, unless decimal is supplied.
SELECT ROUND(5.693893,2);

--This function returns the non-negative square root of X.
SELECT SQRT(49);


/*
=================
String Functions
=================
*/

SELECT CONCAT('My', 'S', 'QL');
SELECT SPACE(6);

SELECT TOP 100
    ae.adenrollid,
    IIF(ae.ExpStartDate > '20180101','20180101',cast(ae.ExpStartDate as date)) AS ExpStartDateAdj,
    ae.ExpStartDate
FROM c2000.dbo.adenroll ae(nolock)
ORDER BY ae.AdEnrollID DESC

Select Difference('Smith','Smyth');

Select STUFF('ABCDEFGH', 2,0,'IJK') ;

Select STR(187.369,6,2) 

SELECT  Substring('state',1,4); 

/*
test git push
*/