-- Install requires extensions vector, vectorscale, and ai
CREATE EXTENSION IF NOT EXISTS vector CASCADE;
CREATE EXTENSION IF NOT EXISTS vectorscale CASCADE;
CREATE EXTENSION IF NOT EXISTS ai CASCADE;


DROP TABLE IF EXISTS vector_test CASCADE;
-- Create a table with a vector(3) field
CREATE TABLE vector_test (
    id SERIAL PRIMARY KEY,
    description TEXT,
    embedding vector(3)  -- 3-dimensional vector
);

-- Insert 10 rows of test data with 3-dimensional vectors
INSERT INTO vector_test (description, embedding) VALUES
    ('Red color vector', '[1.0, 0.0, 0.0]'),
    ('Green color vector', '[0.0, 1.0, 0.0]'),
    ('Blue color vector', '[0.0, 0.0, 1.0]'),
    ('Yellow color vector', '[1.0, 1.0, 0.0]'),
    ('Magenta color vector', '[1.0, 0.0, 1.0]'),
    ('Cyan color vector', '[0.0, 1.0, 1.0]'),
    ('White color vector', '[1.0, 1.0, 1.0]'),
    ('Black color vector', '[0.0, 0.0, 0.0]'),
    ('Light gray color vector', '[0.5, 0.5, 0.5]'),
    ('Orange color vector', '[1.0, 0.5, 0.0]');

-- Query to verify the data was inserted correctly
SELECT id, description, embedding FROM vector_test;

-- Example of a vector similarity search (finding colors similar to red)
SELECT 
    id, 
    description, 
    embedding, 
    embedding <=> '[1.0, 0.0, 0.0]' AS distance
FROM 
    vector_test
ORDER BY 
    embedding <=> '[1.0, 0.0, 0.0]'
LIMIT 5;

CREATE INDEX idx_diskann ON vector_test USING diskann (embedding vector_cosine_ops);

-- DROP INDEX idx_diskann;

WITH target_vector AS (
    SELECT embedding from vector_test WHERE description LIKE '%Red%' LIMIT 1
)
SELECT 
    id, 
    description, 
    embedding, 
    embedding <=> (SELECT embedding FROM target_vector) AS distance
FROM 
    vector_test
-- WHERE description NOT LIKE '%Red%'
ORDER BY 
    embedding <=> (SELECT embedding FROM target_vector) 
LIMIT 5;