-- Step 3: Implement Grade Change Auditing
USE StudentDB;
GO

-- Create a trigger to audit grade changes
CREATE TRIGGER tr_Grades_Audit
ON Enrollments
AFTER UPDATE
AS
BEGIN
    -- Only capture changes where the grade was actually modified
    IF UPDATE(Grade)
    BEGIN
        INSERT INTO Grades_Audit (StudentID, CourseID, OldGrade, NewGrade, ChangedBy)
        SELECT 
            d.StudentID, 
            d.CourseID,
            d.Grade AS OldGrade,
            i.Grade AS NewGrade,
            SYSTEM_USER AS ChangedBy
        FROM 
            deleted d
            JOIN inserted i ON d.StudentID = i.StudentID AND d.CourseID = i.CourseID
        WHERE 
            d.Grade &lt;&gt; i.Grade;
    END
END;
GO

-- Add sample faculty members
INSERT INTO Faculty (FirstName, LastName, Email, Department, Position, HireDate)
VALUES 
('John', 'Smith', 'john.smith@university.edu', 'Computer Science', 'Professor', '2018-08-15'),
('Maria', 'Garcia', 'maria.garcia@university.edu', 'Information Technology', 'Associate Professor', '2020-01-10'),
('Robert', 'Johnson', 'robert.johnson@university.edu', 'Computer Science', 'Assistant Professor', '2021-08-15');
GO

-- Test the grade audit trigger
-- Update a grade
UPDATE Enrollments
SET Grade = 'A'
WHERE StudentID = 1 AND CourseID = 1;
GO

-- View audit log
SELECT * FROM Grades_Audit;
GO