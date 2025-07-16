CREATE PROCEDURE [dbo].[AttendeesMarkBatchAsEmailed]
    @BarcodeList NVARCHAR(MAX), -- Comma-separated list of barcodes
    @EmailSentDateTime DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Use current datetime if not provided
    IF @EmailSentDateTime IS NULL
        SET @EmailSentDateTime = GETDATE();
    
    -- Create a temporary table to hold the barcodes
    CREATE TABLE #TempBarcodes (
        Barcode NVARCHAR(50) NOT NULL
    );
    
    -- Split the comma-separated list and insert into temp table
    INSERT INTO #TempBarcodes (Barcode)
    SELECT LTRIM(RTRIM(value)) AS Barcode
    FROM STRING_SPLIT(@BarcodeList, ',')
    WHERE LTRIM(RTRIM(value)) != '';
    
    -- Insert new records for barcodes not already in AttendeesPrinted
    INSERT INTO dbo.AttendeesPrinted (Barcode, CreatedDatetime)
    SELECT 
        tb.Barcode, 
        @EmailSentDateTime
    FROM #TempBarcodes tb
    WHERE NOT EXISTS (
        SELECT 1 
        FROM dbo.AttendeesPrinted ap 
        WHERE ap.Barcode = tb.Barcode
    );
    
    DECLARE @NewCount INT = @@ROWCOUNT;
    
    -- Update existing records with new timestamp
    UPDATE ap
    SET CreatedDatetime = @EmailSentDateTime
    FROM dbo.AttendeesPrinted ap
    INNER JOIN #TempBarcodes tb ON ap.Barcode = tb.Barcode;
    
    DECLARE @UpdatedCount INT = @@ROWCOUNT - @NewCount;
    
    -- Return summary
    SELECT 
        'SUCCESS' AS Result,
        @NewCount AS NewRecords,
        @UpdatedCount AS UpdatedRecords,
        (@NewCount + @UpdatedCount) AS TotalProcessed,
        CONCAT('Processed ', (@NewCount + @UpdatedCount), ' attendees (', @NewCount, ' new, ', @UpdatedCount, ' updated)') AS Message;
    
    DROP TABLE #TempBarcodes;
END;
