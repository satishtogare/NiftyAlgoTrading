CREATE   PROCEDURE [dbo].[sp_IsMarketOpen]  
    @IsOpen BIT OUTPUT  
AS  
BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE   
        @Now DATETIME = GETDATE(),  
        @DayName NVARCHAR(10) = DATENAME(WEEKDAY, GETDATE()),  
        @StartTime TIME = '09:15:00',  
        @EndTime TIME = '15:30:00';   
    SET @IsOpen = 0;  
    
    IF @DayName IN ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday')  
    BEGIN   
        IF CAST(@Now AS TIME) BETWEEN @StartTime AND @EndTime  
        BEGIN  
            SET @IsOpen = 1;  
        END  
    END   
END;