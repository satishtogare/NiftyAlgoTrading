
CREATE PROCEDURE [dbo].[GenerateScalpSignals]      
    @PricePctThreshold DECIMAL(6,3) = 2.0,      
    @OIPctThreshold DECIMAL(6,3) = 1.0,      
    @MinVolume BIGINT = 1000,      
    @LookbackMinutes INT = 10      
AS      
BEGIN      
    SET NOCOUNT ON;      
      
    DECLARE @MaxTimeStamp DATETIME;      
    SELECT @MaxTimeStamp = MAX(CreatedAt) FROM dbo.OptionData;      

    ;WITH recent AS      
    (      
        SELECT *     
        FROM dbo.OptionData      
        WHERE CreatedAt >= DATEADD(MINUTE, -ABS(@LookbackMinutes), @MaxTimeStamp)      
    ),    

    ranked AS      
    (      
        SELECT *,      
               ROW_NUMBER() OVER (PARTITION BY StrikePrice, OptionType ORDER BY CreatedAt DESC, Id DESC) AS rn      
        FROM recent      
    ),      

    latest AS ( SELECT * FROM ranked WHERE rn = 1 ),      
    previous AS ( SELECT * FROM ranked WHERE rn = 2 ),      

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
                 ELSE (L.ImpliedVolatility - P.ImpliedVolatility) * 100.0 / P.ImpliedVolatility END AS IVPct,
            L.ExpiryDate
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
    ),

    -----------------------------------------------------------
    -- CANDIDATE SIGNALS
    -----------------------------------------------------------
    Candidates AS
(
    SELECT j.*,
           (ABS(j.PricePct)*0.5 + ABS(j.OIPct)*0.3 + ABS(j.VolumePct)*0.2) AS StrengthScore
    FROM joined j
    WHERE
        (
            (j.OptionType = 'ce'
             AND j.PricePct > 0.8
             AND j.OIPct   > 0.5
             AND j.Volume  >= 500
             AND j.Delta   > 0.25
            )
        OR
            (j.OptionType = 'pe'
             AND j.PricePct > 0.8
             AND j.OIPct   > 0.5
             AND j.Volume  >= 500
             AND ABS(j.Delta) > 0.25
            )
        OR
            -- 🚀 Momentum scalp trigger
            (j.PricePct > 1.2 AND j.VolumePct > 5)
        )
        AND NOT EXISTS (SELECT 1 FROM dbo.ScalpSignal s WHERE s.OptionDataId = j.OptionDataId)
),


    -----------------------------------------------------------
    -- BLOCK CE + PE SAME TIME / SAME STRIKE
    -----------------------------------------------------------
    Filtered AS
    (
        SELECT c.*
        FROM Candidates c
        WHERE 
        (
            c.OptionType = 'ce'
            AND NOT EXISTS (
                SELECT 1 FROM Candidates p
                WHERE p.StrikePrice = c.StrikePrice
                  AND p.CreatedAt  = c.CreatedAt
                  AND p.OptionType = 'pe'
            )
        )
        OR
        (
            c.OptionType = 'pe'
            AND NOT EXISTS (
                SELECT 1 FROM Candidates ce
                WHERE ce.StrikePrice = c.StrikePrice
                  AND ce.CreatedAt  = c.CreatedAt
                  AND ce.OptionType = 'ce'
            )
        )
    ),

    -----------------------------------------------------------
    -- PICK STRONGER SIDE IF BOTH STILL EXIST
    -----------------------------------------------------------
    FinalRanked AS
    (
        SELECT *,
               ROW_NUMBER() OVER(
                    PARTITION BY StrikePrice, CreatedAt
                    ORDER BY StrengthScore DESC
               ) AS rn
        FROM Filtered
    )

    -----------------------------------------------------------
    -- FINAL INSERT
    -----------------------------------------------------------
    INSERT INTO dbo.ScalpSignal      
    (      
        OptionDataId, StrikePrice, OptionType, SignalType, SignalScore,      
        LastPrice, PrevLastPrice, PricePctChange,      
        OI, PrevOI, OIPctChange,      
        Volume, PrevVolume, VolumePctChange,      
        ImpliedVolatility, PrevImpliedVolatility, IVPctChange,      
        Delta, Gamma, Vega, CreatedAt , Diff , ExpiryDate
    )      
    SELECT      
        r.OptionDataId,
        r.StrikePrice,
        r.OptionType,
        CASE WHEN r.OptionType='ce' THEN 'BUY_CE' ELSE 'BUY_PE' END,
        r.StrengthScore,
        r.LastPrice,
        r.PrevLastPrice,
        r.PricePct,
        r.OI,
        r.PrevOI,
        r.OIPct,
        r.Volume,
        r.PrevVolume,
        r.VolumePct,
        r.ImpliedVolatility,
        r.PrevImpliedVolatility,
        r.IVPct,
        r.Delta,
        r.Gamma,
        r.Vega,
        r.CreatedAt,
        ((r.StrikePrice-(r.UnderlyingValue-(r.UnderlyingValue%50)+50))),
        r.ExpiryDate
    FROM FinalRanked r
    WHERE rn = 1;

END;