-- ============================================================================
-- # Analyze Industrial IoT Manufacturing Data
-- ============================================================================
--
-- This workshop demonstrates how to use TimescaleDB for Industrial IoT and 
-- manufacturing use cases. Manufacturing environments generate massive amounts 
-- of time-series data from sensors, machines, production lines, and quality 
-- control systems. TimescaleDB simplifies management of these large volumes of 
-- data while providing meaningful analytical insights for predictive maintenance,
-- quality control, and operational efficiency.
--
-- In this tutorial, you'll work with real-time sensor data from manufacturing 
-- equipment, create aggregated views for machine performance monitoring, 
-- implement predictive maintenance alerts, and analyze production efficiency.
--
-- Key use cases covered:
-- - Machine sensor monitoring (temperature, vibration, pressure)
-- - Production line efficiency tracking
-- - Quality control metrics
-- - Predictive maintenance analytics
-- - Energy consumption optimization
--
-- ============================================================================
-- ## Prerequisites
-- ============================================================================
-- To follow the steps on this page:
--
-- 1. Create a target Timescale Cloud service with time-series and analytics enabled.
--    https://console.cloud.timescale.com/signup
--
-- 2. You need your connection details like: 
--    "postgres://tsdbadmin:xxxxxxx.yyyyy.tsdb.cloud.timescale.com:39966/tsdb?sslmode=require"
--
-- 3. using psql cli connect to your Timescale Cloud service:
--    psql -d "postgres://tsdbadmin:xxxxxxx.yyyyy.tsdb.cloud.timescale.com:39966/tsdb?sslmode=require"
--
-- ============================================================================
-- ## About Industrial IoT Data
-- ============================================================================
-- Industrial IoT generates several types of time-series data:
-- 
-- 1. Sensor Data: Temperature, pressure, vibration, humidity from equipment
-- 2. Production Metrics: Throughput, cycle times, quality scores
-- 3. Energy Data: Power consumption, efficiency metrics
-- 4. Maintenance Data: Equipment status, fault codes, maintenance schedules
-- 5. Environmental Data: Ambient conditions affecting production

-- ============================================================================
-- ## Setup
-- ============================================================================

-- Drop tables and associated objects
DROP TABLE IF EXISTS sensor_data CASCADE;
DROP TABLE IF EXISTS production_metrics CASCADE;
DROP TABLE IF EXISTS equipment_registry CASCADE;
DROP TABLE IF EXISTS maintenance_events CASCADE;
DROP TABLE IF EXISTS quality_control CASCADE;

-- Create equipment registry table (reference data)
CREATE TABLE equipment_registry (
    equipment_id TEXT PRIMARY KEY,
    equipment_name TEXT NOT NULL,
    equipment_type TEXT NOT NULL, -- motor, pump, conveyor, robot, etc.
    location TEXT NOT NULL,       -- factory floor, line number
    manufacturer TEXT,
    model TEXT,
    install_date DATE,
    max_temp NUMERIC,            -- operating thresholds
    max_pressure NUMERIC,
    max_vibration NUMERIC
);

-- Create sensor data hypertable (high-frequency IoT data)
CREATE TABLE sensor_data (
    "time" TIMESTAMPTZ NOT NULL,
    equipment_id TEXT NOT NULL,
    sensor_type TEXT NOT NULL,   -- temperature, vibration, pressure, humidity
    value NUMERIC NOT NULL,
    unit TEXT NOT NULL,          -- celsius, bar, hz, percent
    status TEXT DEFAULT 'normal' -- normal, warning, critical
);

-- Convert to hypertable partitioned by time
SELECT create_hypertable('sensor_data', by_range('time'));

-- Create production metrics hypertable
CREATE TABLE production_metrics (
    "time" TIMESTAMPTZ NOT NULL,
    line_id TEXT NOT NULL,
    equipment_id TEXT,
    cycle_time NUMERIC,          -- seconds per unit
    throughput NUMERIC,          -- units per hour
    efficiency_score NUMERIC,    -- 0-100%
    energy_consumption NUMERIC,  -- kWh
    downtime_duration NUMERIC,   -- minutes
    defect_rate NUMERIC         -- percentage
);

-- Convert to hypertable
SELECT create_hypertable('production_metrics', by_range('time'));

-- Create quality control table
CREATE TABLE quality_control (
    "time" TIMESTAMPTZ NOT NULL,
    batch_id TEXT NOT NULL,
    line_id TEXT NOT NULL,
    product_id TEXT,
    test_type TEXT NOT NULL,     -- dimensional, visual, functional
    test_result TEXT NOT NULL,   -- pass, fail
    measurement_value NUMERIC,
    tolerance_min NUMERIC,
    tolerance_max NUMERIC,
    inspector_id TEXT
);

-- Convert to hypertable
SELECT create_hypertable('quality_control', by_range('time'));

-- Create maintenance events table
CREATE TABLE maintenance_events (
    "time" TIMESTAMPTZ NOT NULL,
    equipment_id TEXT NOT NULL,
    event_type TEXT NOT NULL,    -- scheduled, unscheduled, emergency
    maintenance_type TEXT,       -- preventive, corrective, predictive
    duration NUMERIC,            -- hours
    cost NUMERIC,
    technician_id TEXT,
    description TEXT,
    parts_replaced TEXT[]
);

-- Convert to hypertable
SELECT create_hypertable('maintenance_events', by_range('time'));

-- ============================================================================
-- ## Load Reference Data
-- ============================================================================
-- Insert sample equipment registry data

INSERT INTO equipment_registry VALUES
('MOTOR_001', 'Main Drive Motor A1', 'motor', 'Line 1', 'Siemens', 'IE3-100L', '2020-01-15', 80, NULL, 15),
('MOTOR_002', 'Main Drive Motor A2', 'motor', 'Line 1', 'Siemens', 'IE3-100L', '2020-01-15', 80, NULL, 15),
('PUMP_001', 'Hydraulic Pump B1', 'pump', 'Line 1', 'Bosch Rexroth', 'A10VSO', '2019-06-10', 70, 250, 20),
('PUMP_002', 'Hydraulic Pump B2', 'pump', 'Line 2', 'Bosch Rexroth', 'A10VSO', '2019-06-10', 70, 250, 20),
('CONV_001', 'Conveyor Belt C1', 'conveyor', 'Line 1', 'FlexLink', 'X45', '2021-03-20', 60, NULL, 10),
('CONV_002', 'Conveyor Belt C2', 'conveyor', 'Line 2', 'FlexLink', 'X45', '2021-03-20', 60, NULL, 10),
('ROBOT_001', 'Assembly Robot D1', 'robot', 'Line 1', 'KUKA', 'KR 6 R700', '2022-08-01', 65, NULL, 8),
('ROBOT_002', 'Welding Robot D2', 'robot', 'Line 2', 'ABB', 'IRB 1400', '2022-08-01', 65, NULL, 8),
('COMP_001', 'Air Compressor E1', 'compressor', 'Utility', 'Atlas Copco', 'GA 37', '2018-12-05', 90, 8, 25),
('HVAC_001', 'HVAC Unit F1', 'hvac', 'Factory Floor', 'Carrier', '30HXC', '2019-04-12', 25, NULL, 5);

-- ============================================================================
-- ## Create Indexes for Performance
-- ============================================================================

CREATE INDEX ON equipment_registry (equipment_type);
CREATE INDEX ON equipment_registry (location);

CREATE INDEX ON sensor_data (equipment_id, time);
CREATE INDEX ON sensor_data (sensor_type, time);
CREATE INDEX ON sensor_data (status, time) WHERE status != 'normal';

CREATE INDEX ON production_metrics (line_id, time);
CREATE INDEX ON production_metrics (equipment_id, time);

CREATE INDEX ON quality_control (line_id, time);
CREATE INDEX ON quality_control (test_result, time) WHERE test_result = 'fail';

CREATE INDEX ON maintenance_events (equipment_id, time);
CREATE INDEX ON maintenance_events (event_type, time);

-- ============================================================================
-- ## Generate Sample Data
-- ============================================================================
-- Note: Run the Python script 'generate_iot_data.py' to populate the tables
-- with realistic time-series data. The script will generate:
-- - 7 days of sensor data (1-minute intervals)
-- - Production metrics (5-minute intervals)
-- - Quality control records (random intervals)
-- - Maintenance events (scheduled and unscheduled)

-- ============================================================================
-- ## Preview Data
-- ============================================================================

-- Preview sensor data
SELECT 
    time,
    equipment_id,
    sensor_type,
    value,
    unit,
    status
FROM sensor_data 
ORDER BY time DESC 
LIMIT 10;

-- Preview production metrics
SELECT 
    time,
    line_id,
    equipment_id,
    cycle_time,
    throughput,
    efficiency_score,
    energy_consumption
FROM production_metrics 
ORDER BY time DESC 
LIMIT 10;

-- Preview equipment registry
SELECT * FROM equipment_registry LIMIT 10;

-- ============================================================================
-- ## Examine Hypertable Details
-- ============================================================================

\d+ sensor_data

-- Check hypertable chunks
SELECT 
    chunk_name, 
    range_start, 
    range_end, 
    is_compressed 
FROM timescaledb_information.chunks
WHERE hypertable_name = 'sensor_data';

-- ============================================================================
-- ## Basic Analytics Queries
-- ============================================================================

-- Enable timing to compare performance
\timing on

-- 1. Equipment with temperature warnings in last 24 hours
SELECT 
    s.equipment_id,
    e.equipment_name,
    e.location,
    COUNT(*) as warning_count,
    AVG(s.value) as avg_temp,
    MAX(s.value) as max_temp
FROM sensor_data s
JOIN equipment_registry e ON s.equipment_id = e.equipment_id
WHERE s.sensor_type = 'temperature' 
  AND s.status IN ('warning', 'critical')
  AND s.time >= NOW() - INTERVAL '24 hours'
GROUP BY s.equipment_id, e.equipment_name, e.location
ORDER BY warning_count DESC;

-- 2. Production efficiency by line over last week
SELECT
    time_bucket('1 hour', time) AS bucket,
    line_id,
    AVG(efficiency_score) as avg_efficiency,
    SUM(throughput) as total_throughput,
    SUM(energy_consumption) as total_energy
FROM production_metrics
WHERE time >= NOW() - INTERVAL '7 days'
GROUP BY bucket, line_id
ORDER BY bucket DESC, line_id;

-- 3. Quality control failure rate by product line
SELECT
    time_bucket('1 day', time) AS day,
    line_id,
    COUNT(*) as total_tests,
    COUNT(*) FILTER (WHERE test_result = 'fail') as failures,
    ROUND(
        COUNT(*) FILTER (WHERE test_result = 'fail') * 100.0 / COUNT(*), 
        2
    ) as failure_rate_percent
FROM quality_control
WHERE time >= NOW() - INTERVAL '30 days'
GROUP BY day, line_id
ORDER BY day DESC, line_id;

-- ============================================================================
-- ## Enable Columnarstore (Compression)
-- ============================================================================

-- Configure compression for sensor data (highest volume)
ALTER TABLE sensor_data 
SET (
    timescaledb.enable_columnstore = true,
    timescaledb.segmentby = 'equipment_id, sensor_type',
    timescaledb.compress_orderby = 'time DESC'
);

-- Configure compression for production metrics
ALTER TABLE production_metrics 
SET (
    timescaledb.enable_columnstore = true,
    timescaledb.segmentby = 'line_id',
    timescaledb.compress_orderby = 'time DESC'
);

-- Manually compress existing chunks
SELECT compress_chunk(c, true) FROM show_chunks('sensor_data') c;
SELECT compress_chunk(c, true) FROM show_chunks('production_metrics') c;

-- Set up automatic compression policies
CALL add_columnstore_policy('sensor_data', after => INTERVAL '1 day');
CALL add_columnstore_policy('production_metrics', after => INTERVAL '1 day');

-- ============================================================================
-- ## Check Compression Savings
-- ============================================================================

SELECT 
    'sensor_data' as table_name,
    pg_size_pretty(before_compression_total_bytes) AS before,
    pg_size_pretty(after_compression_total_bytes) AS after,
    ROUND(
        (before_compression_total_bytes - after_compression_total_bytes) * 100.0 / 
        before_compression_total_bytes, 
        1
    ) as compression_ratio_percent
FROM hypertable_compression_stats('sensor_data')
UNION ALL
SELECT 
    'production_metrics' as table_name,
    pg_size_pretty(before_compression_total_bytes) AS before,
    pg_size_pretty(after_compression_total_bytes) AS after,
    ROUND(
        (before_compression_total_bytes - after_compression_total_bytes) * 100.0 / 
        before_compression_total_bytes, 
        1
    ) as compression_ratio_percent
FROM hypertable_compression_stats('production_metrics');

-- ============================================================================
-- ## Create Continuous Aggregates for Common Analytics
-- ============================================================================

-- 1. Hourly equipment health summary
CREATE MATERIALIZED VIEW equipment_health_hourly
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    equipment_id,
    sensor_type,
    AVG(value) as avg_value,
    MIN(value) as min_value,
    MAX(value) as max_value,
    COUNT(*) FILTER (WHERE status != 'normal') as alert_count,
    COUNT(*) as total_readings
FROM sensor_data
GROUP BY bucket, equipment_id, sensor_type;

-- 2. Daily production summary by line
CREATE MATERIALIZED VIEW production_summary_daily
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 day', time) AS bucket,
    line_id,
    AVG(efficiency_score) as avg_efficiency,
    SUM(throughput) as total_throughput,
    SUM(energy_consumption) as total_energy,
    SUM(downtime_duration) as total_downtime,
    AVG(defect_rate) as avg_defect_rate
FROM production_metrics
GROUP BY bucket, line_id;

-- 3. Daily quality metrics
CREATE MATERIALIZED VIEW quality_summary_daily
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 day', time) AS bucket,
    line_id,
    test_type,
    COUNT(*) as total_tests,
    COUNT(*) FILTER (WHERE test_result = 'fail') as failed_tests,
    ROUND(
        COUNT(*) FILTER (WHERE test_result = 'fail') * 100.0 / COUNT(*), 
        2
    ) as failure_rate_percent
FROM quality_control
GROUP BY bucket, line_id, test_type;

-- Add continuous aggregate policies
SELECT add_continuous_aggregate_policy('equipment_health_hourly',
    start_offset => INTERVAL '3 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');

SELECT add_continuous_aggregate_policy('production_summary_daily',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day');

SELECT add_continuous_aggregate_policy('quality_summary_daily',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day');

-- ============================================================================
-- ## Advanced Analytics - Predictive Maintenance
-- ============================================================================

-- Identify equipment showing degradation patterns
-- (Rising temperature + increasing vibration)
WITH equipment_trends AS (
    SELECT 
        equipment_id,
        sensor_type,
        AVG(value) FILTER (WHERE time >= NOW() - INTERVAL '7 days') as recent_avg,
        AVG(value) FILTER (WHERE time >= NOW() - INTERVAL '14 days' 
                          AND time < NOW() - INTERVAL '7 days') as previous_avg
    FROM sensor_data
    WHERE sensor_type IN ('temperature', 'vibration')
      AND time >= NOW() - INTERVAL '14 days'
    GROUP BY equipment_id, sensor_type
)
SELECT 
    et.equipment_id,
    e.equipment_name,
    e.location,
    et.sensor_type,
    ROUND(et.previous_avg::numeric, 2) as previous_week_avg,
    ROUND(et.recent_avg::numeric, 2) as recent_week_avg,
    ROUND(((et.recent_avg - et.previous_avg) / et.previous_avg * 100)::numeric, 2) as percent_change
FROM equipment_trends et
JOIN equipment_registry e ON et.equipment_id = e.equipment_id
WHERE et.recent_avg > et.previous_avg * 1.1  -- 10% increase threshold
ORDER BY percent_change DESC;

-- ============================================================================
-- ## Energy Efficiency Analysis
-- ============================================================================

-- Equipment energy consumption vs production output
SELECT
    time_bucket('1 day', p.time) AS day,
    p.line_id,
    SUM(p.throughput) as total_production,
    SUM(p.energy_consumption) as total_energy,
    ROUND(
        (SUM(p.energy_consumption) / NULLIF(SUM(p.throughput), 0))::numeric, 
        3
    ) as energy_per_unit
FROM production_metrics p
WHERE p.time >= NOW() - INTERVAL '30 days'
GROUP BY day, p.line_id
ORDER BY day DESC, p.line_id;

-- ============================================================================
-- ## Real-time Alerting Queries
-- ============================================================================

-- Current equipment in critical state
SELECT 
    s.equipment_id,
    e.equipment_name,
    e.location,
    s.sensor_type,
    s.value,
    s.unit,
    s.time as last_reading,
    CASE 
        WHEN s.sensor_type = 'temperature' THEN e.max_temp
        WHEN s.sensor_type = 'pressure' THEN e.max_pressure
        WHEN s.sensor_type = 'vibration' THEN e.max_vibration
    END as threshold
FROM sensor_data s
JOIN equipment_registry e ON s.equipment_id = e.equipment_id
WHERE s.status = 'critical'
  AND s.time >= NOW() - INTERVAL '1 hour'
ORDER BY s.time DESC;

-- Production lines with efficiency below 80% in last 4 hours
SELECT
    time_bucket('1 hour', time) AS hour,
    line_id,
    AVG(efficiency_score) as avg_efficiency,
    MIN(efficiency_score) as min_efficiency
FROM production_metrics
WHERE time >= NOW() - INTERVAL '4 hours'
GROUP BY hour, line_id
HAVING AVG(efficiency_score) < 80
ORDER BY hour DESC, avg_efficiency ASC;

-- ============================================================================
-- ## Query Continuous Aggregates
-- ============================================================================

-- Equipment health trends from continuous aggregate
SELECT 
    bucket,
    equipment_id,
    sensor_type,
    avg_value,
    alert_count,
    total_readings
FROM equipment_health_hourly
WHERE equipment_id = 'MOTOR_001'
  AND bucket >= NOW() - INTERVAL '24 hours'
ORDER BY bucket DESC, sensor_type;

-- Production efficiency trends
SELECT 
    bucket,
    line_id,
    avg_efficiency,
    total_throughput,
    total_energy,
    total_downtime
FROM production_summary_daily
WHERE bucket >= NOW() - INTERVAL '7 days'
ORDER BY bucket DESC, line_id;

-- ============================================================================
-- ## Maintenance Optimization
-- ============================================================================

-- Calculate mean time between failures (MTBF) for equipment
WITH failure_events AS (
    SELECT 
        equipment_id,
        time,
        LAG(time) OVER (PARTITION BY equipment_id ORDER BY time) as prev_failure
    FROM maintenance_events
    WHERE event_type = 'unscheduled'
      AND time >= NOW() - INTERVAL '1 year'
),
mtbf_calc AS (
    SELECT 
        equipment_id,
        EXTRACT(EPOCH FROM (time - prev_failure))/3600 as hours_between_failures
    FROM failure_events
    WHERE prev_failure IS NOT NULL
)
SELECT 
    m.equipment_id,
    e.equipment_name,
    e.equipment_type,
    COUNT(m.hours_between_failures) as failure_count,
    ROUND(AVG(m.hours_between_failures)::numeric, 1) as avg_mtbf_hours,
    ROUND((AVG(m.hours_between_failures)/24)::numeric, 1) as avg_mtbf_days
FROM mtbf_calc m
JOIN equipment_registry e ON m.equipment_id = e.equipment_id
GROUP BY m.equipment_id, e.equipment_name, e.equipment_type
HAVING COUNT(m.hours_between_failures) > 1
ORDER BY avg_mtbf_hours ASC;

-- ============================================================================
-- ## Test Real-time Updates
-- ============================================================================

-- Insert new sensor reading to test real-time continuous aggregates
INSERT INTO sensor_data (time, equipment_id, sensor_type, value, unit, status)
VALUES (NOW(), 'MOTOR_001', 'temperature', 85.5, 'celsius', 'warning');

-- Insert new production metric
INSERT INTO production_metrics (time, line_id, equipment_id, cycle_time, throughput, efficiency_score, energy_consumption)
VALUES (NOW(), 'Line 1', 'MOTOR_001', 45.2, 78, 92.5, 12.3);

-- Verify real-time updates in continuous aggregates
SELECT 
    bucket,
    equipment_id,
    sensor_type,
    avg_value,
    alert_count
FROM equipment_health_hourly
WHERE equipment_id = 'MOTOR_001'
  AND sensor_type = 'temperature'
  AND bucket >= date_trunc('hour', NOW())
ORDER BY bucket DESC;

-- ============================================================================
-- ## Performance Summary
-- ============================================================================
-- TimescaleDB provides significant benefits for Industrial IoT:
-- 1. High-frequency sensor data ingestion (millions of readings/hour)
-- 2. Automatic compression reduces storage costs by 90%+
-- 3. Continuous aggregates provide real-time dashboards
-- 4. Advanced time-series functions for predictive analytics
-- 5. Standard SQL interface for easy integration
-- 6. Automatic data retention policies for regulatory compliance
