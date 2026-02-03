# Architecture Documentation

## System Overview

This MicroHack demonstrates a modernized infrastructure with:
- .NET 10 Web API Application Server
- Two SQL Server 2022 Databases
- Database Links for cross-database queries

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Docker Network                         │
│                      (app-network)                          │
│                                                             │
│  ┌────────────────┐                                        │
│  │   .NET 10 App  │                                        │
│  │   (Port 8080)  │                                        │
│  │                │                                        │
│  │  Controllers:  │                                        │
│  │  - Customers   │                                        │
│  │  - Orders      │                                        │
│  └────┬────┬──────┘                                        │
│       │    │                                               │
│       │    │                                               │
│       │    └─────────────────┐                            │
│       │                      │                            │
│  ┌────▼─────────┐      ┌────▼─────────┐                  │
│  │ SQL Server 1 │◄─────┤ SQL Server 2 │                  │
│  │ (Port 1433)  │      │ (Port 1435)  │                  │
│  │              │      │              │                  │
│  │ CustomerDB   │      │   OrderDB    │                  │
│  │              │      │              │                  │
│  │ Tables:      │      │ Tables:      │                  │
│  │ - Customers  │      │ - Orders     │                  │
│  │              │      │              │                  │
│  │ Views:       │      │              │                  │
│  │ - vw_Customer│      │              │                  │
│  │   Orders     │      │              │                  │
│  │   (uses link)│      │              │                  │
│  └──────────────┘      └──────────────┘                  │
│                                                            │
│  Database Link: SQLSERVER2_LINK                           │
│  (from SQL Server 1 to SQL Server 2)                      │
└────────────────────────────────────────────────────────────┘
```

## Components

### 1. .NET 10 Web API Application

**Technology Stack:**
- ASP.NET Core 10.0
- Entity Framework Core 10.0
- OpenAPI/Swagger

**Features:**
- RESTful API design
- Two separate DbContexts for database isolation
- Health checks for database connectivity
- OpenAPI documentation

**Endpoints:**
- Customers API: Full CRUD operations
- Orders API: Full CRUD operations

### 2. SQL Server Databases

#### CustomerDB (SQL Server 1)
**Purpose:** Stores customer information

**Schema:**
```sql
CREATE TABLE Customers (
    CustomerId INT PRIMARY KEY IDENTITY(1,1),
    Name NVARCHAR(200) NOT NULL,
    Email NVARCHAR(200) NOT NULL,
    CreatedDate DATETIME2 NOT NULL
);
```

#### OrderDB (SQL Server 2)
**Purpose:** Stores order information

**Schema:**
```sql
CREATE TABLE Orders (
    OrderId INT PRIMARY KEY IDENTITY(1,1),
    CustomerId INT NOT NULL,
    ProductName NVARCHAR(200) NOT NULL,
    Amount DECIMAL(18,2) NOT NULL,
    OrderDate DATETIME2 NOT NULL
);
```

### 3. Database Links

**Linked Server Configuration:**
- Name: `SQLSERVER2_LINK`
- Source: SQL Server 1 (CustomerDB)
- Target: SQL Server 2 (OrderDB)
- Authentication: SQL Server Authentication

**Cross-Database View:**
```sql
CREATE VIEW vw_CustomerOrders AS
SELECT 
    c.CustomerId,
    c.Name,
    c.Email,
    c.CreatedDate,
    o.OrderId,
    o.ProductName,
    o.Amount,
    o.OrderDate
FROM 
    CustomerDB.dbo.Customers c
    LEFT JOIN SQLSERVER2_LINK.OrderDB.dbo.Orders o 
    ON c.CustomerId = o.CustomerId;
```

## Data Flow

1. **Customer Creation:**
   - Client → POST /api/customers → .NET App
   - .NET App → CustomerDbContext → SQL Server 1 (CustomerDB)

2. **Order Creation:**
   - Client → POST /api/orders → .NET App
   - .NET App → OrderDbContext → SQL Server 2 (OrderDB)

3. **Cross-Database Query:**
   - SQL Server 1 → SQLSERVER2_LINK → SQL Server 2
   - View vw_CustomerOrders joins data from both databases

## Deployment

### Docker Compose Services

1. **sqlserver1** - Primary SQL Server instance
2. **sqlserver2** - Secondary SQL Server instance
3. **db-link-setup** - One-time setup container for database links
4. **app** - .NET 10 application server

### Service Dependencies

```
app → depends on → sqlserver1 (healthy)
                → sqlserver2 (healthy)
                → db-link-setup (started)

db-link-setup → depends on → sqlserver1 (healthy)
                           → sqlserver2 (healthy)
```

### Volumes

- `sqlserver1-data` - Persistent storage for CustomerDB
- `sqlserver2-data` - Persistent storage for OrderDB

### Networking

All services communicate over a bridge network (`app-network`)

## Security Considerations

⚠️ **Production Recommendations:**

1. Change default SA password
2. Use environment variables for secrets
3. Implement proper authentication/authorization
4. Use TLS/SSL for database connections
5. Configure network policies
6. Implement audit logging
7. Use Azure Key Vault or similar for secrets management

## Scalability

**Horizontal Scaling:**
- Multiple .NET app instances can be deployed
- Load balancer can be added in front of app containers
- Database read replicas can be configured

**Vertical Scaling:**
- Increase CPU/memory for SQL Server containers
- Adjust connection pool sizes in application

## Monitoring

**Recommended Monitoring:**
- Application performance monitoring (APM)
- Database performance metrics
- Container resource usage
- API response times
- Database connection pool statistics

## Troubleshooting

### Common Issues

1. **Database Connection Timeout**
   - Verify SQL Server containers are healthy
   - Check network connectivity
   - Verify connection strings

2. **Database Link Failures**
   - Check SQLSERVER2_LINK configuration
   - Verify network connectivity between containers
   - Check SA password matches

3. **Application Startup Failures**
   - Review application logs
   - Verify database migrations completed
   - Check environment variables

## Future Enhancements

1. Add Redis cache layer
2. Implement message queue (RabbitMQ/Azure Service Bus)
3. Add authentication/authorization (Azure AD)
4. Implement distributed tracing
5. Add Kubernetes deployment manifests
6. Implement database migrations with EF Core Migrations
