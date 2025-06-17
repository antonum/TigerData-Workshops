-- # Clear Timescale Tables
DROP TABLE IF EXISTS ev_maintenance_reports CASCADE;
DROP TABLE IF EXISTS ev_charging_stations CASCADE;

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

-- Import ev_charging_stations data
\COPY ev_charging_stations(id, station_name, station_code, longitude, latitude) FROM 'ev_charging_stations.csv' WITH (FORMAT CSV, HEADER, DELIMITER ',');

-- Import ev_maintenance_reports data
\COPY ev_maintenance_reports(id, station_code, date, description, status) FROM 'ev_maintenance_reports.csv' WITH (FORMAT CSV, HEADER, DELIMITER ',');

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

-- Check the status of the vectorizer
-- Wait for pending_items = 0
SELECT * FROM ai.vectorizer_status;

-- ev_reports_embeddings is a view that will be created automatically by ai.create_vectorizer
-- It might take few minutes to fully populate the view
SELECT count(*) FROM ev_reports_embeddings;

--Generate single embedding
SELECT ai.openai_embed('text-embedding-3-small', 'snow-related event', dimensions=>1536);


-- Ask a question to OpenAI using pgAI
SELECT ai.openai_chat_complete(
  'gpt-4o',
  jsonb_build_array(
    jsonb_build_object(
      'role', 'system',
      'content', 'You are a helpful assistant.'
    ),
    jsonb_build_object(
      'role', 'user',
      'content', 'What are the top 3 benefits of electric vehicles?'
    )
  )
)->'choices'->0->'message'->>'content';


-- Semantic search using vector distance
SELECT
    station_code, date, description, 
    embedding <=> ai.openai_embed(
        'text-embedding-3-small',
        'heat-related event', -- your RAG query
        dimensions => 1536
    ) AS vector_distance
FROM
    ev_reports_embeddings
ORDER BY
    vector_distance
LIMIT 10;


-- RAG query to summarize maintenance reports related to snow
-- This query retrieves the top 10 maintenance reports related to snow and summarizes them using OpenAI's GPT-4o model.
-- It uses the vector distance to find the most relevant reports based on their embeddings.
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

-- Finding stations within 15 miles from a given point
-- Query for stations within 10 miles of JFK Airport
-- JFK coordinates: approximately -73.80, 40.641 
SELECT 
    id,
    station_name,
    station_code,
    longitude,
    latitude,
    -- Calculate the distance in miles directly from coordinates
    ST_Distance(
        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
        ST_SetSRID(ST_MakePoint(-73.80, 40.641), 4326)::geography
    ) / 1609.34 AS distance_miles
FROM 
    ev_charging_stations
WHERE 
    ST_DWithin(
        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
        ST_SetSRID(ST_MakePoint(-73.79, 40.641), 4326)::geography,
        15 * 1609.34  -- Convert 15 miles to meters (1 mile = 1609.34 meters)
    )
ORDER BY 
    distance_miles;

------------------------
--- FINAL RESULTS ------
------------------------

WITH stations_near_airport as (
-- Filter charging stations within 15 miles of JFK Airport
SELECT 
    station_code,
    ST_Distance(
        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
        ST_SetSRID(ST_MakePoint(-73.79, 40.641), 4326)::geography
    ) / 1609.34 AS distance_miles
FROM 
    ev_charging_stations
WHERE 
    ST_DWithin(
        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
        ST_SetSRID(ST_MakePoint(-73.79, 40.641), 4326)::geography,
        15 * 1609.34  -- Convert 15 miles to meters (1 mile = 1609.34 meters)
    )
),
x AS (    
-- Semantic Search/Vector query, filtered by date and stations identified on a previos step
SELECT 
    id, description AS report,
    embedding <=> ai.openai_embed(
        'text-embedding-3-small',
        'snow-related issues', -- Semantic query to identify relevant context
        dimensions => 1536
    ) AS distance
FROM 
    ev_reports_embeddings
    WHERE date BETWEEN '2024-01-01' AND '2024-01-31' -- Filter by date range
    AND station_code IN (SELECT station_code FROM stations_near_airport) -- Filter by stations near the airport
ORDER BY distance
LIMIT 10
)
-- Finally, let's ask LLM to summarize the reports
SELECT 
    ai.openai_chat_complete(
        'gpt-4o',
        jsonb_build_array(
            jsonb_build_object('role', 'system','content', 'you are a helpful assistant'),
            jsonb_build_object(
                'role', 'user', 
                'content', concat(
                    E'Summarize the maintanance reports in one paragraph' -- LLM instructions
                    ,string_agg(x.report, E'\n')) -- Concatenate all reports into one string for LLM input
            )
        )
    )->'choices'->0->'message'->>'content' AS summary
    --,string_agg(x.report, E'\n') AS raw_descriptions
FROM x;
