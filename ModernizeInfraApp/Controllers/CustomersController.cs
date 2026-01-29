using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModernizeInfraApp.Data;
using ModernizeInfraApp.Models;

namespace ModernizeInfraApp.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CustomersController : ControllerBase
{
    private readonly CustomerDbContext _context;

    public CustomersController(CustomerDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Customer>>> GetCustomers()
    {
        return await _context.Customers.ToListAsync();
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Customer>> GetCustomer(int id)
    {
        var customer = await _context.Customers.FindAsync(id);

        if (customer == null)
        {
            return NotFound();
        }

        return customer;
    }

    [HttpPost]
    public async Task<ActionResult<Customer>> PostCustomer(Customer customer)
    {
        customer.CreatedDate = DateTime.UtcNow;
        _context.Customers.Add(customer);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetCustomer), new { id = customer.CustomerId }, customer);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> PutCustomer(int id, Customer customer)
    {
        if (id != customer.CustomerId)
        {
            return BadRequest();
        }

        _context.Entry(customer).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!await CustomerExists(id))
            {
                return NotFound();
            }
            throw;
        }

        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteCustomer(int id)
    {
        var customer = await _context.Customers.FindAsync(id);
        if (customer == null)
        {
            return NotFound();
        }

        _context.Customers.Remove(customer);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    private async Task<bool> CustomerExists(int id)
    {
        return await _context.Customers.AnyAsync(e => e.CustomerId == id);
    }
}
