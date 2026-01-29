using Microsoft.EntityFrameworkCore;
using ModernizeInfraApp.Data;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddOpenApi();

// Configure database contexts for two separate databases
// NOTE: Connection strings contain hardcoded credentials for development/demo purposes only.
// For production, use environment variables, Azure Key Vault, or other secure secrets management.
builder.Services.AddDbContext<CustomerDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("CustomerDatabase") ?? 
        "Server=sqlserver1,1433;Database=CustomerDB;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;"));

builder.Services.AddDbContext<OrderDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("OrderDatabase") ?? 
        "Server=sqlserver2,1433;Database=OrderDB;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;"));

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

// Initialize databases
// NOTE: EnsureCreatedAsync is used for demo/development simplicity.
// For production, use EF Core Migrations (dotnet ef migrations) for proper schema version control.
using (var scope = app.Services.CreateScope())
{
    var customerDb = scope.ServiceProvider.GetRequiredService<CustomerDbContext>();
    var orderDb = scope.ServiceProvider.GetRequiredService<OrderDbContext>();
    
    await customerDb.Database.EnsureCreatedAsync();
    await orderDb.Database.EnsureCreatedAsync();
}

app.MapControllers();

app.Run();
