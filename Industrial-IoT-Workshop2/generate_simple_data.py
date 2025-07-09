#!/usr/bin/env python3
"""
Simple IoT Data Generator for TimescaleDB Workshop

Generates realistic sensor data for 6 pieces of equipment over the last 3 days.
Uses only Python standard library - no external dependencies required.

Usage:
    python3 generate_simple_data.py

Creates:
    - sensor_data.csv (for loading via COPY command)
    - load_data.sql (script to load the CSV)
"""

import csv
import math
import random
import datetime
from typing import List, Tuple

# Equipment configuration
EQUIPMENT = [
    {'id': 'MOTOR_001', 'type': 'motor', 'temp_range': (45, 75), 'vib_range': (2, 12)},
    {'id': 'MOTOR_002', 'type': 'motor', 'temp_range': (45, 75), 'vib_range': (2, 12)},
    {'id': 'PUMP_001', 'type': 'pump', 'temp_range': (40, 70), 'vib_range': (5, 18)},
    {'id': 'PUMP_002', 'type': 'pump', 'temp_range': (40, 70), 'vib_range': (5, 18)},
    {'id': 'CONV_001', 'type': 'conveyor', 'temp_range': (25, 60), 'vib_range': (1, 8)},
    {'id': 'ROBOT_001', 'type': 'robot', 'temp_range': (35, 65), 'vib_range': (1, 6)},
]

def determine_status(temp_value: float, temp_max: float, vib_value: float, vib_max: float) -> str:
    """Determine equipment status based on sensor values"""
    if temp_value > temp_max or vib_value > vib_max:
        return 'critical'
    elif temp_value > temp_max * 0.9 or vib_value > vib_max * 0.9:
        return 'warning'
    else:
        return 'normal'

def generate_sensor_data() -> List[Tuple]:
    """Generate realistic sensor data for all equipment"""
    data = []
    
    # Generate data for last 3 days with 2-minute intervals
    end_time = datetime.datetime.now()
    start_time = end_time - datetime.timedelta(days=3)
    current_time = start_time
    
    print(f"Generating sensor data from {start_time} to {end_time}...")
    
    # Equipment state tracking for realistic patterns
    equipment_state = {}
    for eq in EQUIPMENT:
        equipment_state[eq['id']] = {
            'temp_drift': random.uniform(-0.1, 0.1),  # Daily temperature drift
            'base_temp': sum(eq['temp_range']) / 2,   # Base temperature
            'base_vib': sum(eq['vib_range']) / 2,     # Base vibration
        }
    
    while current_time <= end_time:
        for equipment in EQUIPMENT:
            eq_id = equipment['id']
            state = equipment_state[eq_id]
            
            # Time-based factors
            hour = current_time.hour
            day_of_week = current_time.weekday()
            
            # Operating schedule (reduced activity on weekends and nights)
            if day_of_week >= 5:  # Weekend
                operating_factor = 0.4
            elif hour < 6 or hour > 22:  # Night shift
                operating_factor = 0.7
            else:  # Day shift
                operating_factor = 1.0
            
            # Temperature generation
            # Daily cycle + random variation + drift over time
            daily_cycle = 4 * math.sin(2 * math.pi * hour / 24)
            temp_variation = (equipment['temp_range'][1] - equipment['temp_range'][0]) * 0.2
            days_elapsed = (current_time - start_time).days
            
            temperature = (
                state['base_temp'] + 
                daily_cycle + 
                random.gauss(0, temp_variation) + 
                state['temp_drift'] * days_elapsed +
                (operating_factor - 0.7) * 5  # Higher temp when operating more
            )
            
            # Vibration generation
            vib_variation = (equipment['vib_range'][1] - equipment['vib_range'][0]) * 0.3
            vibration = (
                state['base_vib'] * operating_factor + 
                random.gauss(0, vib_variation) +
                random.uniform(-1, 1)  # Random fluctuation
            )
            vibration = max(0.1, vibration)  # Minimum vibration
            
            # Determine status
            temp_max = equipment['temp_range'][1]
            vib_max = equipment['vib_range'][1]
            status = determine_status(temperature, temp_max, vibration, vib_max)
            
            # Add occasional random spikes for more realistic data
            if random.random() < 0.005:  # 0.5% chance of spike
                temperature += random.uniform(5, 15)
                status = determine_status(temperature, temp_max, vibration, vib_max)
            
            data.append((
                current_time.strftime('%Y-%m-%d %H:%M:%S%z'),
                eq_id,
                round(temperature, 1),
                round(vibration, 2),
                status
            ))
        
        current_time += datetime.timedelta(minutes=2)
    
    print(f"Generated {len(data):,} sensor readings")
    return data

def create_csv_file(data: List[Tuple]):
    """Create CSV file with sensor data"""
    filename = 'sensor_data.csv'
    
    with open(filename, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        # Write header
        writer.writerow(['time', 'equipment_id', 'temperature', 'vibration', 'status'])
        
        # Write data
        for row in data:
            writer.writerow(row)
    
    print(f"Created {filename}")

def create_load_script():
    """Create SQL script to load the CSV data"""
    script_content = """-- Load sensor data into TimescaleDB
-- Run this after creating the tables in analyze-simple-iot-data.sql

\\echo 'Loading sensor data...'
\\COPY sensor_readings FROM 'sensor_data.csv' CSV HEADER;

-- Verify data load
\\echo 'Data load verification:'
SELECT 
    'Total records loaded:' as info,
    COUNT(*)::text as count
FROM sensor_readings
UNION ALL
SELECT 
    'Time range:',
    CONCAT(
        MIN(time)::date::text, 
        ' to ', 
        MAX(time)::date::text
    )
FROM sensor_readings
UNION ALL
SELECT 
    'Equipment count:',
    COUNT(DISTINCT equipment_id)::text
FROM sensor_readings;

\\echo 'Sample data:'
SELECT 
    time,
    equipment_id,
    temperature,
    vibration,
    status
FROM sensor_readings 
ORDER BY time DESC 
LIMIT 10;

\\echo 'Status distribution:'
SELECT 
    status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as percentage
FROM sensor_readings 
GROUP BY status 
ORDER BY count DESC;
"""
    
    with open('load_data.sql', 'w') as f:
        f.write(script_content)
    
    print("Created load_data.sql")

def main():
    """Generate all data files"""
    print("=== Simple IoT Data Generator ===")
    print("Generating realistic sensor data for TimescaleDB workshop...")
    print()
    
    # Generate the data
    sensor_data = generate_sensor_data()
    
    # Create CSV file
    create_csv_file(sensor_data)
    
    # Create load script
    create_load_script()
    
    print()
    print("=== Generation Complete ===")
    print("Files created:")
    print("  - sensor_data.csv (sensor readings)")
    print("  - load_data.sql (loading script)")
    print()
    print("To use the data:")
    print("1. Create tables: psql -d 'connection_string' -f analyze-simple-iot-data.sql")
    print("2. Load data: psql -d 'connection_string' -f load_data.sql")
    print()
    
    # Show some statistics
    total_records = len(sensor_data)
    equipment_count = len(EQUIPMENT)
    days = 3
    hours_per_day = 24
    readings_per_hour = 30  # Every 2 minutes
    expected = equipment_count * days * hours_per_day * readings_per_hour
    
    print(f"Data statistics:")
    print(f"  - Equipment pieces: {equipment_count}")
    print(f"  - Time period: {days} days")
    print(f"  - Reading interval: 2 minutes")
    print(f"  - Total records: {total_records:,}")
    print(f"  - Expected records: {expected:,}")

if __name__ == "__main__":
    main()
