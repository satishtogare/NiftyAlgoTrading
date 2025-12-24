using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Newtonsoft.Json;
using System; 
using System.Net.Http;
using System.Text; 
using System.Threading;
using System.Threading.Tasks;

namespace NiftyOptionChainService
{
    public class Worker : BackgroundService
    { 
        private readonly ILogger<Worker> _logger; 
        private readonly DhanApiSettings _dhanApi;
        private readonly string _connectionString;
        public Worker(ILogger<Worker> logger, IOptions<DhanApiSettings> dhanApiOptions, IConfiguration config)
        {
            _logger = logger;
            _dhanApi = dhanApiOptions.Value;
            _connectionString = config.GetConnectionString("DefaultConnection");


         


            _dhanApi.IsMarketOpen = IsMarketOpenAsync().Result;
            _dhanApi.isFetchMarketStatus = true;
        }


        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            string logPath1 = "signals_log.txt";
            string line1 = $"{DateTime.Now:dd-MM-yyyy HH:mm:ss} | DAY STARTED.\n"; 
            await File.AppendAllTextAsync(logPath1, line1);

            _logger.LogInformation("Nifty Option Chain Service started at: {time}", DateTimeOffset.Now);

            if (_dhanApi.isFetchedExpiryDetails == false)
            {
                await FetchExpiry(stoppingToken);
            }

            using var httpClient = new HttpClient();
            httpClient.Timeout = TimeSpan.FromMinutes(5);

            while (!stoppingToken.IsCancellationRequested)
            {
                if (!_dhanApi.IsMarketOpen)
                {
                    _dhanApi.IsMarketOpen = IsMarketOpenAsync().Result;

                    _logger.LogInformation("Market not opened :  {time}", DateTimeOffset.Now);
                    await Task.Delay(TimeSpan.FromSeconds(60), stoppingToken);
                    continue;

                }

                try
                {
                    var payload = new
                    {
                        UnderlyingScrip = 13,
                        UnderlyingSeg = "IDX_I",
                        Expiry = _dhanApi.nextExpiry
                    };

                    var jsonBody = JsonConvert.SerializeObject(payload);

                    var request = new HttpRequestMessage(HttpMethod.Post, _dhanApi.optionchain);
                    request.Headers.Add("access-token", _dhanApi.AccessToken);
                    request.Headers.Add("client-id", _dhanApi.ClientId);
                    request.Content = new StringContent(jsonBody, Encoding.UTF8, "application/json");

                    var response = await httpClient.SendAsync(request, stoppingToken);
                    response.EnsureSuccessStatusCode();

                    var jsonString = await response.Content.ReadAsStringAsync(stoppingToken);

                    var now = DateTime.Now;

                    if (now.TimeOfDay < new TimeSpan(15, 30, 0))
                    {
                        await SaveOptionChainDataAsync(jsonString, _dhanApi.nextExpiry, stoppingToken);
                    } 

                    if (now.TimeOfDay < new TimeSpan(14, 30, 0))
                    {
                        await PleaceSuperOrderAsync(stoppingToken);
                    }

                    _logger.LogInformation("Data fetched and saved at {time}", DateTimeOffset.Now);
                }
                catch (Exception ex)
                {
                    _logger.LogError("Error", "Error fetching or saving data");
                }

                await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
            }



        }

        protected async Task FetchExpiry(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Nifty Option Chain Service started at: {time}", DateTimeOffset.Now);

            using var httpClient = new HttpClient();
            httpClient.Timeout = TimeSpan.FromMinutes(5);

            try
            {
                var payload = new
                {
                    UnderlyingScrip = 13,
                    UnderlyingSeg = "IDX_I"
                };

                var jsonBody = JsonConvert.SerializeObject(payload);

                var request = new HttpRequestMessage(HttpMethod.Post, _dhanApi.expirylist);
                request.Headers.Add("access-token", _dhanApi.AccessToken);
                request.Headers.Add("client-id", _dhanApi.ClientId);
                request.Content = new StringContent(jsonBody, Encoding.UTF8, "application/json");

                var response = await httpClient.SendAsync(request, stoppingToken);
                response.EnsureSuccessStatusCode();

                var jsonString = await response.Content.ReadAsStringAsync(stoppingToken);

                using var doc = System.Text.Json.JsonDocument.Parse(jsonString);
                var dates = doc.RootElement.GetProperty("data")
                    .EnumerateArray()
                    .Select(d => DateTime.Parse(d.GetString()!))
                    .ToList();

                DateTime nearestExpiry = dates.Min();

                _dhanApi.isFetchedExpiryDetails = true;
                _dhanApi.nextExpiry = nearestExpiry.ToString("yyyy-MM-dd");



                _logger.LogInformation("Data fetched and saved at {time}", DateTimeOffset.Now);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching or saving data");
            }


        }
        private async Task<bool> IsMarketOpenAsync()
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            await using var cmd = new SqlCommand("sp_IsMarketOpen", connection)
            {
                CommandType = System.Data.CommandType.StoredProcedure
            };

            var outputParam = new SqlParameter("@IsOpen", System.Data.SqlDbType.Bit)
            {
                Direction = System.Data.ParameterDirection.Output
            };
            cmd.Parameters.Add(outputParam);

            await cmd.ExecuteNonQueryAsync();

            return (bool)outputParam.Value;
        }
        private async Task generateSingalLoop(CancellationToken cancellationToken)
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync(cancellationToken);

            const string query = "exec generateSingalLoop";

            await using var cmd = new SqlCommand(query, connection);

            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }
        private async Task SaveOptionChainDataAsync(string jsonData, string expDate, CancellationToken cancellationToken)
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync(cancellationToken); 

            await using var cmd = new SqlCommand("SaveOptionChainData", connection);
            cmd.CommandType = System.Data.CommandType.StoredProcedure; 
            cmd.Parameters.AddWithValue("@JsonData", jsonData);
            cmd.Parameters.AddWithValue("@ExpiryDate", expDate);
            cmd.CommandTimeout = 120;

            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }
         
        private async Task<ScalpSignal> GetFreshSignalAsync(CancellationToken cancellationToken)
        {

            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync(cancellationToken);

            const string query = "SELECT * FROM vw_GetLatestSignal";

            await using var cmd = new SqlCommand(query, connection);



            using (SqlDataReader dr = await cmd.ExecuteReaderAsync(cancellationToken))
            {
                if (dr.Read())
                {
                    return new ScalpSignal
                    {
                        Id = dr.GetInt32(dr.GetOrdinal("Id")),
                        SecondsAgo = dr.GetInt32(dr.GetOrdinal("SecondsAgo")),
                        symbol = dr.GetString(dr.GetOrdinal("symbol")),
                        CreatedAt = dr.GetDateTime(dr.GetOrdinal("CreatedAt")),
                        StrikePrice = dr.GetDecimal(dr.GetOrdinal("StrikePrice")),
                        OptionType = dr.GetString(dr.GetOrdinal("OptionType")),
                        securityId = dr.GetString(dr.GetOrdinal("securityId")),
                        SignalType = dr.GetString(dr.GetOrdinal("SignalType")),
                        SignalScore = dr.GetDecimal(dr.GetOrdinal("SignalScore")),
                        LastPrice = dr.GetDecimal(dr.GetOrdinal("LastPrice")) 
                    };
                }
            }

            return null;
        }

        public async Task<bool> HasActiveDhanPosition()
        {
            using (var client = new HttpClient())
            {
                client.DefaultRequestHeaders.Add("Client-Id", _dhanApi.ClientId);
                client.DefaultRequestHeaders.Add("Access-Token", _dhanApi.AccessToken);

                var response = await client.GetAsync("https://api.dhan.co/positions");
                var json = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                {
                    Console.WriteLine("Error fetching positions: " + json);
                    return false;
                }

                var positions = JsonConvert.DeserializeObject<List<Position>>(json);
                return positions != null && positions.Any(p =>
                !string.Equals(p.positionType, "closed", StringComparison.OrdinalIgnoreCase)
                );
            }
        }
        private async Task InsertNewTradeAsync(int Key,int SignalId, string RequestJson, CancellationToken cancellationToken)
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync(cancellationToken); 

            await using var cmd = new SqlCommand("usp_TradeBook", connection);
            cmd.CommandType = System.Data.CommandType.StoredProcedure; 
            cmd.Parameters.AddWithValue("@SignalId", SignalId);
            cmd.Parameters.AddWithValue("@RequestJson", RequestJson);
            cmd.Parameters.AddWithValue("@Key", Key);
            cmd.CommandTimeout = 120;

            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }
        private async Task PleaceSuperOrderAsync(CancellationToken cancellationToken)
        {
            string logPath = "signals_log.txt";
            string line = "";

            var signal = await GetFreshSignalAsync(cancellationToken);
             if (signal == null)
              {
               
                line = $"{DateTime.Now:dd-MM-yyyy HH:mm:ss} | No signal.\n";

                await File.AppendAllTextAsync(logPath, line);
                Console.WriteLine("No signal.");
                    return;
              }

            var activeTrade = await HasActiveDhanPosition();
            if (activeTrade)
            {  
                  line = $"{DateTime.Now:dd-MM-yyyy HH:mm:ss} | Active position exists. No new trade placed.\n";

                await File.AppendAllTextAsync(logPath, line);
                Console.WriteLine("Active position exists. No new trade placed.");
                return;
            }
             


            var payload = new
            {
                dhanClientId = _dhanApi.ClientId,
                correlationId = "123abc678",
                transactionType = "BUY",
                exchangeSegment = "NSE_FNO",
                productType = "INTRADAY",
                orderType = "MARKET", 
                securityId =signal.securityId,
                quantity = 75,
                targetPrice= signal.LastPrice+ 100,
                //price = signal.LastPrice, 
                stopLossPrice = signal.LastPrice-signal.stopLoss,
                trailingJump = signal.trailingStopLoss
            };



            var json = JsonConvert.SerializeObject(payload); 

            using var httpClient = new HttpClient();
            httpClient.Timeout = TimeSpan.FromMinutes(5);
            var request = new HttpRequestMessage(HttpMethod.Post, "https://api.dhan.co/v2/super/orders");
            request.Headers.Add("access-token", _dhanApi.AccessToken);
            request.Headers.Add("client-id", _dhanApi.ClientId);
            request.Content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await httpClient.SendAsync(request, cancellationToken);

            await InsertNewTradeAsync(1,signal.Id, json, cancellationToken);

            var result = await response.Content.ReadAsStringAsync();
            await InsertNewTradeAsync(2, signal.Id, result, cancellationToken);

            if (response.IsSuccessStatusCode)
                { 
                   await InsertNewTradeAsync(3,signal.Id, json, cancellationToken);
                } 
        }
        }
    }
 