using Microsoft.EntityFrameworkCore;
using ModernizeInfraApp.Models;

namespace ModernizeInfraApp.Data;

public class OrderDbContext : DbContext
{
    private const string ConnectionString = "Server=sqlserver2,1435;Database=OrderDB;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;";

    public OrderDbContext(DbContextOptions<OrderDbContext> options)
        : base(options)
    {
    }

    public DbSet<Order> Orders { get; set; }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        if (!optionsBuilder.IsConfigured)
        {
            optionsBuilder.UseSqlServer(ConnectionString);
        }
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Order>(entity =>
        {
            entity.HasKey(e => e.OrderId);
            entity.Property(e => e.ProductName).IsRequired().HasMaxLength(200);
            entity.Property(e => e.Amount).HasColumnType("decimal(18,2)");
        });
    }
}
