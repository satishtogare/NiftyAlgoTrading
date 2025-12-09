  
CREATE proc SaveOptionChainData  
(  
@JsonData nvarchar(max)  
)  
AS  
BEGIN  
  
 declare @TimeStamp datetime  
 set @TimeStamp =GETDATE()
   
  
 if not exists(select top 1 1 from OptionChainRaw where FORMAT(FetchedAt,'dd-MM-yyyy HH:mm') =FORMAT(@TimeStamp,'dd-MM-yyyy HH:mm') )  
 begin  
  INSERT INTO OptionChainRaw(FetchedAt,JsonData,isProcessed)  
  SELECT GETDATE(),@JsonData,NULL  
  
  exec generateSingalLoop  
 end  
  
END