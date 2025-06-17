# Timescale AI Workshop

## Overview

This repository contains materials for the Timescale AI Workshop, which demonstrates how to integrate PostgreSQL with AI capabilities for managing and analyzing EV charging station data. The workshop showcases the power of TimescaleDB, PostGIS, and AI extensions to build intelligent applications for time-series and geospatial data.

## Contents

- **Data Files**:
  - `ev_charging_stations.csv`: Contains information about charging station locations including coordinates
  - `ev_maintenance_reports.csv`: Contains maintenance records for EV charging stations

- **SQL Scripts**:
  - `vector.sql`: Example scripts for working with vector embeddings
  - `pgai.sql`: Example scripts for working with PgAI extension. Semantic/Vector search and RAG in SQL

## Prerequisites

- PostgreSQL 15+ with the following extensions:
  - TimescaleDB
  - PostGIS
  - vector (for vector similarity search)
  - vectorscale (for scalable vector operations)
  - ai (for OpenAI integration)

Get free 30 days Timescale cloud at https://console.cloud.timescale.com/signup

## Getting Started

1. **Set up the database**:
```sql
   CREATE EXTENSION IF NOT EXISTS vector CASCADE;
   CREATE EXTENSION IF NOT EXISTS vectorscale CASCADE;
   CREATE EXTENSION IF NOT EXISTS ai CASCADE;
   CREATE EXTENSION IF NOT EXISTS postgis;
```

2. **Create tables and import data**:

```sql
-- EV Charging Stations and Maintenance Reports Schema
CREATE TABLE ev_charging_stations (
    id INTEGER PRIMARY KEY,
    station_name TEXT,
    station_code TEXT,
    longitude FLOAT,
    latitude FLOAT
);

CREATE TABLE ev_maintenance_reports (
    id INTEGER PRIMARY KEY,
    station_code TEXT NOT NULL,
    date DATE NOT NULL,
    description TEXT,
    status TEXT
);

```

3. **Create vectorizer**:


```sql
-- Create Vectorizer for Description Column of ev_maintenance_reports table
SELECT ai.create_vectorizer(
    -- Name of the table with text data to vectorize
   'ev_maintenance_reports'::regclass,
    -- Name of the vectorizer's destination view
   destination => 'ev_reports_embeddings',
   -- Embedding model to use (OpenAI, Bedrock, Gemini, etc.)
   embedding => ai.embedding_openai('text-embedding-3-small', 1536),
   -- Create index after 500 rows are inserted
   indexing => ai.indexing_diskann(min_rows => 500, create_when_queue_empty => false),
   -- Chunking/splitting strategy for text data
   chunking => ai.chunking_recursive_character_text_splitter('description')
);
```

## Workshop Examples

### Vector Similarity Search

Test vector operations with a simple RGB color example:

```sql
CREATE TABLE vector_test (
    id SERIAL PRIMARY KEY,
    description TEXT,
    embedding vector(3)
);

-- Populate with test data
INSERT INTO vector_test (description, embedding) VALUES
    ('Red color vector', '[1.0, 0.0, 0.0]'),
    ('Green color vector', '[0.0, 1.0, 0.0]'),
    -- additional colors...
```

### Retrieval-Augmented Generation (RAG)

Combine vector search with AI to generate maintenance summaries:

```sql
WITH x as (    
    SELECT 
        id, description AS report,
        embedding <=> ai.openai_embed(
            'text-embedding-3-small',
            'snow-related issues', -- Semantic query to identify relevant context
            dimensions => 1536
        ) AS distance
    FROM 
        ev_reports_embeddings
    -- WHERE date BETWEEN '2024-01-01' AND '2024-01-31' -- Filter by date range
    ORDER BY distance
    LIMIT 10
)
SELECT 
    ai.openai_chat_complete(
        'gpt-4o',
        jsonb_build_array(
            jsonb_build_object('role', 'system','content', 'you are a helpful assistant'),
            jsonb_build_object(
                'role', 'user', 
                'content', concat(
                    E'Summarize the maintanance reports in one paragraph' -- LLM instructions
                    ,string_agg(x.report, E'\n'))
            )
        )
    )->'choices'->0->'message'->>'content' AS summary
    --,string_agg(x.report, E'\n') AS raw_descriptions
FROM x;
```

## License

MIT License

## Acknowledgments

This workshop was created by Anton Umnikov/Timescale.
