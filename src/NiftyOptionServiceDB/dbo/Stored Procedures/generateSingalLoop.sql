CREATE PROC [dbo].[generateSingalLoop]
AS
BEGIN 
CREATE TABLE #OptionTemp
(
    rowId BIGINT IDENTITY(1,1),
    id INT,
    FetchedAt DATETIME,
    JsonData NVARCHAR(MAX),
    Underlying VARCHAR(50),
    ExpiryDate DATE
);

INSERT INTO #OptionTemp (id, FetchedAt, JsonData, Underlying,ExpiryDate)
SELECT   Id, FetchedAt, JsonData, 'NIFTY' AS Underlying,ExpiryDate
FROM OptionChainRaw 
WHERE isnull(isProcessed,0)=0 
ORDER BY FetchedAt ASC;

DECLARE @MinId BIGINT, @MaxId BIGINT;

SELECT @MinId = MIN(RowId), @MaxId = MAX(RowId)
FROM #OptionTemp;

WHILE @MinId <= @MaxId
BEGIN
    DECLARE @Json NVARCHAR(MAX);
    DECLARE @FetchAt DATETIME;
    DECLARE @Underlying VARCHAR(50);
    DECLARE @id INT;
    DECLARE @ExpiryDate DATE

    SELECT 
        @Json = JsonData,
        @FetchAt = FetchedAt,
        @Underlying = Underlying,
        @id = id,
        @ExpiryDate=ExpiryDate
    FROM #OptionTemp 
    WHERE RowId = @MinId;
     
    EXEC [dbo].[InsertOptionDataFromJson]
        @Json = @Json,
        @FetchAt = @FetchAt,
        @Underlying = @Underlying,
        @ExpiryDate=@ExpiryDate;
         
    EXEC [dbo].[GenerateScalpSignals]

    UPDATE OptionChainRaw
    SET isProcessed = 1
    WHERE Id = @id;

    SET @MinId = @MinId + 1;
END

END