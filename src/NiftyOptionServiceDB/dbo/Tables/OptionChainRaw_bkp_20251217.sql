CREATE TABLE [dbo].[OptionChainRaw_bkp_20251217] (
    [Id]          INT            IDENTITY (1, 1) NOT NULL,
    [FetchedAt]   DATETIME       NULL,
    [JsonData]    NVARCHAR (MAX) NULL,
    [isProcessed] INT            NULL,
    [ExpiryDate]  DATE           NULL
);

