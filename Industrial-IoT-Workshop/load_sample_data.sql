-- Load sample data into Industrial IoT tables
-- Run this script after creating the tables and before running analytics

-- Load sensor data
\COPY sensor_data FROM 'sample_sensor_data.csv' CSV HEADER;

-- Load production metrics
\COPY production_metrics FROM 'sample_production_metrics.csv' CSV HEADER;

-- Load quality control data
\COPY quality_control FROM 'sample_quality_control.csv' CSV HEADER;

-- Load maintenance events
\COPY maintenance_events FROM 'sample_maintenance_events.csv' CSV HEADER;

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
