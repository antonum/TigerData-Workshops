# Industrial IoT Manufacturing Workshop

This workshop demonstrates how to use TimescaleDB for Industrial IoT and manufacturing use cases. Manufacturing environments generate massive amounts of time-series data from sensors, machines, production lines, and quality control systems.

## Workshop Overview

Learn how to:
- Set up hypertables for high-frequency sensor data
- Implement real-time monitoring and alerting
- Create continuous aggregates for production dashboards
- Analyze equipment performance and predict maintenance needs
- Optimize energy consumption and production efficiency
- Track quality control metrics and trends

## Use Cases Covered

1. **Machine Sensor Monitoring**
   - Temperature, vibration, and pressure sensors
   - Real-time status monitoring (normal/warning/critical)
   - Threshold-based alerting

2. **Production Line Efficiency**
   - Cycle time and throughput tracking
   - Energy consumption monitoring
   - Downtime analysis and root cause identification

3. **Quality Control Analytics**
   - Dimensional and functional testing
   - Defect rate trending
   - Batch quality tracking

4. **Predictive Maintenance**
   - Equipment degradation pattern detection
   - Mean Time Between Failures (MTBF) calculation
   - Maintenance cost optimization

## Files in This Workshop

### Core Workshop Files
- `analyze-industrial-iot-data.sql` - Main SQL workshop script with comprehensive examples
- `generate_iot_data.py` - Full-featured Python data generator (requires psycopg2, numpy, pandas)
- `generate_sample_data.py` - Simple data generator using only Python standard library
- `README.md` - This documentation

### Data Schema

The workshop uses four main hypertables:

1. **sensor_data** - High-frequency IoT sensor readings
   - Equipment temperature, vibration, pressure, humidity
   - 1-minute intervals with status indicators

2. **production_metrics** - Production line performance data
   - Cycle times, throughput, efficiency scores
   - Energy consumption and downtime tracking

3. **quality_control** - Product quality test results
   - Dimensional, visual, functional, and electrical tests
   - Pass/fail results with tolerance measurements

4. **maintenance_events** - Equipment maintenance history
   - Scheduled preventive and unscheduled corrective maintenance
   - Cost tracking and parts replacement logs

## Getting Started

### Prerequisites

1. **TimescaleDB Instance**
   - Create a Timescale Cloud service: https://console.cloud.timescale.com/signup
   - Enable time-series and analytics features
   - Note your connection string

2. **Database Client**
   - `psql` command-line tool
   - Or any PostgreSQL-compatible database client

3. **Python Environment** (for data generation)
   - Python 3.7+ 
   - Optional: `pip install psycopg2-binary numpy pandas` for full generator

### Quick Start

1. **Set up the database schema:**
   ```bash
   psql -d "your_connection_string" -f analyze-industrial-iot-data.sql
   ```

2. **Generate sample data:**
   ```bash
   # Option A: Simple generator (no dependencies)
   python generate_sample_data.py
   psql -d "your_connection_string" -f load_sample_data.sql
   
   # Option B: Full generator (requires packages)
   # Update CONNECTION_STRING in generate_iot_data.py
   python generate_iot_data.py
   ```

3. **Run the analytics queries:**
   - Open `analyze-industrial-iot-data.sql` in your SQL client
   - Execute sections step-by-step to explore the data
   - Observe query performance with and without compression

## Key Features Demonstrated

### 1. Hypertable Setup and Indexing
```sql
-- Convert regular table to hypertable
SELECT create_hypertable('sensor_data', by_range('time'));

-- Create performance indexes
CREATE INDEX ON sensor_data (equipment_id, time);
CREATE INDEX ON sensor_data (status, time) WHERE status != 'normal';
```

### 2. Columnar Compression
```sql
-- Enable compression with segmentation
ALTER TABLE sensor_data 
SET (
    timescaledb.enable_columnstore = true,
    timescaledb.segmentby = 'equipment_id, sensor_type',
    timescaledb.compress_orderby = 'time DESC'
);

-- Automatic compression policy
CALL add_columnstore_policy('sensor_data', after => INTERVAL '1 day');
```

### 3. Continuous Aggregates
```sql
-- Real-time equipment health monitoring
CREATE MATERIALIZED VIEW equipment_health_hourly
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    equipment_id,
    sensor_type,
    AVG(value) as avg_value,
    COUNT(*) FILTER (WHERE status != 'normal') as alert_count
FROM sensor_data
GROUP BY bucket, equipment_id, sensor_type;
```

### 4. Predictive Analytics
```sql
-- Detect equipment degradation patterns
WITH equipment_trends AS (
    SELECT 
        equipment_id,
        AVG(value) FILTER (WHERE time >= NOW() - INTERVAL '7 days') as recent_avg,
        AVG(value) FILTER (WHERE time >= NOW() - INTERVAL '14 days' 
                          AND time < NOW() - INTERVAL '7 days') as previous_avg
    FROM sensor_data
    WHERE sensor_type = 'temperature'
    GROUP BY equipment_id
)
SELECT 
    equipment_id,
    ((recent_avg - previous_avg) / previous_avg * 100) as percent_change
FROM equipment_trends
WHERE recent_avg > previous_avg * 1.1;
```

## Sample Queries and Analysis

The workshop includes comprehensive examples for:

- **Real-time Monitoring**: Current equipment status and alerts
- **Production Efficiency**: Line performance and energy analysis  
- **Quality Trends**: Defect rates and test result patterns
- **Maintenance Optimization**: MTBF calculation and cost analysis
- **Energy Analytics**: Consumption per unit and efficiency metrics

## Performance Benefits

TimescaleDB provides significant advantages for Industrial IoT:

1. **High Ingestion Rates**: Handle millions of sensor readings per hour
2. **Storage Efficiency**: 90%+ compression ratios for time-series data
3. **Query Performance**: Fast analytics on compressed data
4. **Real-time Aggregates**: Continuous aggregates for live dashboards
5. **SQL Compatibility**: Standard PostgreSQL interface and ecosystem
6. **Operational Simplicity**: Automated compression and data retention

## Next Steps

After completing this workshop:

1. **Extend the Schema**: Add more sensor types or production metrics
2. **Build Dashboards**: Connect to Grafana, Tableau, or other visualization tools
3. **Implement Alerting**: Set up real-time notifications for critical conditions
4. **Add Machine Learning**: Use pgvector or external ML pipelines for advanced analytics
5. **Scale Up**: Test with higher data volumes and more equipment

## Resources

- [TimescaleDB Documentation](https://docs.timescale.com/)
- [Industrial IoT Best Practices](https://docs.timescale.com/use-cases/latest/industrial-iot/)
- [Time-Series Analytics Guide](https://docs.timescale.com/tutorials/latest/)
- [Continuous Aggregates Tutorial](https://docs.timescale.com/getting-started/latest/create-cagg/)

## Support

For questions about this workshop:
- TimescaleDB Community: https://timescaledb.slack.com/
- Documentation: https://docs.timescale.com/
- GitHub Issues: https://github.com/timescale/timescaledb
