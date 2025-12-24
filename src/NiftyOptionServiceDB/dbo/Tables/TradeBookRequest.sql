CREATE TABLE [dbo].[TradeBookRequest] (
    [Id]              BIGINT         IDENTITY (1, 1) NOT NULL,
    [SignalId]        INT            NULL,
    [RequestJson]     NVARCHAR (MAX) NULL,
    [RecordCreatedOn] DATETIME       DEFAULT (getdate()) NULL
);

