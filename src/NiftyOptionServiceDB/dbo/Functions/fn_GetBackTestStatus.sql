
CREATE FUNCTION [dbo].[fn_GetBackTestStatus]
(
    @id BIGINT
)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @CreatedAt_Signal DATETIME2;
    DECLARE @OptionType_Signal VARCHAR(10);
    DECLARE @StrikePrice_Signal VARCHAR(10);
    DECLARE @LastPrice_Signal DECIMAL(18,2);
    DECLARE @ResultStatus VARCHAR(20);

    -- Get the signal details
    SELECT 
        @CreatedAt_Signal = CreatedAt,
        @OptionType_Signal = OptionType,
        @StrikePrice_Signal = StrikePrice,
        @LastPrice_Signal = LastPrice
    FROM ScalpSignal
    WHERE ID = @id;

    -- CTE to determine status for each OptionData row
    ;WITH cte AS
    (
        SELECT 
            CreatedAt AS t,
            CASE
                WHEN (LastPrice - @LastPrice_Signal) <= -5 THEN 'STOPLOSS'
                WHEN (LastPrice - @LastPrice_Signal) >= 5 THEN 'TARGET'
                ELSE 'ACTIVE'
            END AS STATUS
        FROM OptionData
        WHERE 
            CAST(CreatedAt AS DATETIME) >= CAST(@CreatedAt_Signal AS DATETIME)
            AND CAST(CreatedAt AS DATE) = CAST(@CreatedAt_Signal AS DATE)
            AND OptionType = @OptionType_Signal
            AND StrikePrice = @StrikePrice_Signal
    ),
    final AS
    ( 
        SELECT * 
        FROM cte 
        WHERE STATUS <> 'ACTIVE'  
    ) 
    SELECT TOP 1 @ResultStatus = STATUS
    FROM final
    WHERE STATUS <> 'ACTIVE'
    ORDER BY t ASC;

    RETURN @ResultStatus;
END