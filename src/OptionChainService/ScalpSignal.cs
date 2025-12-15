namespace NiftyOptionChainService
{
    public class ScalpSignal
    {
        public int Id { get; set; }
        public DateTime CreatedAt { get; set; }
        public decimal StrikePrice { get; set; }
        public string OptionType { get; set; }
        public string SignalType { get; set; }
        public decimal SignalScore { get; set; }
        public decimal LastPrice { get; set; }
        public int SecondsAgo { get; set; }
        public String symbol { get; set; }
    }
}