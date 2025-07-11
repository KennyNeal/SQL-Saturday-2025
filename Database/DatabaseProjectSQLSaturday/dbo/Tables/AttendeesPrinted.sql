CREATE TABLE [dbo].[AttendeesPrinted] (
    [Barcode]           VARCHAR(50)        NOT NULL,
    [CreatedDatetime] DATETIME2 (3) CONSTRAINT [DF_AttendeesPrinted_CreatedDatetime] DEFAULT (getdate()) NOT NULL
);


GO

