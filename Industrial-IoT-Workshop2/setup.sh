#!/bin/bash

# Simple Industrial IoT Workshop Setup Script

set -e

echo "=== Simple Industrial IoT Workshop Setup ==="
echo "A streamlined TimescaleDB workshop with just 2 tables:"
echo "• 1 hypertable (sensor_readings) for time-series data"
echo "• 1 regular table (equipment) for reference data"
echo

# Check prerequisites
if ! command -v psql &> /dev/null; then
    echo "❌ psql not found. Please install PostgreSQL client tools."
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "❌ python3 not found. Please install Python 3.7 or later."
    exit 1
fi

echo "✅ Prerequisites check passed"
echo

# Get database connection
echo "📝 Database Connection"
echo "Enter your TimescaleDB connection string:"
echo "Example: postgresql://user:password@host:port/database?sslmode=require"
read -p "Connection string: " CONNECTION_STRING

if [ -z "$CONNECTION_STRING" ]; then
    echo "❌ Connection string is required"
    exit 1
fi

# Test connection
echo "🔍 Testing database connection..."
if psql "$CONNECTION_STRING" -c "SELECT version();" > /dev/null 2>&1; then
    echo "✅ Database connection successful"
else
    echo "❌ Failed to connect to database"
    exit 1
fi

echo

# Create schema
echo "🏗️  Creating database schema (2 tables)..."
if psql "$CONNECTION_STRING" -f analyze-simple-iot-data.sql; then
    echo "✅ Tables created:"
    echo "   • equipment (reference table)"
    echo "   • sensor_readings (hypertable)"
else
    echo "❌ Failed to create schema"
    exit 1
fi

echo

# Generate and load data
echo "📊 Generating sample sensor data..."
if python3 generate_simple_data.py; then
    echo "✅ Sample data generated"
else
    echo "❌ Failed to generate data"
    exit 1
fi

echo "📥 Loading data into TimescaleDB..."
if psql "$CONNECTION_STRING" -f load_data.sql; then
    echo "✅ Data loaded successfully"
else
    echo "❌ Failed to load data"
    exit 1
fi

echo

# Show summary
echo "🎉 Workshop setup complete!"
echo
echo "📊 What was created:"
echo "   • 6 pieces of equipment (motors, pumps, conveyor, robot)"
echo "   • 3 days of sensor data (~13,000 readings)"
echo "   • Temperature and vibration sensors"
echo "   • Realistic operational patterns"
echo
echo "🚀 Next steps:"
echo "1. Open analyze-simple-iot-data.sql in your SQL client"
echo "2. Connect to: $CONNECTION_STRING"
echo "3. Run the queries step-by-step to explore:"
echo "   • Real-time equipment monitoring"
echo "   • Time-bucketed aggregations"
echo "   • Compression benefits (90%+ storage savings)"
echo "   • Continuous aggregates for dashboards"
echo
echo "📚 Key concepts demonstrated:"
echo "   ✓ Hypertables for time-series data"
echo "   ✓ Joining time-series with reference data"
echo "   ✓ Columnar compression"
echo "   ✓ Continuous aggregates"
echo "   ✓ Real-time analytics"
echo
echo "🆘 Need help? Check README.md or visit docs.timescale.com"
