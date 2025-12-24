      
CREATE proc [dbo].[SaveOptionChainData]      
(      
@JsonData nvarchar(max)      ,
@ExpiryDate varchar(250)  
)      
AS      
BEGIN      
      
 declare @TimeStamp datetime      
 set @TimeStamp =GETDATE()    
       
      
 --if not exists(select top 1 1 from OptionChainRaw where FORMAT(FetchedAt,'dd-MM-yyyy HH:mm') =FORMAT(@TimeStamp,'dd-MM-yyyy HH:mm') )      
 --begin      
  INSERT INTO OptionChainRaw(FetchedAt,JsonData,isProcessed,ExpiryDate)      
  SELECT GETDATE(),@JsonData,NULL,cast( @ExpiryDate as date)     
      
 exec generateSingalLoop      
 --end      
      
END