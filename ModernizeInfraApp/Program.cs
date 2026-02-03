using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using ModernizeInfraApp.Data;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddOpenApi();

// Configure database contexts for two separate databases
var customerConnectionString = builder.Configuration.GetConnectionString("CustomerDatabase");

var orderConnectionString = builder.Configuration.GetConnectionString("OrderDatabase");

if (string.IsNullOrWhiteSpace(customerConnectionString) || string.IsNullOrWhiteSpace(orderConnectionString))
{
    throw new InvalidOperationException("Connection strings for CustomerDatabase and OrderDatabase are required.");
}

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
catch (Exception ex) when (ex is SqlException || ex is DbUpdateException)
{
    app.Logger.LogError(
        ex,
        "Database initialization failed. Frontend remains available but data operations will fail until database connectivity is restored. Hint: {Hint}",
        "Check connection strings and database availability.");
}

app.MapControllers();

// ANTI-PATTERN: Fallback route for SPA without proper configuration
app.MapFallbackToFile("index.html");

app.Run();
