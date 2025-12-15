  
CREATE PROC BackTest            
 (            
  @id bigint             
 )            
 AS            
 BEGIN            
            
 declare @CreatedAt_Signal DATETIME2            
 declare @OptionType_Signal VARCHAR(10)            
 declare @StrikePrice_Signal VARCHAR(10)            
   declare @LastPrice_Signal DECIMAL          
            
 SELECT @CreatedAt_Signal=CreatedAt,@OptionType_Signal= OptionType , @StrikePrice_Signal=StrikePrice,@LastPrice_Signal=LastPrice FROM ScalpSignal            
 WHERE ID=@id            
             
   ;with cte as (          
 select  CreatedAt as t,          
 CASE           
 WHEN (LastPrice-@LastPrice_Signal)<=-2 THEN 'STOPLOSS'           
 WHEN (LastPrice-@LastPrice_Signal)>=2 THEN 'TARGET'          
 ELSE 'ACTIVE' END STATUS,          
 *   from OptionData             
 where  cast(CreatedAt as DATETIME)>=cast(cast(@CreatedAt_Signal as datetime2) as DATETIME) and              
 CAST(CreatedAt AS DATE)=cast(cast(@CreatedAt_Signal as datetime2) as date)  and OptionType=@OptionType_Signal and StrikePrice=@StrikePrice_Signal            
 --order by CreatedAt desc        
 ),
 final as (
 select * from cte where STATUS='Active' and CreatedAt<=(select min(CreatedAt) from cte where STATUS<>'Active')
   union        
   select * from cte where STATUS<>'Active' and CreatedAt=(select min(CreatedAt) from cte where STATUS<>'Active')
     )
     select * from final order by CreatedAt desc    
     
     --select * from (      
     --select * from #t where STATUS='Active' and t >(select top 1 t from #t where STATUS<>'Active' order by t asc)      
     --union      
     --select top 1 * from #t where STATUS<>'Active' order by t asc      
     --)f order by t desc      
      
          
   --;WITH DataWithStatus AS           
   -- (          
   --     SELECT           
   --         CreatedAt AS t,          
   --         CASE           
   --             WHEN (LastPrice - @LastPrice_Signal) <= -5 THEN 'STOPLOSS'          
   --             WHEN (LastPrice - @LastPrice_Signal) >= 5 THEN 'TARGET'          
   --             ELSE 'ACTIVE'          
   --         END AS STATUS,          
   --         OD.*          
   --     FROM OptionData OD          
   --     WHERE            
   --         CAST(OD.CreatedAt AS DATE) = CAST(@CreatedAt_Signal AS DATE)          
   --         AND OD.CreatedAt >= @CreatedAt_Signal          
   --         AND OD.OptionType = @OptionType_Signal          
   --         AND OD.StrikePrice = @StrikePrice_Signal          
   -- ),          
          
   -- Ordered AS          
   -- (          
   --     SELECT *,          
   --            ROW_NUMBER() OVER (ORDER BY t ASC) AS rn          
   --     FROM DataWithStatus          
   -- ),          
          
   -- FirstChange AS          
   -- (          
   --     SELECT TOP 1 rn           
   --     FROM Ordered          
   --     WHERE STATUS <> 'ACTIVE'          
   --     ORDER BY rn          
   -- )          
          
          
          
   -- SELECT *          
   -- FROM Ordered          
   -- --WHERE rn < ISNULL((SELECT rn FROM FirstChange), 999999999)          
   -- --ORDER BY t DESC;          
            
END