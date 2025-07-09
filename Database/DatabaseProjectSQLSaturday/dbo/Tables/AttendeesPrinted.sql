CREATE TABLE [dbo].[AttendeesPrinted] (
    [Order]           BIGINT        NOT NULL,
    [CreatedDatetime] DATETIME2 (3) CONSTRAINT [DF_AttendeesPrinted_CreatedDatetime] DEFAULT (getdate()) NOT NULL
);


GO

