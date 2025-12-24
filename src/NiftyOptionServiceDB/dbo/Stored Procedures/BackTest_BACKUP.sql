      
CREATE PROC [dbo].[BackTest_BACKUP]                
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
 select * from cte where STATUS='Active'  and CreatedAt<=(select min(CreatedAt) from cte where STATUS<>'Active')    
   union            
 select * from cte where STATUS<>'Active' and CreatedAt=(select min(CreatedAt) from cte where STATUS<>'Active')    
     )    
     select * from final order by CreatedAt desc        
                      
                
END