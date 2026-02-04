using Microsoft.EntityFrameworkCore;
using ModernizeInfraApp.Models;

namespace ModernizeInfraApp.Data;

public class CustomerDbContext : DbContext
{
    private const string ConnectionString = "Server=localhost,1433;Database=CustomerDB;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;";

    public CustomerDbContext(DbContextOptions<CustomerDbContext> options)
        : base(options)
    {
    }

    public DbSet<Customer> Customers { get; set; }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        if (!optionsBuilder.IsConfigured)
        {
            optionsBuilder.UseSqlServer(ConnectionString);
        }
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Customer>(entity =>
        {
            entity.HasKey(e => e.CustomerId);
            entity.Property(e => e.Name).IsRequired().HasMaxLength(200);
            entity.Property(e => e.Email).IsRequired().HasMaxLength(200);
        });
    }
}
