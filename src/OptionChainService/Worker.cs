using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System; 
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace NiftyOptionChainService
{
    public class Worker : BackgroundService
    { 
        private readonly ILogger<Worker> _logger;
       // private readonly IHttpClientFactory _httpClientFactory;
        private readonly DhanApiSettings _dhanApi;
        private readonly string _connectionString;
        public Worker(ILogger<Worker> logger, IOptions<DhanApiSettings> dhanApiOptions, IConfiguration config)
        {
            _logger = logger;
            _dhanApi = dhanApiOptions.Value;
            _connectionString = config.GetConnectionString("DefaultConnection");

            _dhanApi.IsMarketOpen=IsMarketOpenAsync().Result;
            _dhanApi.isFetchMarketStatus= true;
        }


        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Nifty Option Chain Service started at: {time}", DateTimeOffset.Now);
          
            if (_dhanApi.isFetchedExpiryDetails== false)
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

                        var jsonBody = JsonSerializer.Serialize(payload);

                        var request = new HttpRequestMessage(HttpMethod.Post, _dhanApi.optionchain);
                        request.Headers.Add("access-token", _dhanApi.AccessToken);
                        request.Headers.Add("client-id", _dhanApi.ClientId);
                        request.Content = new StringContent(jsonBody, Encoding.UTF8, "application/json");

                        var response = await httpClient.SendAsync(request, stoppingToken);
                        response.EnsureSuccessStatusCode();

                        var jsonString = await response.Content.ReadAsStringAsync(stoppingToken);

                        await SaveOptionChainDataAsync(jsonString, stoppingToken);
                        await generateSingalLoop(stoppingToken); 

                    _logger.LogInformation("Data fetched and saved at {time}", DateTimeOffset.Now);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Error fetching or saving data");
                    }

                    await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);  
                }
      

         
        }

        protected   async Task FetchExpiry(CancellationToken stoppingToken)
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

                        var jsonBody = JsonSerializer.Serialize(payload);

                        var request = new HttpRequestMessage(HttpMethod.Post, _dhanApi.expirylist);
                        request.Headers.Add("access-token", _dhanApi.AccessToken);
                        request.Headers.Add("client-id", _dhanApi.ClientId);
                        request.Content = new StringContent(jsonBody, Encoding.UTF8, "application/json");

                        var response = await httpClient.SendAsync(request, stoppingToken);
                        response.EnsureSuccessStatusCode();

                        var jsonString = await response.Content.ReadAsStringAsync(stoppingToken);

                        using var doc = JsonDocument.Parse(jsonString);
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
        private async Task SaveOptionChainDataAsync(string jsonData, CancellationToken cancellationToken)
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync(cancellationToken);

            const string query = """
            INSERT INTO OptionChainRaw (FetchedAt, JsonData)
            VALUES (@FetchedAt, @JsonData);
            """;

            await using var cmd = new SqlCommand(query, connection);
            cmd.Parameters.AddWithValue("@FetchedAt", DateTime.Now);
            cmd.Parameters.AddWithValue("@JsonData", jsonData);

            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }
    }
}
