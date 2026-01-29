using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModernizeInfraApp.Data;
using ModernizeInfraApp.Models;

namespace ModernizeInfraApp.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly OrderDbContext _context;

    public OrdersController(OrderDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Order>>> GetOrders()
    {
        return await _context.Orders.ToListAsync();
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Order>> GetOrder(int id)
    {
        var order = await _context.Orders.FindAsync(id);

        if (order == null)
        {
            return NotFound();
        }

        return order;
    }

    [HttpPost]
    public async Task<ActionResult<Order>> PostOrder(Order order)
    {
        // Validate input
        if (order.CustomerId <= 0)
        {
            return BadRequest("Valid CustomerId is required.");
        }

        if (string.IsNullOrWhiteSpace(order.ProductName))
        {
            return BadRequest("Product name is required.");
        }

        if (order.Amount <= 0)
        {
            return BadRequest("Amount must be greater than zero.");
        }

        order.OrderDate = DateTime.UtcNow;
        _context.Orders.Add(order);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetOrder), new { id = order.OrderId }, order);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> PutOrder(int id, Order order)
    {
        if (id != order.OrderId)
        {
            return BadRequest();
        }

        _context.Entry(order).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!await OrderExists(id))
            {
                return NotFound();
            }
            throw;
        }

        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteOrder(int id)
    {
        var order = await _context.Orders.FindAsync(id);
        if (order == null)
        {
            return NotFound();
        }

        _context.Orders.Remove(order);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    private async Task<bool> OrderExists(int id)
    {
        return await _context.Orders.AnyAsync(e => e.OrderId == id);
    }
}
