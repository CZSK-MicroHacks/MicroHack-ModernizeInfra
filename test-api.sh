#!/bin/bash

# Test script for the MicroHack Infrastructure API

BASE_URL="http://localhost:8080"

echo "======================================"
echo "Testing MicroHack Infrastructure API"
echo "======================================"
echo ""

# Test 1: Create a customer
echo "1. Creating a customer..."
CUSTOMER_RESPONSE=$(curl -s -X POST "$BASE_URL/api/customers" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john.doe@example.com"
  }')

echo "Response: $CUSTOMER_RESPONSE"
CUSTOMER_ID=$(echo $CUSTOMER_RESPONSE | grep -o '"customerId":[0-9]*' | grep -o '[0-9]*')
echo "Created Customer ID: $CUSTOMER_ID"
echo ""

# Test 2: Get all customers
echo "2. Getting all customers..."
curl -s "$BASE_URL/api/customers" | python3 -m json.tool || echo "Response received"
echo ""

# Test 3: Create an order
echo "3. Creating an order..."
ORDER_RESPONSE=$(curl -s -X POST "$BASE_URL/api/orders" \
  -H "Content-Type: application/json" \
  -d "{
    \"customerId\": $CUSTOMER_ID,
    \"productName\": \"Laptop\",
    \"amount\": 999.99
  }")

echo "Response: $ORDER_RESPONSE"
ORDER_ID=$(echo $ORDER_RESPONSE | grep -o '"orderId":[0-9]*' | grep -o '[0-9]*')
echo "Created Order ID: $ORDER_ID"
echo ""

# Test 4: Get all orders
echo "4. Getting all orders..."
curl -s "$BASE_URL/api/orders" | python3 -m json.tool || echo "Response received"
echo ""

# Test 5: Get specific customer
echo "5. Getting customer by ID..."
curl -s "$BASE_URL/api/customers/$CUSTOMER_ID" | python3 -m json.tool || echo "Response received"
echo ""

# Test 6: Create another customer
echo "6. Creating another customer..."
CUSTOMER2_RESPONSE=$(curl -s -X POST "$BASE_URL/api/customers" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Jane Smith",
    "email": "jane.smith@example.com"
  }')

echo "Response: $CUSTOMER2_RESPONSE"
echo ""

# Test 7: Create order for second customer
echo "7. Creating order for second customer..."
CUSTOMER2_ID=$(echo $CUSTOMER2_RESPONSE | grep -o '"customerId":[0-9]*' | grep -o '[0-9]*')
ORDER2_RESPONSE=$(curl -s -X POST "$BASE_URL/api/orders" \
  -H "Content-Type: application/json" \
  -d "{
    \"customerId\": $CUSTOMER2_ID,
    \"productName\": \"Smartphone\",
    \"amount\": 699.99
  }")

echo "Response: $ORDER2_RESPONSE"
echo ""

echo "======================================"
echo "Testing Complete!"
echo "======================================"
echo ""
echo "Summary:"
echo "  - Created 2 customers"
echo "  - Created 2 orders"
echo "  - Retrieved customer and order lists"
echo ""
echo "To test database links, connect to SQL Server 1 and query:"
echo "  USE CustomerDB;"
echo "  SELECT * FROM vw_CustomerOrders;"
echo ""
