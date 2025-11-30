  

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using PlaceOrder;

IHost host = Host.CreateDefaultBuilder(args)
    .UseWindowsService(options =>
    {
        options.ServiceName = "Nifty Option Chain Fetcher";
    })
    .ConfigureServices((context, services) =>
    {
        services.Configure<DhanApiSettings>(context.Configuration.GetSection("DhanApi"));
        services.AddHostedService<Worker>();
    })
    .Build();

await host.RunAsync();

