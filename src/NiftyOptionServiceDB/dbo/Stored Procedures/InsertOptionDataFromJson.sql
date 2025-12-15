       
      
CREATE PROCEDURE [dbo].[InsertOptionDataFromJson]          
 @Json NVARCHAR(MAX),      
 @FetchAt DATETIME,    
 @Underlying VARCHAR(50),
 @ExpiryDate DATE
AS          
BEGIN          
    SET NOCOUNT ON;          
        
         
 ;WITH CTE      
 AS      
 (      
    SELECT         
        TRY_CAST(REPLACE(oc.[key], '.000000', '') AS DECIMAL(18,2)) AS StrikePrice,        
        opt.OptionType,        
        TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.implied_volatility')) AS DECIMAL(18,8)) AS ImpliedVolatility,        
        TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.last_price')) AS DECIMAL(18,8)) AS LastPrice,        
        TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.oi')) AS BIGINT) AS OI,        
        TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.previous_close_price')) AS DECIMAL(18,8)) AS PreviousClosePrice,        
        TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.previous_oi')) AS BIGINT) AS PreviousOI,        
        TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.previous_volume')) AS BIGINT) AS PreviousVolume,        
        TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.top_ask_price')) AS DECIMAL(18,8)) AS TopAskPrice,        
        TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.top_ask_quantity')) AS BIGINT) AS TopAskQuantity,        
        TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.top_bid_price')) AS DECIMAL(18,8)) AS TopBidPrice,        
        TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.top_bid_quantity')) AS BIGINT) AS TopBidQuantity,        
        TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.volume')) AS BIGINT) AS Volume,        
        TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.greeks.delta')) AS DECIMAL(18,8)) AS Delta,        
        TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.greeks.theta')) AS DECIMAL(18,8)) AS Theta,        
        TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.greeks.gamma')) AS DECIMAL(18,8)) AS Gamma,        
        TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.greeks.vega')) AS DECIMAL(18,8)) AS Vega,    
  TRY_CAST(JSON_VALUE(@Json, '$.data.last_price') AS DECIMAL(18,8)) AS RootLastPrice    
    FROM OPENJSON(@Json, '$.data.oc') AS oc        
    CROSS APPLY (VALUES ('ce'), ('pe')) AS opt(OptionType)        
  --WHERE TRY_CAST(JSON_VALUE(oc.value, CONCAT('$.', opt.OptionType, '.last_price')) AS DECIMAL(18,8)) > 1;        
  )  , Filtered AS    
    (    
        SELECT *,    
               ABS(CAST(StrikePrice AS INT) - CAST(RootLastPrice AS INT)) AS DistanceFromATM    
        FROM CTE    
        --WHERE Volume > 1.00    
    )     
   ---- Extract all strike prices        
    INSERT INTO OptionData (        
        StrikePrice, OptionType,        
        ImpliedVolatility, LastPrice, OI,        
        PreviousClosePrice, PreviousOI, PreviousVolume,        
        TopAskPrice, TopAskQuantity, TopBidPrice, TopBidQuantity, Volume,        
   Delta, Theta, Gamma, Vega  ,    
   UnderlyingValue,    
   Underlying,CreatedAt,ExpiryDate      
    )        
 SELECT  StrikePrice, OptionType,        
        ImpliedVolatility, LastPrice, OI,        
        PreviousClosePrice, PreviousOI, PreviousVolume,        
        TopAskPrice, TopAskQuantity, TopBidPrice, TopBidQuantity, Volume,        
   Delta, Theta, Gamma, Vega,     
   RootLastPrice,    
   'NIFTY',@FetchAt,@ExpiryDate     
   FROM Filtered   WHERE ImpliedVolatility>1   
 --WHERE DistanceFromATM<=50    
      
      
END;