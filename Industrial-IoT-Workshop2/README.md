# Simple Industrial IoT Workshop

A simplified TimescaleDB workshop demonstrating core concepts with just two tables:
- **One hypertable**: `sensor_readings` (time-series data)
- **One regular table**: `equipment` (reference data)

## What You'll Learn

- ✅ Create hypertables for time-series data
- ✅ Join time-series data with reference tables  
- ✅ Use time-bucketed aggregations
- ✅ Enable compression for storage savings
- ✅ Create continuous aggregates for real-time analytics
- ✅ Query optimization with proper indexing

## Quick Start

### 1. Setup Database
```bash
# Connect to your TimescaleDB instance
psql -d "your_connection_string"

# Create tables and load sample data
\i analyze-simple-iot-data.sql
```

### 2. Generate Sample Data
```bash
# Generate realistic sensor data (no dependencies required)
python3 generate_simple_data.py

# Load the data
psql -d "your_connection_string" -f load_data.sql
```

### 3. Run Analytics
Open `analyze-simple-iot-data.sql` and run the queries step by step to explore:
- Real-time equipment monitoring
- Temperature trend analysis
- Alert detection and reporting
- Performance optimization with compression

## Data Schema

### Equipment Table (Reference Data)
```sql
equipment_id | name                   | type     | location        | max_temperature
MOTOR_001   | Assembly Line Motor A  | motor    | Factory Floor A | 75
PUMP_001    | Hydraulic Pump 1       | pump     | Factory Floor B | 70
```

### Sensor Readings Table (Time-Series Data)
```sql
time                     | equipment_id | temperature | vibration | status
2025-07-09 10:30:00+00  | MOTOR_001    | 68.5        | 8.2       | normal
2025-07-09 10:32:00+00  | MOTOR_001    | 72.1        | 9.5       | warning
```

## Sample Analytics

### Current Equipment Status
```sql
SELECT 
    sr.equipment_id,
    e.name,
    sr.temperature,
    sr.status,
    sr.time as last_reading
FROM sensor_readings sr
JOIN equipment e ON sr.equipment_id = e.equipment_id
WHERE sr.time >= NOW() - INTERVAL '1 hour'
ORDER BY sr.time DESC;
```

### Hourly Temperature Trends
```sql
SELECT
    time_bucket('1 hour', time) AS hour,
    equipment_id,
    AVG(temperature) as avg_temp,
    MAX(temperature) as max_temp,
    COUNT(*) as readings
FROM sensor_readings
WHERE time >= NOW() - INTERVAL '24 hours'
GROUP BY hour, equipment_id
ORDER BY hour DESC;
```

## Key Features Demonstrated

### 1. Hypertable Creation
```sql
SELECT create_hypertable('sensor_readings', by_range('time'));
```

### 2. Compression (90%+ storage savings)
```sql
ALTER TABLE sensor_readings 
SET (timescaledb.enable_columnstore = true);
```

### 3. Continuous Aggregates (Real-time dashboards)
```sql
CREATE MATERIALIZED VIEW equipment_hourly_stats
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    equipment_id,
    AVG(temperature) as avg_temperature,
    COUNT(*) FILTER (WHERE status != 'normal') as alert_count
FROM sensor_readings
GROUP BY bucket, equipment_id;
```

## Data Volume

The sample generator creates:
- **6 equipment pieces** (motors, pumps, conveyor, robot)
- **3 days** of historical data
- **2-minute intervals** (realistic for IoT sensors)
- **~13,000 sensor readings** total
- **Realistic patterns**: daily cycles, weekend/night variations, occasional spikes

## Benefits Shown

1. **High Performance**: Fast queries on large time-series datasets
2. **Storage Efficiency**: 90%+ compression ratios
3. **Real-time Analytics**: Continuous aggregates update automatically
4. **SQL Compatibility**: Standard PostgreSQL interface
5. **Operational Simplicity**: Automated compression and maintenance

## Next Steps

After completing this workshop:
1. **Scale Up**: Add more equipment and longer time periods
2. **Add Sensors**: Include pressure, humidity, energy consumption
3. **Build Dashboards**: Connect to Grafana or other visualization tools
4. **Implement Alerts**: Set up real-time notifications
5. **Add ML**: Use predictive analytics for maintenance scheduling

## Files

- `analyze-simple-iot-data.sql` - Main workshop script with all queries
- `generate_simple_data.py` - Data generator (no dependencies)
- `README.md` - This documentation

## Support

- [TimescaleDB Documentation](https://docs.timescale.com/)
- [Community Slack](https://timescaledb.slack.com/)
- [Tutorials](https://docs.timescale.com/tutorials/latest/)
