#!/usr/bin/env python3
"""
Simple IoT Data Generator (No External Dependencies)

This script generates sample CSV files for the Industrial IoT workshop
without requiring any external Python packages beyond the standard library.

Usage:
    python generate_sample_data.py

This will create CSV files that can be loaded using COPY commands in PostgreSQL.
"""

import csv
import math
import random
import datetime
from typing import List, Dict, Any

# Equipment configurations
EQUIPMENT_CONFIG = {
    'MOTOR_001': {'type': 'motor', 'line': 'Line 1', 'temp_range': (45, 75), 'vib_range': (2, 12)},
    'MOTOR_002': {'type': 'motor', 'line': 'Line 1', 'temp_range': (45, 75), 'vib_range': (2, 12)},
    'PUMP_001': {'type': 'pump', 'line': 'Line 1', 'temp_range': (40, 65), 'vib_range': (5, 18), 'pressure': (180, 240)},
    'PUMP_002': {'type': 'pump', 'line': 'Line 2', 'temp_range': (40, 65), 'vib_range': (5, 18), 'pressure': (180, 240)},
    'CONV_001': {'type': 'conveyor', 'line': 'Line 1', 'temp_range': (25, 55), 'vib_range': (1, 8)},
    'CONV_002': {'type': 'conveyor', 'line': 'Line 2', 'temp_range': (25, 55), 'vib_range': (1, 8)},
    'ROBOT_001': {'type': 'robot', 'line': 'Line 1', 'temp_range': (35, 60), 'vib_range': (1, 6)},
    'ROBOT_002': {'type': 'robot', 'line': 'Line 2', 'temp_range': (35, 60), 'vib_range': (1, 6)},
    'COMP_001': {'type': 'compressor', 'line': 'Utility', 'temp_range': (60, 85), 'vib_range': (8, 22), 'pressure': (6, 7.5)},
    'HVAC_001': {'type': 'hvac', 'line': 'Factory Floor', 'temp_range': (18, 24), 'vib_range': (1, 4)}
}

def generate_sensor_data_csv():
    """Generate sensor data CSV file"""
    filename = 'sample_sensor_data.csv'
    
    # Generate data for last 3 days with 5-minute intervals
    end_time = datetime.datetime.now()
    start_time = end_time - datetime.timedelta(days=3)
    current_time = start_time
    
    with open(filename, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        # Write header
        writer.writerow(['time', 'equipment_id', 'sensor_type', 'value', 'unit', 'status'])
        
        record_count = 0
        while current_time <= end_time:
            for equipment_id, config in EQUIPMENT_CONFIG.items():
                hour = current_time.hour
                
                # Operating factor (reduced activity at night/weekends)
                operating_factor = 1.0
                if current_time.weekday() >= 5:  # Weekend
                    operating_factor = 0.3
                elif hour < 6 or hour > 22:  # Night
                    operating_factor = 0.6
                
                # Temperature sensor
                temp_base = (config['temp_range'][0] + config['temp_range'][1]) / 2
                daily_cycle = 3 * math.sin(2 * math.pi * hour / 24)
                temp_variation = (config['temp_range'][1] - config['temp_range'][0]) * 0.3
                temp_value = temp_base + daily_cycle + random.uniform(-temp_variation, temp_variation)
                
                temp_status = 'normal'
                if temp_value > config['temp_range'][1]:
                    temp_status = 'warning'
                if temp_value > config['temp_range'][1] * 1.1:
                    temp_status = 'critical'
                
                writer.writerow([
                    current_time.strftime('%Y-%m-%d %H:%M:%S%z'),
                    equipment_id, 'temperature', round(temp_value, 1), 'celsius', temp_status
                ])
                
                # Vibration sensor
                vib_base = (config['vib_range'][0] + config['vib_range'][1]) / 2
                vib_variation = (config['vib_range'][1] - config['vib_range'][0]) * 0.4
                vib_value = max(0, vib_base * operating_factor + random.uniform(-vib_variation, vib_variation))
                
                vib_status = 'normal'
                if vib_value > config['vib_range'][1]:
                    vib_status = 'warning'
                if vib_value > config['vib_range'][1] * 1.2:
                    vib_status = 'critical'
                
                writer.writerow([
                    current_time.strftime('%Y-%m-%d %H:%M:%S%z'),
                    equipment_id, 'vibration', round(vib_value, 2), 'hz', vib_status
                ])
                
                # Pressure sensor (only for pumps and compressor)
                if 'pressure' in config:
                    pressure_base = (config['pressure'][0] + config['pressure'][1]) / 2
                    pressure_variation = (config['pressure'][1] - config['pressure'][0]) * 0.2
                    pressure_value = pressure_base * operating_factor + random.uniform(-pressure_variation, pressure_variation)
                    
                    pressure_status = 'normal'
                    if pressure_value > config['pressure'][1]:
                        pressure_status = 'warning'
                    
                    writer.writerow([
                        current_time.strftime('%Y-%m-%d %H:%M:%S%z'),
                        equipment_id, 'pressure', round(pressure_value, 1), 'bar', pressure_status
                    ])
                
                record_count += 2  # temp + vibration (+ pressure if applicable)
                if 'pressure' in config:
                    record_count += 1
            
            current_time += datetime.timedelta(minutes=5)
    
    print(f"Generated {filename} with {record_count:,} sensor readings")

def generate_production_metrics_csv():
    """Generate production metrics CSV file"""
    filename = 'sample_production_metrics.csv'
    
    end_time = datetime.datetime.now()
    start_time = end_time - datetime.timedelta(days=3)
    current_time = start_time
    
    lines = ['Line 1', 'Line 2']
    
    with open(filename, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['time', 'line_id', 'equipment_id', 'cycle_time', 'throughput', 
                        'efficiency_score', 'energy_consumption', 'downtime_duration', 'defect_rate'])
        
        record_count = 0
        while current_time <= end_time:
            for line_id in lines:
                # Get equipment for this line
                line_equipment = [eq for eq, config in EQUIPMENT_CONFIG.items() 
                                if config['line'] == line_id]
                
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
                
                for equipment_id in line_equipment:
                    cycle_time = random.uniform(35, 55) * (100 / max(base_efficiency, 50))
                    throughput = base_throughput * random.uniform(0.8, 1.2)
                    efficiency = max(0, min(100, base_efficiency * random.uniform(0.9, 1.1)))
                    
                    energy_base = 8.0 if line_id == 'Line 1' else 7.5
                    energy_consumption = energy_base + (throughput / 100) * 5 + random.uniform(-1, 1)
                    
                    downtime_prob = (100 - efficiency) / 100 * 0.3
                    downtime = random.uniform(0, 15) * downtime_prob if random.random() < downtime_prob else 0
                    
                    defect_rate = max(0, (100 - efficiency) / 10 + random.uniform(-1, 1))
                    
                    writer.writerow([
                        current_time.strftime('%Y-%m-%d %H:%M:%S%z'),
                        line_id, equipment_id, round(cycle_time, 1), round(throughput, 1),
                        round(efficiency, 1), round(energy_consumption, 2),
                        round(downtime, 1), round(defect_rate, 2)
                    ])
                    record_count += 1
            
            current_time += datetime.timedelta(minutes=15)  # 15-minute intervals
    
    print(f"Generated {filename} with {record_count:,} production records")

def generate_quality_control_csv():
    """Generate quality control CSV file"""
    filename = 'sample_quality_control.csv'
    
    end_time = datetime.datetime.now()
    start_time = end_time - datetime.timedelta(days=3)
    current_time = start_time
    
    lines = ['Line 1', 'Line 2']
    products = ['PROD_A001', 'PROD_B002', 'PROD_C003', 'PROD_D004']
    test_types = ['dimensional', 'visual', 'functional', 'electrical']
    inspectors = ['INSP_001', 'INSP_002', 'INSP_003', 'INSP_004']
    
    with open(filename, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['time', 'batch_id', 'line_id', 'product_id', 'test_type',
                        'test_result', 'measurement_value', 'tolerance_min', 'tolerance_max', 'inspector_id'])
        
        record_count = 0
        batch_counter = 1000
        
        while current_time <= end_time:
            # Random intervals for QC tests
            next_test = current_time + datetime.timedelta(minutes=random.randint(60, 180))
            
            if next_test > end_time:
                break
            
            for line_id in lines:
                if random.random() < 0.6:  # 60% chance of test per interval per line
                    batch_id = f"BATCH_{batch_counter:06d}"
                    batch_counter += 1
                    
                    product_id = random.choice(products)
                    test_type = random.choice(test_types)
                    inspector_id = random.choice(inspectors)
                    
                    # 95% pass rate
                    test_result = 'pass' if random.random() < 0.95 else 'fail'
                    
                    # Generate measurements for dimensional and electrical tests
                    measurement_value = None
                    tolerance_min = None
                    tolerance_max = None
                    
                    if test_type == 'dimensional':
                        tolerance_min = 10.0
                        tolerance_max = 10.5
                        if test_result == 'pass':
                            measurement_value = random.uniform(tolerance_min + 0.05, tolerance_max - 0.05)
                        else:
                            if random.random() < 0.5:
                                measurement_value = random.uniform(tolerance_min - 0.2, tolerance_min)
                            else:
                                measurement_value = random.uniform(tolerance_max, tolerance_max + 0.2)
                    elif test_type == 'electrical':
                        tolerance_min = 45.0
                        tolerance_max = 55.0
                        if test_result == 'pass':
                            measurement_value = random.uniform(tolerance_min + 1, tolerance_max - 1)
                        else:
                            if random.random() < 0.5:
                                measurement_value = random.uniform(tolerance_min - 5, tolerance_min)
                            else:
                                measurement_value = random.uniform(tolerance_max, tolerance_max + 5)
                    
                    writer.writerow([
                        next_test.strftime('%Y-%m-%d %H:%M:%S%z'),
                        batch_id, line_id, product_id, test_type, test_result,
                        round(measurement_value, 2) if measurement_value else None,
                        tolerance_min, tolerance_max, inspector_id
                    ])
                    record_count += 1
            
            current_time = next_test
    
    print(f"Generated {filename} with {record_count:,} quality control records")

def generate_maintenance_events_csv():
    """Generate maintenance events CSV file"""
    filename = 'sample_maintenance_events.csv'
    
    end_time = datetime.datetime.now()
    start_time = end_time - datetime.timedelta(days=90)  # 3 months of maintenance history
    
    technicians = ['TECH_001', 'TECH_002', 'TECH_003', 'TECH_004', 'TECH_005']
    
    with open(filename, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['time', 'equipment_id', 'event_type', 'maintenance_type',
                        'duration', 'cost', 'technician_id', 'description', 'parts_replaced'])
        
        record_count = 0
        
        for equipment_id in EQUIPMENT_CONFIG.keys():
            current_time = start_time
            
            # Schedule monthly preventive maintenance
            while current_time <= end_time:
                # Preventive maintenance
                maint_time = current_time + datetime.timedelta(days=random.randint(28, 35))
                if maint_time <= end_time:
                    duration = random.uniform(2, 6)
                    cost = random.uniform(500, 2000)
                    technician = random.choice(technicians)
                    description = f"Scheduled preventive maintenance for {equipment_id}"
                    parts = "{filters,lubricants}" if random.random() < 0.7 else ""
                    
                    writer.writerow([
                        maint_time.strftime('%Y-%m-%d %H:%M:%S%z'),
                        equipment_id, 'scheduled', 'preventive',
                        round(duration, 1), round(cost, 2), technician, description, parts
                    ])
                    record_count += 1
                
                # Random unscheduled maintenance (2% chance per week)
                week_start = current_time
                for week in range(4):  # 4 weeks in a month
                    if random.random() < 0.02:
                        fault_time = week_start + datetime.timedelta(
                            days=random.randint(0, 6), 
                            hours=random.randint(8, 18)
                        )
                        if fault_time <= end_time:
                            duration = random.uniform(1, 8)
                            cost = random.uniform(200, 5000)
                            technician = random.choice(technicians)
                            
                            fault_types = ['bearing failure', 'sensor malfunction', 'electrical issue',
                                         'hydraulic leak', 'belt replacement', 'calibration drift']
                            fault_desc = random.choice(fault_types)
                            description = f"Unscheduled repair: {fault_desc}"
                            
                            parts_options = ["{bearings,seals}", "{sensors,wiring}", "{electrical_components}",
                                           "{hydraulic_seals,hoses}", "{belts,pulleys}", ""]
                            parts = random.choice(parts_options)
                            
                            writer.writerow([
                                fault_time.strftime('%Y-%m-%d %H:%M:%S%z'),
                                equipment_id, 'unscheduled', 'corrective',
                                round(duration, 1), round(cost, 2), technician, description, parts
                            ])
                            record_count += 1
                    
                    week_start += datetime.timedelta(days=7)
                
                current_time = maint_time
    
    print(f"Generated {filename} with {record_count:,} maintenance events")

def create_load_script():
    """Create a SQL script to load the generated CSV files"""
    script_content = """-- Load sample data into Industrial IoT tables
-- Run this script after creating the tables and before running analytics

-- Load sensor data
\\COPY sensor_data FROM 'sample_sensor_data.csv' CSV HEADER;

-- Load production metrics
\\COPY production_metrics FROM 'sample_production_metrics.csv' CSV HEADER;

-- Load quality control data
\\COPY quality_control FROM 'sample_quality_control.csv' CSV HEADER;

-- Load maintenance events
\\COPY maintenance_events FROM 'sample_maintenance_events.csv' CSV HEADER;

-- Verify data load
SELECT 'sensor_data' as table_name, COUNT(*) as record_count FROM sensor_data
UNION ALL
SELECT 'production_metrics', COUNT(*) FROM production_metrics
UNION ALL
SELECT 'quality_control', COUNT(*) FROM quality_control
UNION ALL
SELECT 'maintenance_events', COUNT(*) FROM maintenance_events;

-- Show data time ranges
SELECT 
    'sensor_data' as table_name,
    MIN(time) as earliest,
    MAX(time) as latest,
    COUNT(*) as total_records
FROM sensor_data
UNION ALL
SELECT 
    'production_metrics',
    MIN(time),
    MAX(time),
    COUNT(*)
FROM production_metrics
UNION ALL
SELECT 
    'quality_control',
    MIN(time),
    MAX(time),
    COUNT(*)
FROM quality_control
UNION ALL
SELECT 
    'maintenance_events',
    MIN(time),
    MAX(time),
    COUNT(*)
FROM maintenance_events;
"""
    
    with open('load_sample_data.sql', 'w') as f:
        f.write(script_content)
    
    print("Generated load_sample_data.sql script")

def main():
    """Generate all sample data files"""
    print("=== Industrial IoT Sample Data Generator ===")
    print("Generating CSV files for TimescaleDB workshop...")
    
    generate_sensor_data_csv()
    generate_production_metrics_csv()
    generate_quality_control_csv()
    generate_maintenance_events_csv()
    create_load_script()
    
    print("\n=== Generation Complete ===")
    print("Generated files:")
    print("  - sample_sensor_data.csv")
    print("  - sample_production_metrics.csv") 
    print("  - sample_quality_control.csv")
    print("  - sample_maintenance_events.csv")
    print("  - load_sample_data.sql")
    print("\nTo load the data:")
    print("1. Create the database tables using analyze-industrial-iot-data.sql")
    print("2. Run: psql -d 'your_connection_string' -f load_sample_data.sql")

if __name__ == "__main__":
    main()
