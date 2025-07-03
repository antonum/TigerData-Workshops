#!/usr/bin/env python3
"""
Industrial IoT Data Generator for TimescaleDB Workshop

This script generates realistic time-series data for manufacturing equipment
including sensor readings, production metrics, quality control data, and
maintenance events.

Requirements:
    pip install psycopg2-binary numpy pandas

Usage:
    python generate_iot_data.py

Configure your database connection in the CONNECTION_STRING variable below.
"""

import psycopg2
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import random
import json
import sys
from typing import List, Tuple, Dict

# Database connection string - update with your Timescale Cloud details
CONNECTION_STRING = "postgresql://tsdbadmin:password@host:port/tsdb?sslmode=require"

# Equipment IDs from the registry
EQUIPMENT_IDS = [
    'MOTOR_001', 'MOTOR_002', 'PUMP_001', 'PUMP_002', 'CONV_001', 
    'CONV_002', 'ROBOT_001', 'ROBOT_002', 'COMP_001', 'HVAC_001'
]

# Equipment type configurations
EQUIPMENT_CONFIG = {
    'MOTOR_001': {'type': 'motor', 'line': 'Line 1', 'temp_range': (45, 75), 'vib_range': (2, 12), 'pressure': None},
    'MOTOR_002': {'type': 'motor', 'line': 'Line 1', 'temp_range': (45, 75), 'vib_range': (2, 12), 'pressure': None},
    'PUMP_001': {'type': 'pump', 'line': 'Line 1', 'temp_range': (40, 65), 'vib_range': (5, 18), 'pressure': (180, 240)},
    'PUMP_002': {'type': 'pump', 'line': 'Line 2', 'temp_range': (40, 65), 'vib_range': (5, 18), 'pressure': (180, 240)},
    'CONV_001': {'type': 'conveyor', 'line': 'Line 1', 'temp_range': (25, 55), 'vib_range': (1, 8), 'pressure': None},
    'CONV_002': {'type': 'conveyor', 'line': 'Line 2', 'temp_range': (25, 55), 'vib_range': (1, 8), 'pressure': None},
    'ROBOT_001': {'type': 'robot', 'line': 'Line 1', 'temp_range': (35, 60), 'vib_range': (1, 6), 'pressure': None},
    'ROBOT_002': {'type': 'robot', 'line': 'Line 2', 'temp_range': (35, 60), 'vib_range': (1, 6), 'pressure': None},
    'COMP_001': {'type': 'compressor', 'line': 'Utility', 'temp_range': (60, 85), 'vib_range': (8, 22), 'pressure': (6, 7.5)},
    'HVAC_001': {'type': 'hvac', 'line': 'Factory Floor', 'temp_range': (18, 24), 'vib_range': (1, 4), 'pressure': None}
}

LINES = ['Line 1', 'Line 2']
PRODUCT_IDS = ['PROD_A001', 'PROD_B002', 'PROD_C003', 'PROD_D004']
TEST_TYPES = ['dimensional', 'visual', 'functional', 'electrical']
MAINTENANCE_TYPES = ['preventive', 'corrective', 'predictive']
INSPECTOR_IDS = ['INSP_001', 'INSP_002', 'INSP_003', 'INSP_004']
TECHNICIAN_IDS = ['TECH_001', 'TECH_002', 'TECH_003', 'TECH_004', 'TECH_005']

def connect_to_db():
    """Establish connection to TimescaleDB"""
    try:
        conn = psycopg2.connect(CONNECTION_STRING)
        return conn
    except psycopg2.Error as e:
        print(f"Error connecting to database: {e}")
        sys.exit(1)

def generate_sensor_data(start_time: datetime, end_time: datetime, interval_minutes: int = 1) -> List[Tuple]:
    """Generate realistic sensor data for all equipment"""
    data = []
    current_time = start_time
    
    # Create base patterns for each equipment
    equipment_states = {}
    for eq_id in EQUIPMENT_IDS:
        equipment_states[eq_id] = {
            'temp_drift': random.uniform(-0.1, 0.1),  # Daily temperature drift
            'vib_drift': random.uniform(-0.05, 0.05), # Vibration trend
            'maintenance_factor': 1.0,  # Factor for post-maintenance readings
            'fault_probability': 0.001  # Probability of fault per reading
        }
    
    print(f"Generating sensor data from {start_time} to {end_time}...")
    
    while current_time <= end_time:
        for equipment_id in EQUIPMENT_IDS:
            config = EQUIPMENT_CONFIG[equipment_id]
            state = equipment_states[equipment_id]
            
            # Time-based factors
            hour = current_time.hour
            day_of_week = current_time.weekday()
            
            # Operating schedule (reduced activity on weekends and nights)
            operating_factor = 1.0
            if day_of_week >= 5:  # Weekend
                operating_factor = 0.3
            elif hour < 6 or hour > 22:  # Night shift
                operating_factor = 0.6
            
            # Generate temperature reading
            temp_base = np.mean(config['temp_range'])
            temp_variation = (config['temp_range'][1] - config['temp_range'][0]) * 0.3
            
            # Add daily cycle, random variation, and drift
            daily_cycle = 3 * np.sin(2 * np.pi * hour / 24)
            temp_value = (temp_base + daily_cycle + 
                         random.gauss(0, temp_variation) + 
                         state['temp_drift'] * (current_time - start_time).days)
            
            # Determine status
            temp_status = 'normal'
            if temp_value > config['temp_range'][1]:
                temp_status = 'warning'
            if temp_value > config['temp_range'][1] * 1.1:
                temp_status = 'critical'
            
            data.append((current_time, equipment_id, 'temperature', 
                        round(temp_value, 1), 'celsius', temp_status))
            
            # Generate vibration reading
            vib_base = np.mean(config['vib_range'])
            vib_variation = (config['vib_range'][1] - config['vib_range'][0]) * 0.4
            
            vib_value = (vib_base * operating_factor + 
                        random.gauss(0, vib_variation) + 
                        state['vib_drift'] * (current_time - start_time).days)
            vib_value = max(0, vib_value)  # Vibration can't be negative
            
            vib_status = 'normal'
            if vib_value > config['vib_range'][1]:
                vib_status = 'warning'
            if vib_value > config['vib_range'][1] * 1.2:
                vib_status = 'critical'
            
            data.append((current_time, equipment_id, 'vibration', 
                        round(vib_value, 2), 'hz', vib_status))
            
            # Generate pressure reading (only for pumps and compressor)
            if config['pressure'] is not None:
                pressure_base = np.mean(config['pressure'])
                pressure_variation = (config['pressure'][1] - config['pressure'][0]) * 0.2
                
                pressure_value = (pressure_base * operating_factor + 
                                random.gauss(0, pressure_variation))
                
                pressure_status = 'normal'
                if pressure_value > config['pressure'][1]:
                    pressure_status = 'warning'
                if pressure_value > config['pressure'][1] * 1.05:
                    pressure_status = 'critical'
                
                data.append((current_time, equipment_id, 'pressure', 
                           round(pressure_value, 1), 'bar', pressure_status))
            
            # Generate humidity reading (for HVAC)
            if equipment_id == 'HVAC_001':
                humidity_value = random.uniform(45, 65)
                humidity_status = 'normal'
                if humidity_value > 70 or humidity_value < 40:
                    humidity_status = 'warning'
                
                data.append((current_time, equipment_id, 'humidity', 
                           round(humidity_value, 1), 'percent', humidity_status))
        
        current_time += timedelta(minutes=interval_minutes)
    
    print(f"Generated {len(data)} sensor readings")
    return data

def generate_production_metrics(start_time: datetime, end_time: datetime, interval_minutes: int = 5) -> List[Tuple]:
    """Generate production metrics data"""
    data = []
    current_time = start_time
    
    print(f"Generating production metrics from {start_time} to {end_time}...")
    
    while current_time <= end_time:
        for line_id in LINES:
            # Get equipment for this line
            line_equipment = [eq for eq, config in EQUIPMENT_CONFIG.items() 
                            if config['line'] == line_id]
            
            # Operating schedule factors
            hour = current_time.hour
            day_of_week = current_time.weekday()
            
            if day_of_week >= 5:  # Weekend
                base_efficiency = random.uniform(30, 50)
                base_throughput = random.uniform(10, 30)
            elif hour < 6 or hour > 22:  # Night shift
                base_efficiency = random.uniform(60, 80)
                base_throughput = random.uniform(40, 70)
            else:  # Day shift
                base_efficiency = random.uniform(80, 95)
                base_throughput = random.uniform(70, 120)
            
            # Add some correlation between equipment
            for equipment_id in line_equipment:
                # Cycle time varies with efficiency
                cycle_time = random.uniform(35, 55) * (100 / max(base_efficiency, 50))
                
                # Throughput (units per hour)
                throughput = base_throughput * random.uniform(0.8, 1.2)
                
                # Efficiency score
                efficiency = base_efficiency * random.uniform(0.9, 1.1)
                efficiency = max(0, min(100, efficiency))  # Clamp to 0-100
                
                # Energy consumption (correlated with throughput)
                energy_base = 8.0 if line_id == 'Line 1' else 7.5
                energy_consumption = energy_base + (throughput / 100) * 5 + random.uniform(-1, 1)
                
                # Downtime (inversely correlated with efficiency)
                downtime_prob = (100 - efficiency) / 100 * 0.3
                downtime = random.exponential(downtime_prob * 15) if random.random() < downtime_prob else 0
                
                # Defect rate (inversely correlated with efficiency)
                defect_rate = max(0, (100 - efficiency) / 10 + random.uniform(-1, 1))
                
                data.append((current_time, line_id, equipment_id, 
                           round(cycle_time, 1), round(throughput, 1), 
                           round(efficiency, 1), round(energy_consumption, 2),
                           round(downtime, 1), round(defect_rate, 2)))
        
        current_time += timedelta(minutes=interval_minutes)
    
    print(f"Generated {len(data)} production metric records")
    return data

def generate_quality_control_data(start_time: datetime, end_time: datetime) -> List[Tuple]:
    """Generate quality control test data"""
    data = []
    current_time = start_time
    
    print(f"Generating quality control data from {start_time} to {end_time}...")
    
    batch_counter = 1000
    
    while current_time <= end_time:
        # Random intervals for QC tests (every 30 minutes to 3 hours)
        next_test = current_time + timedelta(minutes=random.randint(30, 180))
        
        if next_test > end_time:
            break
        
        for line_id in LINES:
            if random.random() < 0.7:  # 70% chance of test per interval per line
                batch_id = f"BATCH_{batch_counter:06d}"
                batch_counter += 1
                
                product_id = random.choice(PRODUCT_IDS)
                test_type = random.choice(TEST_TYPES)
                inspector_id = random.choice(INSPECTOR_IDS)
                
                # Test results - 95% pass rate generally
                test_result = 'pass' if random.random() < 0.95 else 'fail'
                
                # Generate measurement values based on test type
                if test_type == 'dimensional':
                    # Dimensional tolerance test
                    tolerance_min = 10.0
                    tolerance_max = 10.5
                    if test_result == 'pass':
                        measurement = random.uniform(tolerance_min + 0.05, tolerance_max - 0.05)
                    else:
                        if random.random() < 0.5:
                            measurement = random.uniform(tolerance_min - 0.2, tolerance_min)
                        else:
                            measurement = random.uniform(tolerance_max, tolerance_max + 0.2)
                elif test_type == 'electrical':
                    # Electrical resistance test
                    tolerance_min = 45.0
                    tolerance_max = 55.0
                    if test_result == 'pass':
                        measurement = random.uniform(tolerance_min + 1, tolerance_max - 1)
                    else:
                        if random.random() < 0.5:
                            measurement = random.uniform(tolerance_min - 5, tolerance_min)
                        else:
                            measurement = random.uniform(tolerance_max, tolerance_max + 5)
                else:
                    # Visual/functional tests - no numeric measurement
                    measurement = None
                    tolerance_min = None
                    tolerance_max = None
                
                data.append((next_test, batch_id, line_id, product_id, test_type,
                           test_result, measurement, tolerance_min, tolerance_max, inspector_id))
        
        current_time = next_test
    
    print(f"Generated {len(data)} quality control records")
    return data

def generate_maintenance_events(start_time: datetime, end_time: datetime) -> List[Tuple]:
    """Generate maintenance event data"""
    data = []
    
    print(f"Generating maintenance events from {start_time} to {end_time}...")
    
    for equipment_id in EQUIPMENT_IDS:
        current_time = start_time
        
        # Schedule regular preventive maintenance (monthly)
        while current_time <= end_time:
            # Preventive maintenance
            maint_time = current_time + timedelta(days=random.randint(28, 35))
            if maint_time <= end_time:
                duration = random.uniform(2, 6)  # 2-6 hours
                cost = random.uniform(500, 2000)
                technician = random.choice(TECHNICIAN_IDS)
                description = f"Scheduled preventive maintenance for {equipment_id}"
                parts = ['filters', 'lubricants'] if random.random() < 0.7 else None
                
                data.append((maint_time, equipment_id, 'scheduled', 'preventive',
                           round(duration, 1), round(cost, 2), technician, description, parts))
            
            # Random chance of unscheduled maintenance
            days_passed = (current_time - start_time).days
            for day in range(days_passed, days_passed + 30):
                if random.random() < 0.02:  # 2% chance per day
                    fault_time = start_time + timedelta(days=day, hours=random.randint(8, 18))
                    if fault_time <= end_time:
                        duration = random.uniform(1, 8)  # 1-8 hours
                        cost = random.uniform(200, 5000)
                        technician = random.choice(TECHNICIAN_IDS)
                        
                        fault_types = ['bearing failure', 'sensor malfunction', 'electrical issue', 
                                     'hydraulic leak', 'belt replacement', 'calibration drift']
                        fault_desc = random.choice(fault_types)
                        description = f"Unscheduled repair: {fault_desc}"
                        
                        parts_options = [
                            ['bearings', 'seals'],
                            ['sensors', 'wiring'],
                            ['electrical_components'],
                            ['hydraulic_seals', 'hoses'],
                            ['belts', 'pulleys'],
                            ['calibration_tools']
                        ]
                        parts = random.choice(parts_options) if random.random() < 0.8 else None
                        
                        data.append((fault_time, equipment_id, 'unscheduled', 'corrective',
                                   round(duration, 1), round(cost, 2), technician, description, parts))
            
            current_time = maint_time
    
    print(f"Generated {len(data)} maintenance events")
    return data

def insert_data_batch(conn, table_name: str, data: List[Tuple], columns: str):
    """Insert data in batches for better performance"""
    cursor = conn.cursor()
    batch_size = 1000
    total_records = len(data)
    
    for i in range(0, total_records, batch_size):
        batch = data[i:i + batch_size]
        
        # Create the INSERT statement with placeholders
        placeholders = ','.join(['%s'] * len(batch))
        query = f"INSERT INTO {table_name} {columns} VALUES %s"
        
        try:
            psycopg2.extras.execute_values(cursor, query, batch, page_size=batch_size)
            conn.commit()
            print(f"Inserted batch {i//batch_size + 1}/{(total_records-1)//batch_size + 1} for {table_name}")
        except psycopg2.Error as e:
            print(f"Error inserting batch into {table_name}: {e}")
            conn.rollback()
            return False
    
    cursor.close()
    return True

def main():
    """Main function to generate and insert all IoT data"""
    # Time range for data generation (last 7 days)
    end_time = datetime.now()
    start_time = end_time - timedelta(days=7)
    
    print("=== Industrial IoT Data Generator ===")
    print(f"Generating data from {start_time} to {end_time}")
    print(f"Database: {CONNECTION_STRING.split('@')[1].split('/')[0] if '@' in CONNECTION_STRING else 'localhost'}")
    
    # Connect to database
    conn = connect_to_db()
    print("Connected to TimescaleDB")
    
    try:
        # Generate sensor data (1-minute intervals)
        print("\n1. Generating sensor data...")
        sensor_data = generate_sensor_data(start_time, end_time, interval_minutes=1)
        success = insert_data_batch(
            conn, 'sensor_data', sensor_data,
            '(time, equipment_id, sensor_type, value, unit, status)'
        )
        if not success:
            print("Failed to insert sensor data")
            return
        
        # Generate production metrics (5-minute intervals)
        print("\n2. Generating production metrics...")
        production_data = generate_production_metrics(start_time, end_time, interval_minutes=5)
        success = insert_data_batch(
            conn, 'production_metrics', production_data,
            '(time, line_id, equipment_id, cycle_time, throughput, efficiency_score, energy_consumption, downtime_duration, defect_rate)'
        )
        if not success:
            print("Failed to insert production metrics")
            return
        
        # Generate quality control data
        print("\n3. Generating quality control data...")
        quality_data = generate_quality_control_data(start_time, end_time)
        success = insert_data_batch(
            conn, 'quality_control', quality_data,
            '(time, batch_id, line_id, product_id, test_type, test_result, measurement_value, tolerance_min, tolerance_max, inspector_id)'
        )
        if not success:
            print("Failed to insert quality control data")
            return
        
        # Generate maintenance events
        print("\n4. Generating maintenance events...")
        maintenance_data = generate_maintenance_events(start_time, end_time)
        success = insert_data_batch(
            conn, 'maintenance_events', maintenance_data,
            '(time, equipment_id, event_type, maintenance_type, duration, cost, technician_id, description, parts_replaced)'
        )
        if not success:
            print("Failed to insert maintenance events")
            return
        
        print("\n=== Data Generation Complete ===")
        print(f"Total sensor readings: {len(sensor_data):,}")
        print(f"Total production metrics: {len(production_data):,}")
        print(f"Total quality control records: {len(quality_data):,}")
        print(f"Total maintenance events: {len(maintenance_data):,}")
        print("\nYou can now run the SQL queries in analyze-industrial-iot-data.sql")
        
    except Exception as e:
        print(f"Error during data generation: {e}")
    finally:
        conn.close()
        print("Database connection closed")

if __name__ == "__main__":
    # Import required for batch inserts
    import psycopg2.extras
    main()
