CREATE TABLE [dbo].[AttendeesPrinted] (
    [Barcode]         NVARCHAR (50) NOT NULL,
    [CreatedDatetime] DATETIME2 (3) CONSTRAINT [DF_AttendeesPrinted_CreatedDatetime] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_AttendeesPrinted] PRIMARY KEY CLUSTERED ([Barcode] ASC)
);


GO

