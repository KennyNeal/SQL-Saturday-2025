
CREATE OR ALTER VIEW [dbo].[AttendeesGetUnPrintedOrders]
AS
    SELECT
        TOP 100 PERCENT
        agupob.rownumber,
        agupob.Barcode,
        agupob.Order_Date,
        agupob.First_Name,
        agupob.Last_Name,
        agupob.Email,
        agupob.Cell_Phone,
        agupob.Twitter_Handle,
        agupob.Job_Title,
        agupob.Company,
        agupob.Website,
        agupob.Blog,
        agupob.vCard,
        agupob.Lunch_Type
    FROM
        dbo.AttendeesGetUnPrintedOrdersBase AS agupob
    WHERE
        agupob.rownumber = 1
    ORDER BY
        agupob.Last_Name,
        agupob.First_Name;

GO

