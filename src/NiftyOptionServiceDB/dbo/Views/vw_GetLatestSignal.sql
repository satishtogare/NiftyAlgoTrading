



--SELECT  * FROM [vw_GetLatestSignal]
 
  
CREATE VIEW [dbo].[vw_GetLatestSignal]  
AS  
 with cte as (
SELECT TOP 1  Id,
    DATEDIFF(SECOND, CreatedAt, GETDATE()) AS SecondsAgo,  
    CreatedAt,  
    StrikePrice,  
    OptionType,  
    SignalType,  
    SignalScore,  
    LastPrice  ,
    'NIFTY '+ UPPER(FORMAT(ExpiryDate, 'dd MMM'))+' '+CAST(CAST(StrikePrice  AS INT) AS VARCHAR)+
    CASE WHEN UPPER(OptionType)='PE' THEN ' PUT' ELSE ' CALL' END AS symbol
FROM ScalpSignal  
 WHERE CreatedAt >= DATEADD(SECOND, -60, GETDATE())  
 and DIFF IN (150,100,50,0,-50,-100,-150) AND LastPrice BETWEEN 30 AND 70
 --AND CreatedAt>CAST(CAST(GETDATE() AS DATE) AS VARCHAR)+' 09:20:00.000'
-- ORDER BY  CreatedAt DESC
 )

 SELECT a.*,UNDERLYING_SECURITY_ID AS securityId FROM CTE a 
 inner join
 SECURITY_ID b on a.symbol=b.DISPLAY_NAME
WHERE ( SELECT COUNT(*) FROM TradeBook WHERE CAST(RecordCreatedOn AS DATE)=CAST(GETDATE() AS DATE))<=15
 --where  SignalType like '%BREAKOUT%'
-- ORDER BY CreatedAt DESC;