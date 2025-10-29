# Timeseries Workshop - IoT Data Analysis

## Overview

The Internet of Things (IoT) describes a trend where computing capabilities are embedded into IoT devices. That is, physical objects, ranging from light bulbs to oil wells. Many IoT devices collect sensor data about their environment and generate time-series datasets with relational metadata.

It is often necessary to simulate IoT datasets. For example, when you are testing a new system. This tutorial shows how to simulate a basic dataset in your Tiger Cloud service, and then run simple queries on it.

## What You'll Learn

- **Hypertables**: Convert regular PostgreSQL tables into time-series optimized hypertables

- **Real-time IoT Sensor Data**: Work with actual manifacturing line IoT devices/sensor data

- **Metadata Analysis**: Combine the timeseries sensor data with a device reference meta data via joins to create useful visualization

- **Columnar Compression**: Achieve 10x storage reduction while improving query performance

- **Continuous Aggregates**: Pre-compute aggregations for lightning-fast analytics

- **Real-time Updates**: Build materialized views that update automatically as new data arrives


## Contents

- **`analyze-financial-data-psql.sql`**: Complete workshop for psql command-line interface

## Prerequisites

- Create a target TigerData Cloud service with time-series and analytics enabled (at <https://console.cloud.timescale.com/signup>)

- You need your connection details like: "postgres://tsdbadmin:xxxxxxx.yyyyy.tsdb.cloud.timescale.com:39966/tsdb?sslmode=require"

## Data StructureThe workshop uses two main datasets:

## Standard PostgreSQL heap reference (meta data)table for relational data:

```sql
CREATE TABLE sensors(
  id SERIAL PRIMARY KEY,
  type VARCHAR(50),
  location VARCHAR(50)
);
```

### Hypertable to store the real-time sensor data

```sql
CREATE TABLE sensor_data (
  time TIMESTAMPTZ NOT NULL,
  sensor_id INTEGER,
  temperature DOUBLE PRECISION,
  cpu DOUBLE PRECISION,
  FOREIGN KEY (sensor_id) REFERENCES sensors (id)
) WITH (
   tsdb.hypertable,
   tsdb.partition_column='time',
   tsdb.segmentby = 'sensor_id',
   tsdb.orderby = 'time DESC'
);
```
