   
CREATE VIEW vw_GetLatestSignal  
AS  
SELECT TOP 1  Id,
    DATEDIFF(SECOND, CreatedAt, GETDATE()) AS SecondsAgo,  
    CreatedAt,  
    StrikePrice,  
    OptionType,  
    SignalType,  
    SignalScore,  
    LastPrice  ,
    'NIFTY'+ UPPER(FORMAT(ExpiryDate, 'ddMMMyy'))+CAST(CAST(StrikePrice  AS INT) AS VARCHAR)+UPPER(OptionType)  AS symbol
FROM ScalpSignal  
WHERE CreatedAt >= DATEADD(SECOND, -60, GETDATE())  
ORDER BY CreatedAt DESC;