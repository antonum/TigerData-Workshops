-- ============================================================================
-- # Simple Industrial IoT Data Analysis with TimescaleDB
-- ============================================================================
--
-- This simplified workshop demonstrates TimescaleDB basics for Industrial IoT
-- using just two tables:
-- 1. One hypertable for sensor data (time-series)
-- 2. One regular table for equipment information (reference data)
--
-- Key concepts covered:
-- - Creating hypertables for time-series data
-- - Joining hypertables with regular tables
-- - Time-bucketed aggregations
-- - Compression for storage optimization
-- - Continuous aggregates for real-time analytics
--
-- ============================================================================
-- ## Prerequisites
-- ============================================================================
-- 1. Create a Timescale Cloud service: https://console.cloud.timescale.com/signup
-- 2. Connect using: psql -d "your_connection_string"
-- 3. Run this script step by step

-- ============================================================================
-- ## Setup Tables
-- ============================================================================

-- Drop existing tables
DROP TABLE IF EXISTS sensor_readings CASCADE;
DROP TABLE IF EXISTS equipment CASCADE;

-- Create equipment reference table (regular PostgreSQL table)
CREATE TABLE equipment (
    equipment_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,           -- motor, pump, conveyor, etc.
    location TEXT NOT NULL,       -- factory location
    max_temperature NUMERIC       -- alert threshold in celsius
);

-- Create sensor readings hypertable (time-series data)
CREATE TABLE sensor_readings (
    time TIMESTAMPTZ NOT NULL,
    equipment_id TEXT NOT NULL,
    temperature NUMERIC NOT NULL,
    vibration NUMERIC NOT NULL,
    status TEXT DEFAULT 'normal'  -- normal, warning, critical
);

-- Convert to hypertable partitioned by time
SELECT create_hypertable('sensor_readings', by_range('time'));

-- ============================================================================
-- ## Load Reference Data
-- ============================================================================

INSERT INTO equipment VALUES
('MOTOR_001', 'Assembly Line Motor A', 'motor', 'Factory Floor A', 75),
('MOTOR_002', 'Assembly Line Motor B', 'motor', 'Factory Floor A', 75),
('PUMP_001', 'Hydraulic Pump 1', 'pump', 'Factory Floor B', 70),
('PUMP_002', 'Hydraulic Pump 2', 'pump', 'Factory Floor B', 70),
('CONV_001', 'Main Conveyor Belt', 'conveyor', 'Factory Floor A', 60),
('ROBOT_001', 'Assembly Robot', 'robot', 'Factory Floor A', 65);

-- ============================================================================
-- ## Create Indexes
-- ============================================================================

CREATE INDEX ON equipment (type);
CREATE INDEX ON equipment (location);
CREATE INDEX ON sensor_readings (equipment_id, time);
CREATE INDEX ON sensor_readings (status, time) WHERE status != 'normal';

-- ============================================================================
-- ## Generate Sample Data 
-- ============================================================================
-- Run the Python script to generate realistic sensor data:
-- python3 generate_simple_data.py

-- ============================================================================
-- ## Load Sample Data 
-- ============================================================================
\COPY sensor_readings FROM 'sensor_data.csv' CSV HEADER;
-- ============================================================================
-- ## Preview Data
-- ============================================================================

-- Show equipment information
SELECT * FROM equipment ORDER BY equipment_id;

-- Show recent sensor readings
SELECT 
    time,
    equipment_id,
    temperature,
    vibration,
    status
FROM sensor_readings 
ORDER BY time DESC 
LIMIT 10;

-- ============================================================================
-- ## Basic Analytics
-- ============================================================================

-- Enable timing to see query performance
\timing on

-- 1. Current equipment status
SELECT 
    sr.equipment_id,
    e.name,
    e.location,
    sr.temperature,
    sr.vibration,
    sr.status,
    sr.time as last_reading
FROM sensor_readings sr
JOIN equipment e ON sr.equipment_id = e.equipment_id
WHERE sr.time >= NOW() - INTERVAL '1 hour'
ORDER BY sr.time DESC;

-- 2. Equipment with alerts in last 24 hours
SELECT 
    sr.equipment_id,
    e.name,
    e.type,
    COUNT(*) as alert_count,
    AVG(sr.temperature) as avg_temp,
    MAX(sr.temperature) as max_temp,
    e.max_temperature as threshold
FROM sensor_readings sr
JOIN equipment e ON sr.equipment_id = e.equipment_id
WHERE sr.status IN ('warning', 'critical')
  AND sr.time >= NOW() - INTERVAL '24 hours'
GROUP BY sr.equipment_id, e.name, e.type, e.max_temperature
ORDER BY alert_count DESC;

-- 3. Hourly temperature averages by equipment type
SELECT
    time_bucket('1 hour', sr.time) AS hour,
    e.type,
    AVG(sr.temperature) as avg_temperature,
    AVG(sr.vibration) as avg_vibration,
    COUNT(*) as reading_count
FROM sensor_readings sr
JOIN equipment e ON sr.equipment_id = e.equipment_id
WHERE sr.time >= NOW() - INTERVAL '24 hours'
GROUP BY hour, e.type
ORDER BY hour DESC, e.type;

-- 4. Equipment running hot (above 80% of threshold)
SELECT 
    sr.equipment_id,
    e.name,
    e.max_temperature as threshold,
    AVG(sr.temperature) as avg_temp,
    MAX(sr.temperature) as max_temp,
    COUNT(*) as readings
FROM sensor_readings sr
JOIN equipment e ON sr.equipment_id = e.equipment_id
WHERE sr.time >= NOW() - INTERVAL '24 hours'
GROUP BY sr.equipment_id, e.name, e.max_temperature
HAVING AVG(sr.temperature) > e.max_temperature * 0.8
ORDER BY avg_temp DESC;

-- ============================================================================
-- ## Examine Hypertable Structure
-- ============================================================================

-- View hypertable details
\d+ sensor_readings

-- Check chunks (data partitions)
SELECT 
    chunk_name, 
    range_start, 
    range_end, 
    is_compressed 
FROM timescaledb_information.chunks
WHERE hypertable_name = 'sensor_readings';

-- ============================================================================
-- ## Enable Compression
-- ============================================================================

-- Configure compression settings
ALTER TABLE sensor_readings 
SET (
    timescaledb.enable_columnstore = true,
    timescaledb.segmentby = 'equipment_id',
    timescaledb.compress_orderby = 'time DESC'
);

-- Compress existing chunks
SELECT compress_chunk(c, true) FROM show_chunks('sensor_readings') c;

-- Set up automatic compression policy (compress data older than 1 day)
CALL add_columnstore_policy('sensor_readings', after => INTERVAL '1 day');

-- ============================================================================
-- ## Check Compression Benefits
-- ============================================================================

SELECT 
    pg_size_pretty(before_compression_total_bytes) AS before_compression,
    pg_size_pretty(after_compression_total_bytes) AS after_compression,
    ROUND(
        (before_compression_total_bytes - after_compression_total_bytes) * 100.0 / 
        before_compression_total_bytes, 
        1
    ) as compression_ratio_percent
FROM hypertable_compression_stats('sensor_readings');

-- ============================================================================
-- ## Run Same Query on Compressed Data
-- ============================================================================

-- This query should run faster on compressed data
SELECT
    time_bucket('1 hour', sr.time) AS hour,
    e.type,
    AVG(sr.temperature) as avg_temperature,
    AVG(sr.vibration) as avg_vibration,
    COUNT(*) as reading_count
FROM sensor_readings sr
JOIN equipment e ON sr.equipment_id = e.equipment_id
WHERE sr.time >= NOW() - INTERVAL '7 days'
GROUP BY hour, e.type
ORDER BY hour DESC, e.type
LIMIT 20;

-- ============================================================================
-- ## Create Continuous Aggregate
-- ============================================================================

-- Create real-time equipment monitoring view
CREATE MATERIALIZED VIEW equipment_hourly_stats
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    equipment_id,
    AVG(temperature) as avg_temperature,
    MIN(temperature) as min_temperature,
    MAX(temperature) as max_temperature,
    AVG(vibration) as avg_vibration,
    COUNT(*) as reading_count,
    COUNT(*) FILTER (WHERE status != 'normal') as alert_count
FROM sensor_readings
GROUP BY bucket, equipment_id;

-- Add refresh policy for the continuous aggregate
SELECT add_continuous_aggregate_policy('equipment_hourly_stats',
    start_offset => INTERVAL '2 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');

-- ============================================================================
-- ## Query Continuous Aggregate
-- ============================================================================

-- Fast queries using pre-aggregated data
SELECT 
    ehs.bucket,
    e.name,
    e.type,
    ehs.avg_temperature,
    ehs.max_temperature,
    ehs.alert_count,
    e.max_temperature as threshold
FROM equipment_hourly_stats ehs
JOIN equipment e ON ehs.equipment_id = e.equipment_id
WHERE ehs.bucket >= NOW() - INTERVAL '24 hours'
  AND ehs.max_temperature > e.max_temperature * 0.8  -- Above 80% of threshold
ORDER BY ehs.bucket DESC, ehs.avg_temperature DESC;

-- ============================================================================
-- ## Advanced Analytics
-- ============================================================================

-- 1. Equipment temperature trends (increasing/decreasing)
WITH temp_trends AS (
    SELECT 
        equipment_id,
        AVG(avg_temperature) FILTER (WHERE bucket >= NOW() - INTERVAL '4 hours') as recent_avg,
        AVG(avg_temperature) FILTER (WHERE bucket >= NOW() - INTERVAL '8 hours' 
                                     AND bucket < NOW() - INTERVAL '4 hours') as previous_avg
    FROM equipment_hourly_stats
    WHERE bucket >= NOW() - INTERVAL '8 hours'
    GROUP BY equipment_id
)
SELECT 
    tt.equipment_id,
    e.name,
    e.type,
    ROUND(tt.previous_avg::numeric, 1) as previous_4hr_avg,
    ROUND(tt.recent_avg::numeric, 1) as recent_4hr_avg,
    ROUND(((tt.recent_avg - tt.previous_avg) / tt.previous_avg * 100)::numeric, 1) as percent_change
FROM temp_trends tt
JOIN equipment e ON tt.equipment_id = e.equipment_id
WHERE tt.recent_avg IS NOT NULL AND tt.previous_avg IS NOT NULL
ORDER BY percent_change DESC;

-- 2. Daily equipment utilization (based on reading frequency)
SELECT
    time_bucket('1 day', bucket) AS day,
    equipment_id,
    SUM(reading_count) as total_readings,
    AVG(avg_temperature) as daily_avg_temp,
    SUM(alert_count) as daily_alerts
FROM equipment_hourly_stats
WHERE bucket >= NOW() - INTERVAL '7 days'
GROUP BY day, equipment_id
ORDER BY day DESC, equipment_id;

-- ============================================================================
-- ## Real-time Data Insert Test
-- ============================================================================

-- Insert new sensor reading to test real-time continuous aggregates
INSERT INTO sensor_readings (time, equipment_id, temperature, vibration, status)
VALUES (NOW(), 'MOTOR_001', 78.5, 12.3, 'warning');

-- Check if it appears in the continuous aggregate (real-time feature)
SELECT 
    bucket,
    equipment_id,
    avg_temperature,
    alert_count
FROM equipment_hourly_stats
WHERE equipment_id = 'MOTOR_001'
  AND bucket >= date_trunc('hour', NOW())
ORDER BY bucket DESC;

-- ============================================================================
-- ## Summary
-- ============================================================================

-- Data volume summary
SELECT 
    'sensor_readings' as table_name,
    COUNT(*) as total_records,
    MIN(time) as earliest_reading,
    MAX(time) as latest_reading
FROM sensor_readings
UNION ALL
SELECT 
    'equipment' as table_name,
    COUNT(*) as total_records,
    NULL::timestamptz as earliest_reading,
    NULL::timestamptz as latest_reading
FROM equipment;

-- Equipment summary with latest status
SELECT 
    e.equipment_id,
    e.name,
    e.type,
    e.location,
    sr_latest.temperature as current_temp,
    sr_latest.status as current_status,
    sr_latest.time as last_reading
FROM equipment e
LEFT JOIN LATERAL (
    SELECT temperature, status, time
    FROM sensor_readings sr
    WHERE sr.equipment_id = e.equipment_id
    ORDER BY time DESC
    LIMIT 1
) sr_latest ON true
ORDER BY e.equipment_id;

-- ============================================================================
-- ## Next Steps
-- ============================================================================
-- This simple workshop demonstrates:
-- ✅ Hypertables for time-series data
-- ✅ Joining time-series with reference data
-- ✅ Time-bucketed aggregations
-- ✅ Columnar compression (90%+ storage savings)
-- ✅ Continuous aggregates for real-time analytics
-- ✅ Performance optimization with indexes
--
-- To extend this workshop:
-- 1. Add more sensor types (pressure, humidity)
-- 2. Create alerting rules based on thresholds
-- 3. Build dashboards with Grafana
-- 4. Add data retention policies
-- 5. Implement machine learning for predictive maintenance
