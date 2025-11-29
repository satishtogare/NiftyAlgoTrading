CREATE TABLE [dbo].[OptionChainRaw_BKP] (
    [Id]          INT            IDENTITY (1, 1) NOT NULL,
    [FetchedAt]   DATETIME       NULL,
    [JsonData]    NVARCHAR (MAX) NULL,
    [isProcessed] INT            NULL
);

