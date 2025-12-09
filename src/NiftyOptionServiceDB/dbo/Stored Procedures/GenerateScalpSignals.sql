CREATE PROCEDURE [dbo].[GenerateScalpSignals]    
    @PricePctThreshold DECIMAL(6,3) = 2.0,    
    @OIPctThreshold DECIMAL(6,3) = 1.0,    
    @MinVolume BIGINT = 1000,    
    @LookbackMinutes INT = 10    
AS    
BEGIN    
    SET NOCOUNT ON;    
    
    DECLARE @MaxTimeStamp DATETIME;    
    SELECT @MaxTimeStamp = MAX(CreatedAt)    
    FROM dbo.OptionData;    
    
    ;WITH recent AS    
    (    
        SELECT *   
        FROM dbo.OptionData    
        WHERE CreatedAt >= DATEADD(MINUTE, -ABS(@LookbackMinutes), @MaxTimeStamp)    
       -- AND ABS((StrikePrice-(UnderlyingValue-(UnderlyingValue%50)+50)))<=150  
    ),  
    --recentSelectedCount as  
    --(  
    --    select StrikePrice,count(*) as cnt  from recent group by StrikePrice
    --)  ,
      
    ranked AS    
    (    
        SELECT *,    
               ROW_NUMBER() OVER (PARTITION BY StrikePrice, OptionType ORDER BY CreatedAt DESC, Id DESC) AS rn    
        FROM recent    
        --where (select cnt from recentSelectedCount where StrikePrice=(select min(StrikePrice) from recentSelectedCount))=10
    ),    
    latest AS    
    (    
        SELECT * FROM ranked WHERE rn = 1    
    ),    
    previous AS    
    (    
        SELECT * FROM ranked WHERE rn = 2    
    ),    
    joined AS    
    (    
        SELECT    
            L.Id AS OptionDataId,    
            L.StrikePrice,    
            L.OptionType,    
            L.LastPrice,    
            P.LastPrice AS PrevLastPrice,    
            L.OI,    
            P.OI AS PrevOI,    
            L.Volume,    
            P.Volume AS PrevVolume,    
            L.ImpliedVolatility,    
            P.ImpliedVolatility AS PrevImpliedVolatility,    
            L.Delta,    
            L.Gamma,    
            L.Vega,    
            L.CreatedAt,    
            L.UnderlyingValue,
            CASE WHEN P.LastPrice IS NULL OR P.LastPrice = 0 THEN 0     
                 ELSE (L.LastPrice - P.LastPrice) * 100.0 / P.LastPrice END AS PricePct,    
            CASE WHEN P.OI IS NULL OR P.OI = 0 THEN 0     
                 ELSE (L.OI - P.OI) * 100.0 / P.OI END AS OIPct,    
            CASE WHEN P.Volume IS NULL OR P.Volume = 0 THEN 0     
                 ELSE (L.Volume - P.Volume) * 100.0 / P.Volume END AS VolumePct,    
            CASE WHEN P.ImpliedVolatility IS NULL OR P.ImpliedVolatility = 0 THEN 0     
                 ELSE (L.ImpliedVolatility - P.ImpliedVolatility) * 100.0 / P.ImpliedVolatility END AS IVPct 
 
        FROM latest L    
        LEFT JOIN previous P     
            ON L.StrikePrice = P.StrikePrice    
           AND L.OptionType = P.OptionType    
    ),    
    sr AS    
    (    
        SELECT    
            (SELECT TOP 1 StrikePrice FROM latest WHERE OptionType = 'ce' ORDER BY OI DESC) AS ResistanceStrike,    
            (SELECT TOP 1 StrikePrice FROM latest WHERE OptionType = 'pe' ORDER BY OI DESC) AS SupportStrike    
    )    
     

    INSERT INTO dbo.ScalpSignal    
    (    
        OptionDataId,    
        StrikePrice,    
        OptionType,    
        SignalType,    
        SignalScore,    
        LastPrice,    
        PrevLastPrice,    
        PricePctChange,    
        OI,    
        PrevOI,    
        OIPctChange,    
        Volume,    
        PrevVolume,    
        VolumePctChange,    
        ImpliedVolatility,    
        PrevImpliedVolatility,    
        IVPctChange,    
        Delta,    
        Gamma,    
        Vega,    
        CreatedAt ,
        Diff
    )    
    SELECT    
        j.OptionDataId,    
        j.StrikePrice,    
        j.OptionType,    
        CASE    
            WHEN j.OptionType = 'ce' AND j.PricePct > @PricePctThreshold*2 THEN 'BUY_CE_STRONG'    
            WHEN j.OptionType = 'pe' AND j.PricePct > @PricePctThreshold*2 THEN 'BUY_PE_STRONG'    
            WHEN j.OptionType = 'ce' THEN 'BUY_CE'    
            WHEN j.OptionType = 'pe' THEN 'BUY_PE'    
        END AS SignalType,    
        CAST(    
            (ABS(j.PricePct)/NULLIF(@PricePctThreshold,0))*0.4 +    
            (ABS(j.OIPct)/NULLIF(@OIPctThreshold,0))*0.4 +    
            (ABS(j.VolumePct)/10.0)*0.2    
        AS DECIMAL(8,4)) AS SignalScore,    
        j.LastPrice,    
        j.PrevLastPrice,    
        j.PricePct,    
        j.OI,    
        j.PrevOI,    
        j.OIPct,    
        j.Volume,    
        j.PrevVolume,    
        j.VolumePct,    
        j.ImpliedVolatility,    
        j.PrevImpliedVolatility,    
        j.IVPct,    
        j.Delta,    
        j.Gamma,    
        j.Vega,    
        j.CreatedAt  ,
        ((StrikePrice-(j.UnderlyingValue-(j.UnderlyingValue%50)+50)))
    FROM joined j    
    CROSS JOIN sr    
    WHERE    
        (    
            -- 🔹 Type 1: Breakout BUY_CE    
            (j.OptionType = 'ce'    
             AND j.PricePct > @PricePctThreshold    
             AND j.OIPct > @OIPctThreshold    
             AND j.StrikePrice >= sr.ResistanceStrike    
             AND j.Volume >= @MinVolume    
             AND j.Delta > 0.35    
             AND ((j.PricePct + j.OIPct + j.VolumePct) / 3.0) > 2.0    
            )    
         OR    
            -- 🔹 Type 2: Breakout BUY_PE    
            (j.OptionType = 'pe'    
             AND j.PricePct > @PricePctThreshold    
             AND j.OIPct > @OIPctThreshold    
             AND j.StrikePrice <= sr.SupportStrike    
             AND j.Volume >= @MinVolume    
             AND ABS(j.Delta) > 0.35    
             AND ((j.PricePct + j.OIPct + j.VolumePct) / 3.0) > 2.0    
            )    
         OR    
            -- 🔹 Type 3: Momentum continuation (CE or PE with high OI & IV jump)    
            ((j.OptionType IN ('ce','pe'))    
             AND j.PricePct > @PricePctThreshold * 1.5    
             AND j.OIPct > @OIPctThreshold * 1.5    
             AND j.IVPct > 1.0    
             AND j.Volume >= @MinVolume * 1.5    
            )    
         OR    
            -- 🔹 Type 4: Reversal bounce (support-based PE or resistance-based CE)    
            ((j.OptionType = 'pe' AND j.StrikePrice <= sr.SupportStrike AND j.PricePct > 1.0 AND j.OIPct > 0.5)    
             OR    
             (j.OptionType = 'ce' AND j.StrikePrice >= sr.ResistanceStrike AND j.PricePct > 1.0 AND j.OIPct > 0.5)    
            )    
        )    
    AND NOT EXISTS (SELECT 1 FROM dbo.ScalpSignal s WHERE s.OptionDataId = j.OptionDataId);    
END;