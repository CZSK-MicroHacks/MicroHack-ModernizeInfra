using Microsoft.EntityFrameworkCore;
using ModernizeInfraApp.Data;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddOpenApi();

// Configure database contexts for two separate databases
builder.Services.AddDbContext<CustomerDbContext>(options =>
    options.UseSqlServer("Server=localhost,1433;Database=CustomerDB;User Id=sa;Password=YourStrongPass123!;TrustServerCertificate=True;"));

builder.Services.AddDbContext<OrderDbContext>(options =>
    options.UseSqlServer("Server=localhost,1435;Database=OrderDB;User Id=sa;Password=YourStrongPass123!;TrustServerCertificate=True;"));

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
using (var scope = app.Services.CreateScope())
{
    var customerDb = scope.ServiceProvider.GetRequiredService<CustomerDbContext>();
    var orderDb = scope.ServiceProvider.GetRequiredService<OrderDbContext>();
    
    await customerDb.Database.EnsureCreatedAsync();
    await orderDb.Database.EnsureCreatedAsync();
}

app.MapControllers();

// ANTI-PATTERN: Fallback route for SPA without proper configuration
app.MapFallbackToFile("index.html");

app.Run();
