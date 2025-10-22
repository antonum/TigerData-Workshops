# TimeSeries Workshop - Biowearables

## Overview

This workshop demonstrates advanced time-series data analysis using PostgreSQL and TigerData for Biowearables. 
eg track health metrics from wearable devices including:

- Heart Rate (BPM)
- Blood Pressure (Systolic/Diastolic)
- Blood Oxygen Saturation (SpO2)
- Body Temperature
- Steps Count
- Sleep Quality Score

Use case: Remote patient monitoring, fitness tracking, and health analytics


## What You'll Learn

- **Hypertables**: Convert regular PostgreSQL tables into time-series optimized hypertables

- **Working with Bioweareables Data**: Work with sample generated bioweareables data

- **Daily Health Analysis**: Generate daily health summaries & other queries

- **Columnar Compression**: Achieve 10x storage reduction while improving query performance

- **Continuous Aggregates**: Pre-compute aggregations for lightning-fast analytics

- **Real-time Updates**: Build materialized views that update automatically as new data arrives

## Contents

- **`analyze-financial-data-psql.sql`**: Complete workshop for psql command-line interface

- **`analyze-financial-data-UI.sql`**: Workshop version optimized for Timescale Cloud Console UI

## Prerequisites

- Timescale Cloud account (get free 30 days at <https://console.cloud.timescale.com/signup>)

- Optional, but recommended - install psql CLI https://www.tigerdata.com/blog/how-to-install-psql-on-mac-ubuntu-debian-windows

- Basic knowledge of SQL and relational data concepts

## Data Structure

### Health Data Table

```sql
CREATE TABLE health_data (
   time TIMESTAMPTZ NOT NULL,
   device_id INTEGER,
   heart_rate INTEGER,  -- BPM
   blood_pressure_systolic INTEGER,  -- mmHg
   blood_pressure_diastolic INTEGER,  -- mmHg
   spo2 DOUBLE PRECISION,  -- Blood oxygen saturation %
   body_temperature DOUBLE PRECISION,  -- Celsius
   steps_count INTEGER,  -- Daily cumulative steps
   sleep_quality_score DOUBLE PRECISION,  -- 0-100 scale
   activity_level TEXT  -- sedentary, light, moderate, vigorous
) WITH (
   tsdb.hypertable,
   tsdb.partition_column='time',
   tsdb.segmentby='device_id',
   tsdb.orderby='time DESC'
);

```

### Users Table

```sql
CREATE TABLE users(
   id SERIAL PRIMARY KEY,
   name VARCHAR(100), 
   age INTEGER,
   gender VARCHAR(10),
   medical_conditions TEXT
);
```

### Wearable Devices Table

```sql
CREATE TABLE wearable_devices(
   id SERIAL PRIMARY KEY,
   user_id INTEGER,
   device_type VARCHAR(50),  -- smartwatch, fitness_band, patch, ring
   device_model VARCHAR(100),
   firmware_version VARCHAR(20)
);

```

## Key Features Demonstrated

### 1. Hypertable Creation
### 2. Data Generation
### 3. Columnar Compression 
### 4. Real Time Continuous Aggregates

## Getting Started

### Using psql Command Line

1. Follow the instructions in `analyze-financial-data-psql.sql`

2. The script will automatically download sample data and guide you through each step

3. Includes timing comparisons to demonstrate performance improvements

## Workshop Highlights

- **Real Data**: Uses 
- **Performance Optimization**: Compare query times before and after compression
- **Storage Efficiency**: See 10x storage reduction with columnar compression
- **Automatic Updates**: Demonstrate real-time continuous aggregate updates
- **Production Ready**: Learn policies for automatic compression and aggregate refreshing

## Performance Benefits

- **Hypertables**: Automatic partitioning for optimal time-series queries
- **Columnar Storage**: 90% storage reduction with faster analytical queries
- **Continuous Aggregates**: Sub-second response times for complex aggregations
- **Automatic Policies**: Set-and-forget data lifecycle management

## License
