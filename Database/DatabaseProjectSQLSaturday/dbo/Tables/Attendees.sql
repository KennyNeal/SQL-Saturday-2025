CREATE TABLE [dbo].[Attendees] (
    [Order]                                         VARCHAR (50)   NULL,
    [Order_Date]                                    NVARCHAR (50)  NULL,
    [Prefix]                                        NVARCHAR (50)  NULL,
    [First_Name]                                    NVARCHAR (50)  NULL,
    [Last_Name]                                     NVARCHAR (50)  NULL,
    [Suffix]                                        NVARCHAR (50)  NULL,
    [Email]                                         NVARCHAR (50)  NULL,
    [Quantity]                                      TINYINT        NULL,
    [Ticket_Type]                                   NVARCHAR (50)  NULL,
    [Attendee]                                      NVARCHAR (50)  NULL,
    [Barcode]                                       NVARCHAR (50)  NULL,
    [Order_Type]                                    NVARCHAR (50)  NULL,
    [Attendee_Status]                               NVARCHAR (50)  NULL,
    [Home_Address_1]                                NVARCHAR (1)   NULL,
    [Home_Address_2]                                NVARCHAR (1)   NULL,
    [Home_City]                                     NVARCHAR (1)   NULL,
    [Home_State]                                    NVARCHAR (1)   NULL,
    [Home_Zip]                                      NVARCHAR (1)   NULL,
    [Home_Country]                                  NVARCHAR (1)   NULL,
    [Cell_Phone]                                    NVARCHAR (1)   NULL,
    [Accept_Code_of_Conduct]                        NVARCHAR (50)  NULL,
    [Lunch_Type]                                    NVARCHAR (50)  NULL,
    [Are_you_willing_to_volunteer_during_the_event] VARCHAR (3)    NULL,
    [Twitter_X_UserName]                            NVARCHAR (50)  NULL,
    [LinkedIn_URL]                                  NVARCHAR (150) NULL,
    [Job_Title]                                     NVARCHAR (50)  NULL,
    [Company]                                       NVARCHAR (100) NULL,
    [Work_Phone]                                    NVARCHAR (1)   NULL,
    [Website]                                       NVARCHAR (100) NULL,
    [Blog]                                          NVARCHAR (50)  NULL
);


GO

