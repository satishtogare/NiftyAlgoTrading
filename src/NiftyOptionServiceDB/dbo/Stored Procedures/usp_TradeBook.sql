
CREATE PROC usp_TradeBook
(
@SignalId INT,
@RequestJson NVARCHAR(MAX)
)
AS
BEGIN
    INSERT INTO TradeBook(SignalId,RequestJson)
    SELECT @SignalId,@RequestJson
END