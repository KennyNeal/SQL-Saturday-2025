CREATE PROCEDURE [dbo].[AttendeesPrintedInsert]
AS
    BEGIN
        SET NOCOUNT ON;
        INSERT INTO
            dbo.AttendeesPrinted
            ([Order], CreatedDatetime)
        SELECT
            agupo.[Order], GETDATE()
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
                    ap.[Order] = agupo.[Order]
            )
        GROUP BY
            agupo.[Order];
    END;

GO

