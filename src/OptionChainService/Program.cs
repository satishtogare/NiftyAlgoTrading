//using NiftyOptionChainService;

//var builder = Host.CreateApplicationBuilder(args);
//builder.Services.AddHostedService<Worker>();

//var host = builder.Build();
//host.Run();
 
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using NiftyOptionChainService;

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