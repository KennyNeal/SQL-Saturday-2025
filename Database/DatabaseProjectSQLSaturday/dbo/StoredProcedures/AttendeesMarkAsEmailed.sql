CREATE PROCEDURE [dbo].[AttendeesMarkAsEmailed]
    @Barcode NVARCHAR(50),
    @EmailSentDateTime DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Use current datetime if not provided
    IF @EmailSentDateTime IS NULL
        SET @EmailSentDateTime = GETDATE();
    
    -- Insert or update the AttendeesPrinted table to mark as emailed
    IF NOT EXISTS (SELECT 1 FROM dbo.AttendeesPrinted WHERE Barcode = @Barcode)
    BEGIN
        INSERT INTO dbo.AttendeesPrinted (Barcode, CreatedDatetime)
        VALUES (@Barcode, @EmailSentDateTime);
        
        SELECT 'SUCCESS' AS Result, 'Attendee marked as emailed' AS Message;
    END
    ELSE
    BEGIN
        -- Already exists, optionally update the datetime
        UPDATE dbo.AttendeesPrinted 
        SET CreatedDatetime = @EmailSentDateTime 
        WHERE Barcode = @Barcode;
        
        SELECT 'INFO' AS Result, 'Attendee was already marked as emailed - updated timestamp' AS Message;
    END
END;
