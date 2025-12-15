CREATE TABLE [dbo].[OptionChainRaw] (
    [Id]          INT            IDENTITY (1, 1) NOT NULL,
    [FetchedAt]   DATETIME       NULL,
    [JsonData]    NVARCHAR (MAX) NULL,
    [isProcessed] INT            NULL,
    [ExpiryDate]  DATE           NULL,
    PRIMARY KEY CLUSTERED ([Id] ASC)
);

