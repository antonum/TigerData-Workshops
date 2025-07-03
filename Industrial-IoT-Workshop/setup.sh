#!/bin/bash

# Industrial IoT Workshop Setup Script
# This script helps set up the workshop environment

set -e

echo "=== Industrial IoT Manufacturing Workshop Setup ==="
echo

# Check if psql is available
if ! command -v psql &> /dev/null; then
    echo "❌ psql not found. Please install PostgreSQL client tools."
    echo "   macOS: brew install postgresql"
    echo "   Ubuntu: sudo apt-get install postgresql-client"
    exit 1
fi

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ python3 not found. Please install Python 3.7 or later."
    exit 1
fi

echo "✅ Prerequisites check passed"
echo

# Get database connection string
echo "📝 Database Setup"
echo "Please enter your TimescaleDB connection string:"
echo "Example: postgresql://tsdbadmin:password@host:port/tsdb?sslmode=require"
read -p "Connection string: " CONNECTION_STRING

if [ -z "$CONNECTION_STRING" ]; then
    echo "❌ Connection string is required"
    exit 1
fi

# Test database connection
echo "🔍 Testing database connection..."
if psql "$CONNECTION_STRING" -c "SELECT version();" > /dev/null 2>&1; then
    echo "✅ Database connection successful"
else
    echo "❌ Failed to connect to database. Please check your connection string."
    exit 1
fi

echo

# Create database schema
echo "🏗️  Creating database schema..."
if psql "$CONNECTION_STRING" -f analyze-industrial-iot-data.sql; then
    echo "✅ Database schema created successfully"
else
    echo "❌ Failed to create database schema"
    exit 1
fi

echo

# Choose data generation method
echo "📊 Data Generation Options:"
echo "1. Simple generator (no dependencies, generates CSV files)"
echo "2. Full generator (requires Python packages, direct database insert)"
echo "3. Skip data generation"
read -p "Choose option (1/2/3): " DATA_OPTION

case $DATA_OPTION in
    1)
        echo "🐍 Running simple data generator..."
        python3 generate_sample_data.py
        echo "📥 Loading data into database..."
        psql "$CONNECTION_STRING" -f load_sample_data.sql
        echo "✅ Sample data loaded successfully"
        ;;
    2)
        echo "📦 Installing Python dependencies..."
        pip3 install -r requirements.txt
        
        echo "🐍 Running full data generator..."
        # Update connection string in the Python file
        sed -i.bak "s|CONNECTION_STRING = \".*\"|CONNECTION_STRING = \"$CONNECTION_STRING\"|" generate_iot_data.py
        python3 generate_iot_data.py
        echo "✅ Data generated and loaded successfully"
        ;;
    3)
        echo "⏭️  Skipping data generation"
        ;;
    *)
        echo "❌ Invalid option selected"
        exit 1
        ;;
esac

echo

# Workshop completion
echo "🎉 Workshop setup complete!"
echo
echo "Next steps:"
echo "1. Open analyze-industrial-iot-data.sql in your SQL client"
echo "2. Connect to your database: $CONNECTION_STRING"
echo "3. Run the queries step by step to explore the data"
echo
echo "Key features to explore:"
echo "• Real-time sensor monitoring"
echo "• Production efficiency analytics"
echo "• Quality control trending"
echo "• Predictive maintenance insights"
echo "• Columnar compression benefits"
echo "• Continuous aggregates for dashboards"
echo
echo "📚 See README.md for detailed instructions and explanations"
echo "🆘 For support, visit: https://docs.timescale.com/"
