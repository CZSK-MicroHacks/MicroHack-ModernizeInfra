using Microsoft.EntityFrameworkCore;
using ModernizeInfraApp.Data;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddOpenApi();

// Configure database contexts for two separate databases
var customerConnectionString = builder.Configuration.GetConnectionString("CustomerDatabase")
    ?? "Server=sqlserver1,1433;Database=CustomerDB;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;";

var orderConnectionString = builder.Configuration.GetConnectionString("OrderDatabase")
    ?? "Server=sqlserver2,1433;Database=OrderDB;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;";

builder.Services.AddDbContext<CustomerDbContext>(options =>
    options.UseSqlServer(customerConnectionString));

builder.Services.AddDbContext<OrderDbContext>(options =>
    options.UseSqlServer(orderConnectionString));

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

// ANTI-PATTERN: Using default files without explicit configuration
app.UseDefaultFiles();

// ANTI-PATTERN: Serving static files without proper caching headers
// ANTI-PATTERN: No content security policy
app.UseStaticFiles();

// Initialize databases
try
{
    using var scope = app.Services.CreateScope();
    var customerDb = scope.ServiceProvider.GetRequiredService<CustomerDbContext>();
    var orderDb = scope.ServiceProvider.GetRequiredService<OrderDbContext>();

    await customerDb.Database.EnsureCreatedAsync();
    await orderDb.Database.EnsureCreatedAsync();
}
catch (Exception ex)
{
    app.Logger.LogError(ex, "Database initialization failed. The API will continue to run, but data operations may fail until the database is available.");
}

app.MapControllers();

// ANTI-PATTERN: Fallback route for SPA without proper configuration
app.MapFallbackToFile("index.html");

app.Run();
