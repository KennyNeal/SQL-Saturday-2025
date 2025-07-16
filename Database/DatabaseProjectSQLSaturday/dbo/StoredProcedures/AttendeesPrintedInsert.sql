CREATE PROCEDURE [dbo].[AttendeesPrintedInsert]
AS
    BEGIN
        SET NOCOUNT ON;
        INSERT INTO
            dbo.AttendeesPrinted
            ([Barcode], CreatedDatetime)
        SELECT
            agupo.[Barcode], GETDATE()
        FROM
            [dbo].[AttendeesGetUnPrintedOrders] AS agupo
        WHERE
            NOT EXISTS
            (
                SELECT
                    1
                FROM
                    dbo.AttendeesPrinted AS ap
                WHERE
                    ap.[Barcode] = agupo.[Barcode]
            )
        GROUP BY
            agupo.[Barcode];
    END;

GO

