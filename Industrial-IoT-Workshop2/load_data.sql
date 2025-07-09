-- Load sensor data into TimescaleDB
-- Run this after creating the tables in analyze-simple-iot-data.sql

\echo 'Loading sensor data...'
\COPY sensor_readings FROM 'sensor_data.csv' CSV HEADER;

-- Verify data load
\echo 'Data load verification:'
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

\echo 'Sample data:'
SELECT 
    time,
    equipment_id,
    temperature,
    vibration,
    status
FROM sensor_readings 
ORDER BY time DESC 
LIMIT 10;

\echo 'Status distribution:'
SELECT 
    status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as percentage
FROM sensor_readings 
GROUP BY status 
ORDER BY count DESC;
