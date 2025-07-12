CREATE PROCEDURE [dbo].[AttendeesInsert]
    @Order nvarchar(50),
    @Order_Date datetime = NULL,
    @Prefix nvarchar(50) = NULL,
    @First_Name nvarchar(100) = NULL,
    @Last_Name nvarchar(100) = NULL,
    @Email nvarchar(255) = NULL,
    @Quantity int = NULL,
    @Ticket_Type nvarchar(100) = NULL,
    @Attendee nvarchar(255) = NULL,
    @Barcode nvarchar(100) = NULL,
    @Order_Type nvarchar(50) = NULL,
    @Attendee_Status nvarchar(50) = NULL,
    @Home_Address_1 nvarchar(255) = NULL,
    @Home_Address_2 nvarchar(255) = NULL,
    @Home_City nvarchar(100) = NULL,
    @Home_State nvarchar(100) = NULL,
    @Home_Zip nvarchar(20) = NULL,
    @Home_Country nvarchar(100) = NULL,
    @Cell_Phone nvarchar(50) = NULL,
    @Accept_Code_of_Conduct nvarchar(10) = NULL,
    @Lunch_Type nvarchar(50) = NULL,
    @Are_you_willing_to_volunteer_during_the_event nvarchar(10) = NULL,
    @Twitter_X_UserName nvarchar(50) = NULL,
    @LinkedIn_URL nvarchar(255) = NULL,
    @Job_Title nvarchar(100) = NULL,
    @Company nvarchar(100) = NULL,
    @Work_Phone nvarchar(50) = NULL,
    @Website nvarchar(255) = NULL,
    @Blog nvarchar(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.Attendees (
        [Order], [Order_Date], [Prefix], [First_Name], [Last_Name], [Email], [Quantity], [Ticket_Type], [Attendee], [Barcode], [Order_Type], [Attendee_Status],
        [Home_Address_1], [Home_Address_2], [Home_City], [Home_State], [Home_Zip], [Home_Country], [Cell_Phone], [Accept_Code_of_Conduct], [Lunch_Type],
        [Are_you_willing_to_volunteer_during_the_event], [Twitter_X_UserName], [LinkedIn_URL], [Job_Title], [Company], [Work_Phone], [Website], [Blog]
    )
    VALUES (
        @Order, @Order_Date, @Prefix, @First_Name, @Last_Name, @Email, @Quantity, @Ticket_Type, @Attendee, @Barcode, @Order_Type, @Attendee_Status,
        @Home_Address_1, @Home_Address_2, @Home_City, @Home_State, @Home_Zip, @Home_Country, @Cell_Phone, @Accept_Code_of_Conduct, @Lunch_Type,
        @Are_you_willing_to_volunteer_during_the_event, @Twitter_X_UserName, @LinkedIn_URL, @Job_Title, @Company, @Work_Phone, @Website, @Blog
    );
END