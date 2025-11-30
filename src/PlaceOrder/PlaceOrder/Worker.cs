using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Newtonsoft.Json;
using System.Text;
using System.Threading;
namespace PlaceOrder
{
    public class Worker : BackgroundService
    {
        private readonly string _connectionString;
        private readonly ILogger logger; 
        private readonly DhanApiSettings _dhanApi;
        public Worker(ILogger<Worker> _logger, IOptions<DhanApiSettings> dhanApiOptions, IConfiguration config)
        {
            _connectionString = config.GetConnectionString("DefaultConnection");
            logger = _logger;
            _dhanApi = dhanApiOptions.Value;
        }
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                if (logger.IsEnabled(LogLevel.Information))
                {
                    logger.LogInformation("Worker running at: {time}", DateTimeOffset.Now);
                }

                var signal =await GetFreshSignal(stoppingToken);
                if (signal == null) return;
                 
                var activeTrade =await HasActiveDhanPosition();
                if (activeTrade)
                {
                    Console.WriteLine("Active position exists. No new trade placed.");
                    return;
                }
                 
                string symbol = "NIFTY";
                int qty = 50;
                //double entryPrice = signal.LastPrice;
                 
                double _stopLoss = 3;   
                double _tsl = 2;         

                string txnType = signal.OptionType.ToUpper() == "CE" ? "BUY" : "SELL";
                 
                var payload = new
                {
                    symbol = symbol,
                    exchangeSegment = "NSE",
                    transactionType = txnType,
                    quantity = qty,
                    orderType = "MARKET",
                    productType = "INTRADAY",
                    legType = "Single",
                    price = 0,
                    stopLoss = _stopLoss,
                    trailingStopLoss = _tsl
                };

                var json = JsonConvert.SerializeObject(payload);
                Console.WriteLine("Placing Order: " + json);

                
                using (var client = new HttpClient())
                {
                    client.DefaultRequestHeaders.Add("Client-Id", "YOUR_CLIENT_ID");
                    client.DefaultRequestHeaders.Add("Access-Token", "YOUR_ACCESS_TOKEN");

                    var response = await client.PostAsync(
                        "https://api.dhan.co/orders/super",
                        new StringContent(json, Encoding.UTF8, "application/json")
                    );

                    var result = await response.Content.ReadAsStringAsync();
                    Console.WriteLine("DHAN Response: " + result);

                    if (response.IsSuccessStatusCode)
                    {
                        dynamic data = JsonConvert.DeserializeObject(result);
                        string orderId = data.orderId;
                         
                       // InsertNewTrade(signal, orderId, entryPrice, qty, stopLoss, tsl);
                    }
                }


                await Task.Delay(1000, stoppingToken);
            }
        }

        private async Task<ScalpSignal> GetFreshSignal(CancellationToken cancellationToken)
        { 

            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync(cancellationToken);

            const string query = "SELECT * FROM vw_GetLatestSignal";

            await using var cmd = new SqlCommand(query, connection); 

         

            using (SqlDataReader dr =await cmd.ExecuteReaderAsync(cancellationToken))
            {
                if (dr.Read())
                {
                    return new ScalpSignal
                    {
                        Id = dr.GetInt32(dr.GetOrdinal("Id")),
                        CreatedAt = dr.GetDateTime(dr.GetOrdinal("CreatedAt")),
                        StrikePrice = dr.GetDecimal(dr.GetOrdinal("StrikePrice")),
                        OptionType = dr.GetString(dr.GetOrdinal("OptionType")),
                        SignalType = dr.GetString(dr.GetOrdinal("SignalType")),
                        SignalScore = dr.GetDecimal(dr.GetOrdinal("SignalScore")),
                        LastPrice = dr.GetDecimal(dr.GetOrdinal("LastPrice")),
                        SecondsAgo = dr.GetInt32(dr.GetOrdinal("SecondsAgo"))
                    };
                }
            }

            return null;
        }

        public async Task<bool> HasActiveDhanPosition()
        {
            using (var client = new HttpClient())
            {
                client.DefaultRequestHeaders.Add("Client-Id", "YOUR_CLIENT_ID");
                client.DefaultRequestHeaders.Add("Access-Token", "YOUR_ACCESS_TOKEN");

                var response = await client.GetAsync("https://api.dhan.co/positions");
                var json = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                {
                    Console.WriteLine("Error fetching positions: " + json);
                    return false;
                }

                var positions = JsonConvert.DeserializeObject<List<dynamic>>(json); 
                return positions != null && positions.Count > 0;
            }
        }

    }
}
