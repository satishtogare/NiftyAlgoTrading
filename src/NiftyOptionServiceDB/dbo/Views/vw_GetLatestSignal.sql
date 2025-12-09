 
CREATE VIEW vw_GetLatestSignal
AS
SELECT TOP 1
    DATEDIFF(SECOND, CreatedAt, GETDATE()) AS SecondsAgo,
    CreatedAt,
    StrikePrice,
    OptionType,
    SignalType,
    SignalScore,
    LastPrice
FROM ScalpSignal
WHERE CreatedAt >= DATEADD(SECOND, -60, GETDATE())
ORDER BY CreatedAt DESC;