/* =====================================================================
   SQL Interview Question: Find the Second Highest Salary (3 methods)
   Every query from the video, plus the "your turn" answer and the bonus question.
   Run the setup block once (it creates InterviewDB and dbo.Employees),
   then highlight one query and press F5 to run just that one.
   Expected answer: 95000 (Kabir Singh and Meera Nair).
   ===================================================================== */

-- Setup: a small database for interview practice (run once)
IF DB_ID(N'InterviewDB') IS NULL CREATE DATABASE InterviewDB;
GO
USE InterviewDB;
GO
IF OBJECT_ID(N'dbo.Employees') IS NOT NULL DROP TABLE dbo.Employees;
CREATE TABLE dbo.Employees (
    EmployeeID  INT           NOT NULL PRIMARY KEY,
    Name        NVARCHAR(100) NOT NULL,
    Department  NVARCHAR(50)  NOT NULL,
    Salary      INT           NULL       -- NULL = not set yet (new joiner)
);
INSERT INTO dbo.Employees (EmployeeID, Name, Department, Salary) VALUES
(1, N'Aarav Sharma', N'Engineering', 120000),
(2, N'Diya Patel', N'Engineering', 120000),
(3, N'Kabir Singh', N'Engineering', 95000),
(4, N'Meera Nair', N'Sales', 95000),
(5, N'Rohan Gupta', N'Sales', 80000),
(6, N'Sneha Reddy', N'Sales', 72000),
(7, N'Arjun Mehta', N'HR', 72000),
(8, N'Priya Iyer', N'HR', 65000),
(9, N'Vikram Joshi', N'HR', 58000),
(10, N'Ishaan Verma', N'Finance', 70000),
(11, N'Neha Kapoor', N'Sales', NULL);
GO

SELECT * FROM dbo.Employees ORDER BY Salary DESC, EmployeeID;

/* ---------- METHOD 1: SUBQUERY ---------- */

-- The highest salary below the highest salary: 95000 (one row; NULL if there is no second salary)
SELECT MAX(Salary) AS SecondHighest
FROM Employees
WHERE Salary < (SELECT MAX(Salary) FROM Employees);

-- Who earns it? Wrap it once more: Kabir Singh and Meera Nair
SELECT Name, Department, Salary
FROM Employees
WHERE Salary = (
    SELECT MAX(Salary) FROM Employees
    WHERE Salary < (SELECT MAX(Salary) FROM Employees)
);

-- The nested TOP version: 95000.
-- Trap: with only one distinct salary (try adding WHERE Department = 'Finance' inside), it returns that salary, not NULL.
SELECT TOP 1 Salary
FROM (SELECT DISTINCT TOP 2 Salary
      FROM Employees
      ORDER BY Salary DESC) AS t
ORDER BY Salary;

-- Nth highest without window functions or OFFSET: a correlated subquery
-- Nth highest without window functions or OFFSET (runs anywhere, but slow on big tables)
DECLARE @N INT = 2;
SELECT DISTINCT e1.Salary
FROM Employees AS e1
WHERE e1.Salary IS NOT NULL
  AND @N - 1 = (SELECT COUNT(DISTINCT e2.Salary)
                  FROM Employees AS e2
                  WHERE e2.Salary > e1.Salary);


/* ---------- METHOD 2: OFFSET / FETCH (SQL Server 2012+) ---------- */

-- WRONG: skips a row, not a salary. Returns 120000 (Diya ties with Aarav)
SELECT Salary
FROM Employees
ORDER BY Salary DESC
OFFSET 1 ROW FETCH NEXT 1 ROW ONLY;

-- RIGHT: DISTINCT first, then skip one: 95000
SELECT DISTINCT Salary
FROM Employees
ORDER BY Salary DESC
OFFSET 1 ROW FETCH NEXT 1 ROW ONLY;

-- Edge case: Finance has one salary, so this returns 0 rows (not NULL)
SELECT DISTINCT Salary
FROM Employees
WHERE Department = 'Finance'
ORDER BY Salary DESC
OFFSET 1 ROW FETCH NEXT 1 ROW ONLY;

-- Wrapped as a scalar subquery: 1 row with NULL
SELECT (
    SELECT DISTINCT Salary
    FROM Employees
    WHERE Department = 'Finance'
    ORDER BY Salary DESC
    OFFSET 1 ROW FETCH NEXT 1 ROW ONLY
) AS SecondHighest;

-- Nth highest with a variable: OFFSET @N - 1 ROWS (NULL if there is no Nth salary)
DECLARE @N INT = 2;
SELECT (SELECT DISTINCT Salary
        FROM Employees
        ORDER BY Salary DESC
        OFFSET @N - 1 ROWS FETCH NEXT 1 ROW ONLY) AS NthHighest;

-- MySQL / PostgreSQL: SELECT DISTINCT Salary FROM Employees ORDER BY Salary DESC LIMIT 1 OFFSET 1;


/* ---------- METHOD 3: DENSE_RANK in a CTE ---------- */

-- ROW_NUMBER vs RANK vs DENSE_RANK on the tie: only DENSE_RANK puts 95000 at number 2
SELECT Name, Salary,
       ROW_NUMBER() OVER (ORDER BY Salary DESC, EmployeeID) AS RowNum,
       RANK()       OVER (ORDER BY Salary DESC) AS RankNo,
       DENSE_RANK() OVER (ORDER BY Salary DESC) AS DenseRank
FROM Employees
ORDER BY Salary DESC, EmployeeID;

-- Second highest salary, with every employee who earns it: Kabir Singh and Meera Nair
WITH Ranked AS (
    SELECT Name, Department, Salary,
           DENSE_RANK() OVER (ORDER BY Salary DESC) AS SalaryRank
    FROM Employees
)
SELECT Name, Department, Salary
FROM Ranked
WHERE SalaryRank = 2;

-- DENSE_RANK, but always exactly one row (NULL when there is no rank 2)
WITH Ranked AS (
    SELECT Salary, DENSE_RANK() OVER (ORDER BY Salary DESC) AS SalaryRank
    FROM Employees
    WHERE Salary IS NOT NULL
)
SELECT MAX(Salary) AS SecondHighest
FROM Ranked
WHERE SalaryRank = 2;

-- Second highest salary in every department: 3 rows (Finance has no rank 2)
WITH Ranked AS (
    SELECT Name, Department, Salary,
           DENSE_RANK() OVER (PARTITION BY Department
                              ORDER BY Salary DESC) AS DeptRank
    FROM Employees
)
SELECT Department, Name, Salary
FROM Ranked
WHERE DeptRank = 2
ORDER BY Department;

-- Every department listed, NULL when it has no second highest salary (Finance)
WITH Ranked AS (
    SELECT Department, Name, Salary,
           DENSE_RANK() OVER (PARTITION BY Department ORDER BY Salary DESC) AS DeptRank
    FROM Employees
    WHERE Salary IS NOT NULL
)
SELECT d.Department, r.Name, r.Salary
FROM (SELECT DISTINCT Department FROM Employees) AS d
LEFT JOIN Ranked AS r ON r.Department = d.Department AND r.DeptRank = 2
ORDER BY d.Department;


/* ---------- YOUR TURN: the third highest salary (Rohan Gupta, 80000) ---------- */

-- DENSE_RANK
WITH Ranked AS (
    SELECT Name, Department, Salary,
           DENSE_RANK() OVER (
             ORDER BY Salary DESC) AS SalaryRank
    FROM Employees
)
SELECT Name, Department, Salary
FROM Ranked
WHERE SalaryRank = 3;

-- OFFSET FETCH: skip two distinct salaries
SELECT DISTINCT Salary
FROM Employees
ORDER BY Salary DESC
OFFSET 2 ROWS FETCH NEXT 1 ROW ONLY;

-- Subquery: one more level of nesting
SELECT MAX(Salary) AS ThirdHighest
FROM Employees
WHERE Salary < (SELECT MAX(Salary) FROM Employees
                WHERE Salary < (SELECT MAX(Salary) FROM Employees));


/* ---------- BONUS QUESTION (from the recap) ---------- */

-- Third highest salary in every department: 2 rows (HR: Vikram Joshi 58000, Sales: Sneha Reddy 72000).
-- Engineering (only two different salaries) and Finance (one person) have no third salary.
WITH Ranked AS (
    SELECT Name, Department, Salary,
           DENSE_RANK() OVER (PARTITION BY Department
                              ORDER BY Salary DESC) AS DeptRank
    FROM Employees
)
SELECT Department, Name, Salary
FROM Ranked
WHERE DeptRank = 3
ORDER BY Department;
