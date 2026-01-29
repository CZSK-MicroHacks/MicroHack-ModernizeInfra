namespace ModernizeInfraApp.Models;

public class Order
{
    public int OrderId { get; set; }
    public int CustomerId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public DateTime OrderDate { get; set; }
}
