CREATE PROC usp_TradeBook  
(  
@SignalId INT,  
@RequestJson NVARCHAR(MAX),
@Key INT
)  
AS  
BEGIN  
    IF(@Key=1)
    BEGIN
        INSERT INTO TradeBookRequest(SignalId,RequestJson)  
        SELECT @SignalId,@RequestJson  
    END

    ELSE IF(@Key=2)
    BEGIN
        INSERT INTO TradeBookResponse(SignalId,RequestJson)  
        SELECT @SignalId,@RequestJson  
    END
    ELSE IF(@Key=3)
    BEGIN
        INSERT INTO TradeBook(SignalId,RequestJson)  
        SELECT @SignalId,@RequestJson  
    END
    ELSE
    BEGIN
        SELECT 1
    END


END