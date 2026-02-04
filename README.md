# MicroHack-ModernizeInfra

Repository for CZ/SK MicroHack Infrastructure Modernization

## Overview

This repository contains:
1. **Modern Infrastructure Application** - .NET 10 Web API with SQL Server databases running in Docker
2. **On-Premises Simulator** - Azure VM deployment scripts to simulate legacy on-premises environment

## Architecture

This repository contains a modern infrastructure setup for app modernization, featuring:

- **.NET 10 Web API Application** - A modern ASP.NET Core web API server
- **Two SQL Server Databases** - Customer and Order databases running in separate containers
- **Database Links** - Configured linked servers for cross-database queries

## Components

### 1. .NET 10 Application Server
- ASP.NET Core Web API with .NET 10
- Entity Framework Core 10.0 for database access
- RESTful API endpoints for Customers and Orders
- OpenAPI/Swagger documentation

### 2. SQL Server Databases

#### Database 1: CustomerDB (sqlserver1)
- Stores customer information
- Port: 1433
- Tables: Customers

#### Database 2: OrderDB (sqlserver2)
- Stores order information
- Port: 1435 (mapped from container port 1433)
- Tables: Orders

### 3. Database Links
- Linked server from sqlserver1 to sqlserver2
- Enables cross-database queries
- Includes a view (`vw_CustomerOrders`) demonstrating linked server usage

## Prerequisites

- Docker and Docker Compose
- .NET 10 SDK (for local development)

## Quick Start

### Using Docker Compose (Recommended)

1. Clone the repository:
```bash
git clone https://github.com/CZSK-MicroHacks/MicroHack-ModernizeInfra.git
cd MicroHack-ModernizeInfra
```

2. Start all services:
```bash
docker-compose up -d
```

3. Wait for all services to be healthy (about 30-60 seconds):
```bash
docker-compose ps
```

4. Access the application:
- API Base URL: http://localhost:8080
- OpenAPI Documentation: http://localhost:8080/openapi/v1.json

### Local Development

1. Ensure .NET 10 SDK is installed:
```bash
dotnet --version
```

2. Navigate to the application directory:
```bash
cd ModernizeInfraApp
```

3. Restore dependencies:
```bash
dotnet restore
```

4. Run the application:
```bash
dotnet run
```

## API Endpoints

### Customers API
- `GET /api/customers` - Get all customers
- `GET /api/customers/{id}` - Get customer by ID
- `POST /api/customers` - Create new customer
- `PUT /api/customers/{id}` - Update customer
- `DELETE /api/customers/{id}` - Delete customer

### Orders API
- `GET /api/orders` - Get all orders
- `GET /api/orders/{id}` - Get order by ID
- `POST /api/orders` - Create new order
- `PUT /api/orders/{id}` - Update order
- `DELETE /api/orders/{id}` - Delete order

## Database Links

The setup includes a linked server configuration that allows querying across both databases. A view `vw_CustomerOrders` is created in the CustomerDB that joins data from both databases:

```sql
-- Example query using the linked server view
USE CustomerDB;
SELECT * FROM vw_CustomerOrders;
```

## Testing the Setup

### Test API Endpoints

```bash
# Create a customer
curl -X POST http://localhost:8080/api/customers \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}'

# Get all customers
curl http://localhost:8080/api/customers

# Create an order
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{"customerId":1,"productName":"Laptop","amount":999.99}'

# Get all orders
curl http://localhost:8080/api/orders
```

### Test Database Links

Connect to sqlserver1 and query the cross-database view:

```bash
docker exec -it sqlserver1 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrongPass123!' -C -Q "USE CustomerDB; SELECT * FROM vw_CustomerOrders;"
```

## Stopping the Services

```bash
docker-compose down
```

To also remove the volumes (databases will be deleted):
```bash
docker-compose down -v
```

## Configuration

### Database Connection Strings

Connection strings are configured in `appsettings.json` and can be overridden via environment variables:

```json
{
  "ConnectionStrings": {
    "CustomerDatabase": "Server=sqlserver1,1433;Database=CustomerDB;User Id=sa;Password=YourStrongPass123!;TrustServerCertificate=True;",
    "OrderDatabase": "Server=sqlserver2,1433;Database=OrderDB;User Id=sa;Password=YourStrongPass123!;TrustServerCertificate=True;"
  }
}
```

### Security Notes

⚠️ **Important**: The default SQL Server password (`YourStrongPass123!`) is for development only. Change it for production use.

## Troubleshooting

### Services not starting
Check the logs:
```bash
docker-compose logs
```

### Database connection issues
Verify SQL Server containers are healthy:
```bash
docker-compose ps
```

### Database link issues
Check the db-link-setup logs:
```bash
docker-compose logs db-link-setup
```

## Automated Deployment

The application includes **automated deployment** capabilities to deploy updates to target VMs:

### GitHub Actions CI/CD

The repository includes GitHub Actions workflows that automatically:
1. **Build** the application on every push to main
2. **Test** the application (if tests exist)
3. **Package** the application into `app-binaries.zip`
4. **Publish** as a GitHub Release

### Deployment to VM

The application can be deployed to a target VM using:

**Option 1: Manual Deployment (Recommended)**
```powershell
# On the target VM
cd C:\Apps\ModernizeInfraApp
.\update-application.ps1
```

**Option 2: Automatic Updates**
```powershell
# One-time setup on the target VM
.\setup-auto-update.ps1
# Application will automatically update daily at 2 AM
```

**Option 3: Azure VM Run Command (CI/CD)**
- Configure Azure credentials in GitHub Secrets
- Workflow automatically deploys to VM on push

See [DEPLOYMENT.md](./DEPLOYMENT.md) for complete documentation on:
- GitHub Actions workflows
- Deployment scripts
- Scheduled automatic updates
- Troubleshooting

## On-Premises Environment Simulator

For the Migrate and Modernize hackathon, you can deploy a Windows Azure VM that simulates an on-premises environment with SQL Server and the application running directly on the VM (not in containers).

This simulated on-premises environment serves as the starting point for migration exercises.

### Security Features

The deployment includes production-grade security:
- ✅ **No public IP on VM** - Access only via Azure Bastion
- ✅ **Azure Bastion** - Secure RDP access
- ✅ **Private endpoint for storage** - No public access
- ✅ **Entra ID authentication** - Azure AD login enabled
- ✅ **Managed identity** - No storage keys needed

### Quick Start for On-Premises Simulator

```bash
cd init-vm
./deploy-vm.sh
```

**Note:** The script will automatically generate a random strong password for the local admin user. Make sure to save it!

See the [init-vm/README.md](./init-vm/README.md) for complete documentation on:
- Deploying the Azure VM with security features
- Connecting via Azure Bastion
- Using Entra ID authentication
- Installing SQL Server instances
- Setting up linked servers
- Deploying the application

### What Gets Deployed

The on-premises simulator creates:
- Windows Server 2022 Azure VM (no public IP)
- Azure Bastion for secure access
- Azure Storage Account with private endpoint
- SQL Server 2022 with two instances (ports 1433 and 1435)
- CustomerDB and OrderDB with sample data
- Linked server configuration
- ASP.NET Core application running on the VM
- Azure AD Login extension for Entra ID authentication

This environment allows students to:
1. Explore a legacy on-premises setup with modern security
2. Plan migration strategies
3. Practice migrating to Azure services (Azure SQL, App Service, etc.)
4. Learn about secure Azure networking (Bastion, private endpoints)

## License

This project is for educational purposes as part of the CZ/SK MicroHack program.
