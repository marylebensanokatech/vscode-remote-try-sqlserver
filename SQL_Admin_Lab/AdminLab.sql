-- Create users for our StudentDB database
USE master;
GO

-- Check if logins exist and drop them if they do
IF EXISTS (SELECT name FROM sys.server_principals WHERE name = 'Professor')
BEGIN
    DROP LOGIN [Professor];
END
GO

IF EXISTS (SELECT name FROM sys.server_principals WHERE name = 'Student')
BEGIN
    DROP LOGIN [Student];
END
GO

-- Create logins
CREATE LOGIN Professor WITH PASSWORD = 'Prof@123';
CREATE LOGIN Student WITH PASSWORD = 'Student@123';
GO

-- Create database users and assign permissions
USE StudentDB;
GO

-- Create users
CREATE USER Professor FOR LOGIN Professor;
CREATE USER Student FOR LOGIN Student;
GO

-- Grant Professor full access to manage the database
ALTER ROLE db_owner ADD MEMBER Professor;
GO

-- Grant Student read-only access to the database
ALTER ROLE db_datareader ADD MEMBER Student;
GO

-- Verify creation - list all users and their roles
SELECT 
    dp.name AS DatabaseUser,
    CASE dp.type
        WHEN 'S' THEN 'SQL User'
        WHEN 'U' THEN 'Windows User'
        WHEN 'G' THEN 'Windows Group'
        WHEN 'A' THEN 'Application Role'
        WHEN 'R' THEN 'Database Role'
        ELSE dp.type
    END AS AccountType,
    rp.name AS DatabaseRole
FROM sys.database_principals dp
LEFT JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
LEFT JOIN sys.database_principals rp ON drm.role_principal_id = rp.principal_id
WHERE dp.name IN ('Professor', 'Student', 'dbo');
GO

-- Implement Row-Level Security for Students table
-- This will restrict students to only see their own records
USE StudentDB;
GO

-- First, add an Email column to the Students table if it doesn't exist
-- We'll use this to match with the user's login name
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Students') AND name = 'Email') 
BEGIN
    PRINT 'Email column already exists in Students table';
END
ELSE
BEGIN
    -- The Email column already exists based on Module 10 lab
    PRINT 'Email column already exists in Students table';
END
GO

-- Create security predicate function
-- This function controls which rows each user can see
CREATE FUNCTION dbo.fn_StudentSecurityPredicate(@StudentEmail VARCHAR(100))
RETURNS TABLE
WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS fn_result
    -- Users can see only their own records (except professors and dbo who see all)
    WHERE @StudentEmail = USER_NAME() 
       OR USER_NAME() = 'Professor' 
       OR USER_NAME() = 'dbo';
GO

-- Apply security policy
-- This enforces RLS automatically on all queries
CREATE SECURITY POLICY StudentFilter
ADD FILTER PREDICATE dbo.fn_StudentSecurityPredicate(Email)
ON dbo.Students;
GO

-- Insert test data with student accounts matching login names
-- Add a couple of students that correspond to our security model
INSERT INTO Students (FirstName, LastName, Email, EnrollmentDate)
VALUES 
('Test', 'Student', 'Student', '2023-10-01');
GO

-- Test the security by querying as dbo (should see all rows)
SELECT * FROM Students;
GO

-- To test as Student, open a new terminal and connect as that user:
-- sqlcmd -S localhost -U Student -P Student@123 -d StudentDB -Q "SELECT * FROM Students;"

-- Implement indexing strategies for better performance
USE StudentDB;
GO

-- First, let's add more data to our tables to better demonstrate indexing benefits
-- Add more students (if needed)
INSERT INTO Students (FirstName, LastName, Email, EnrollmentDate)
VALUES 
('Jane', 'Wilson', 'jane.wilson@example.com', '2023-09-01'),
('Michael', 'Brown', 'michael.brown@example.com', '2023-09-01'),
('Emily', 'Davis', 'emily.davis@example.com', '2023-09-15'),
('David', 'Miller', 'david.miller@example.com', '2023-08-15'),
('Sarah', 'Anderson', 'sarah.anderson@example.com', '2023-08-15');
GO

-- Add more courses (if needed)
INSERT INTO Courses (CourseName, Credits, Department)
VALUES 
('Machine Learning', 4, 'Computer Science'),
('Database Administration', 3, 'Information Technology'),
('Cybersecurity Fundamentals', 3, 'Information Technology'),
('Software Engineering', 4, 'Computer Science'),
('Project Management', 3, 'Business');
GO

-- Create enrollments - we'll create many enrollments for demonstrating index performance
-- First, let's get the student and course IDs
DECLARE @StudentCount INT, @CourseCount INT;
SELECT @StudentCount = COUNT(*) FROM Students;
SELECT @CourseCount = COUNT(*) FROM Courses;

-- Now create many enrollments for performance testing
DECLARE @i INT = 1;
DECLARE @MaxEnrollments INT = 500; -- Adjust as needed
DECLARE @RandomStudent INT, @RandomCourse INT;
DECLARE @Grades VARCHAR(2);
DECLARE @GradeOptions TABLE (Grade VARCHAR(2));
INSERT INTO @GradeOptions VALUES ('A'), ('A-'), ('B+'), ('B'), ('B-'), ('C+'), ('C'), ('C-'), ('D'), ('F');

WHILE @i &lt;= @MaxEnrollments
BEGIN
    SET @RandomStudent = FLOOR(RAND() * @StudentCount) + 1;
    SET @RandomCourse = FLOOR(RAND() * @CourseCount) + 1;
    
    -- Select a random grade
    SELECT TOP 1 @Grades = Grade FROM @GradeOptions ORDER BY NEWID();
    
    -- Insert enrollment if it doesn't exist already
    IF NOT EXISTS (SELECT 1 FROM Enrollments WHERE StudentID = @RandomStudent AND CourseID = @RandomCourse)
    BEGIN
        INSERT INTO Enrollments (StudentID, CourseID, EnrollmentDate, Grade)
        VALUES (@RandomStudent, @RandomCourse, 
                DATEADD(DAY, -FLOOR(RAND() * 180), GETDATE()), -- Random date in last 6 months
                @Grades);
    END
    
    SET @i = @i + 1;
END
GO

-- Create indexes to optimize common queries
-- Index for finding all courses a student is enrolled in
CREATE NONCLUSTERED INDEX IX_Enrollments_StudentID
ON Enrollments(StudentID);
GO

-- Index for finding all students in a course
CREATE NONCLUSTERED INDEX IX_Enrollments_CourseID
ON Enrollments(CourseID);
GO

-- Composite index for finding enrollments by date range
CREATE NONCLUSTERED INDEX IX_Enrollments_DateGrade
ON Enrollments(EnrollmentDate, Grade);
GO

-- Index for searching students by name
CREATE NONCLUSTERED INDEX IX_Students_Name
ON Students(LastName, FirstName);
GO


-- Test query performance with and without indexes
USE StudentDB;
GO

-- Turn on statistics to measure performance
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

-- Query 1: Find all courses for a specific student (should use index)
PRINT '---------- Query 1: Find all courses for a student ----------';
SELECT 
    s.FirstName + ' ' + s.LastName AS StudentName,
    c.CourseName,
    e.Grade,
    e.EnrollmentDate
FROM 
    Students s
    JOIN Enrollments e ON s.StudentID = e.StudentID
    JOIN Courses c ON e.CourseID = c.CourseID
WHERE 
    s.StudentID = 1;
GO

-- Query 2: Find all students in a specific course (should use index)
PRINT '---------- Query 2: Find all students in a course ----------';
SELECT 
    c.CourseName,
    s.FirstName + ' ' + s.LastName AS StudentName,
    e.Grade,
    e.EnrollmentDate
FROM 
    Courses c
    JOIN Enrollments e ON c.CourseID = e.CourseID
    JOIN Students s ON e.StudentID = s.StudentID
WHERE 
    c.CourseID = 1;
GO

-- Query 3: Find enrollments by date range and grade (should use index)
PRINT '---------- Query 3: Find enrollments by date range and grade ----------';
SELECT 
    s.FirstName + ' ' + s.LastName AS StudentName,
    c.CourseName,
    e.Grade,
    e.EnrollmentDate
FROM 
    Enrollments e
    JOIN Students s ON e.StudentID = s.StudentID
    JOIN Courses c ON e.CourseID = c.CourseID
WHERE 
    e.EnrollmentDate BETWEEN '2023-08-01' AND '2023-09-30'
    AND e.Grade = 'A';
GO

-- Query 4: Search students by name (should use index)
PRINT '---------- Query 4: Search students by name ----------';
SELECT 
    StudentID,
    FirstName,
    LastName,
    Email,
    EnrollmentDate
FROM 
    Students
WHERE 
    LastName LIKE 'S%'
ORDER BY 
    LastName, FirstName;
GO

-- Turn off statistics
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

-- Perform full database backup
-- This creates a complete backup of the database
USE master;
GO

BACKUP DATABASE StudentDB 
TO DISK = '/workspace/SQL_Admin_Lab/Backups/StudentDB.bak' 
WITH FORMAT,                -- Overwrite any existing backup
    MEDIANAME = 'StudentDBBackup',
    NAME = 'StudentDB-Full';
GO

-- Verify backup completion and size
-- This shows details of our backup operation
SELECT 
    database_name,
    backup_start_date,
    backup_finish_date,
    backup_size/1024/1024 AS backup_size_mb
FROM msdb.dbo.backupset
WHERE database_name = 'StudentDB'
ORDER BY backup_finish_date DESC;
GO

-- Add test record for recovery verification
-- This record should disappear after restore
USE StudentDB;
GO

INSERT INTO Students (FirstName, LastName, Email, EnrollmentDate)
VALUES ('Temporary', 'Student', 'temp.student@example.com', GETDATE());
GO

-- Verify the test record was added
SELECT * FROM Students WHERE FirstName = 'Temporary';
GO

-- Perform database restore
-- This returns the database to the state it was in when backed up
USE master;
GO

ALTER DATABASE StudentDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;  -- Disconnect other users
GO

RESTORE DATABASE StudentDB 
FROM DISK = '/workspace/SQL_Admin_Lab/Backups/StudentDB.bak' 
WITH REPLACE;  -- Replace existing database
GO

-- Set database back to multi-user mode
ALTER DATABASE StudentDB SET MULTI_USER;
GO

-- Verify restore by checking the temporary record is gone
USE StudentDB;
GO

SELECT * FROM Students WHERE FirstName = 'Temporary';
GO