-- Step 1: Add a log table to track student changes
USE StudentDB;
GO

-- Create a log table
CREATE TABLE StudentChanges (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    StudentID INT,
    ChangeType VARCHAR(20),   -- "Add", "Update", or "Delete"
    ChangeDate DATETIME DEFAULT GETDATE(),
    ChangedBy VARCHAR(50) DEFAULT SYSTEM_USER
);
GO

-- Insert a log entry when we make changes later
INSERT INTO StudentChanges (StudentID, ChangeType)
VALUES (1, 'Test Entry');
GO

-- Check that it worked
SELECT * FROM StudentChanges;
GO

-----------------------
-- Step 2: Add a few more students to the database
USE StudentDB;
GO

-- Add three more students
INSERT INTO Students (FirstName, LastName, Email, EnrollmentDate)
VALUES 
('Emma', 'Wilson', 'emma.wilson@example.com', '2023-09-01'),
('James', 'Taylor', 'james.taylor@example.com', '2023-09-15'),
('Olivia', 'Brown', 'olivia.brown@example.com', '2023-08-15');
GO

-- Log these changes
INSERT INTO StudentChanges (StudentID, ChangeType)
VALUES 
((SELECT StudentID FROM Students WHERE Email = 'emma.wilson@example.com'), 'Add'),
((SELECT StudentID FROM Students WHERE Email = 'james.taylor@example.com'), 'Add'),
((SELECT StudentID FROM Students WHERE Email = 'olivia.brown@example.com'), 'Add');
GO

-- View all students
SELECT * FROM Students;
GO
-----------------------------
-- Step 3: Create a simple index to improve performance
USE StudentDB;
GO

-- Create an index on LastName to make student searches faster
CREATE NONCLUSTERED INDEX IX_Students_LastName
ON Students(LastName);
GO

-- Test the index with a simple query
SELECT * FROM Students
WHERE LastName LIKE 'B%';
GO
-----------
-- Step 4: Create a simple backup of your database
USE master;
GO

-- Create a backup using a path that SQL Server has access to
BACKUP DATABASE StudentDB 
TO DISK = '/var/opt/mssql/data/StudentDB_Backup.bak' 
WITH FORMAT,
    NAME = 'StudentDB-Simple-Backup';
GO

-- Verify the backup exists
SELECT 
    database_name,
    backup_start_date,
    backup_finish_date,
    backup_size/1024/1024 AS backup_size_mb
FROM msdb.dbo.backupset
WHERE database_name = 'StudentDB'
ORDER BY backup_finish_date DESC;
GO

-- Step 5: Generate an Excel export of student grades
USE StudentDB;
GO

-- Run this query and export the results to Excel
-- by clicking the "Save As Excel" button in the results toolbar
SELECT 
    s.StudentID,
    s.FirstName,
    s.LastName,
    c.CourseName,
    c.Credits,
    e.Grade
FROM 
    Students s
    JOIN Enrollments e ON s.StudentID = e.StudentID
    JOIN Courses c ON e.CourseID = c.CourseID
ORDER BY 
    s.LastName, s.FirstName, c.CourseName;
GO

-- Save this as "StudentGrades.xlsx" when prompted