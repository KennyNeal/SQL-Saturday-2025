CREATE PROCEDURE [dbo].[AttendeesGetForEmail]
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Get attendees who haven't been emailed yet (no entry in AttendeesPrinted)
    SELECT 
        a.Barcode,
        a.First_Name,
        a.Last_Name,
        a.Email,
        a.Order_Date,
        a.Job_Title,
        a.Company
    FROM 
        dbo.AttendeesGetUnPrintedOrders a
    WHERE 
        NOT EXISTS (
            SELECT 1 
            FROM dbo.AttendeesPrinted ap 
            WHERE ap.Barcode = a.Barcode
        )
        AND a.Email IS NOT NULL
        AND a.Email != ''
        AND a.First_Name IS NOT NULL
        AND a.Last_Name IS NOT NULL
    ORDER BY 
        a.Last_Name, 
        a.First_Name;
END;
