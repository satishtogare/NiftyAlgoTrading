CREATE TABLE [dbo].[SECURITY_ID] (
    [UNDERLYING_SECURITY_ID] VARCHAR (250) NULL,
    [SYMBOL_NAME]            VARCHAR (500) NULL,
    [DISPLAY_NAME]           VARCHAR (500) NULL,
    [RecordCreationDate]     DATETIME      DEFAULT (getdate()) NULL
);

