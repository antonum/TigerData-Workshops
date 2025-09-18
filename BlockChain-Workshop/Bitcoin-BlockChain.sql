-----------------------------------
-- # Bitcoin Blockchain analysis --
-----------------------------------

-- In this workshop you would load and analyze small subset of Bitcoin Blockchain data
-- Between 6th and 13th June 2025

---------------------------------
-- Drop existing tables if any --
---------------------------------

DROP TABLE IF EXISTS blocks;
DROP TABLE IF EXISTS tx_vinout CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;

-------------------------------
-- Bitcoin Blockchain Schema --
-------------------------------

CREATE TABLE IF NOT EXISTS blocks (
    height BIGINT,
    timestamp TIMESTAMPTZ,
    hash TEXT,
    value NUMERIC,
    fee NUMERIC,
    ntx INTEGER,
    PRIMARY KEY (height)
);

CREATE INDEX ON blocks(hash);

CREATE TABLE IF NOT EXISTS transactions  (
    txid TEXT,
    timestamp TIMESTAMPTZ,
    block_height BIGINT,
    value NUMERIC,
    fee NUMERIC,
    coinbase BOOLEAN,
    txid_2 TEXT,
    txid_3 TEXT,
    PRIMARY KEY (txid, timestamp)
) WITH (
   tsdb.hypertable,
   tsdb.partition_column='timestamp',
   timescaledb.enable_columnstore, 
   tsdb.orderby = 'timestamp ASC',
   tsdb.segmentby='txid_2'
);

CREATE INDEX ON transactions (block_height);
CREATE INDEX ON transactions (txid);

CREATE TABLE IF NOT EXISTS tx_vinout (
    timestamp TIMESTAMPTZ,
    type TEXT,
    address TEXT,
    value NUMERIC,
    txid TEXT,
    n INTEGER,
    coinbase BOOLEAN,   
    block_height BIGINT,
    address_2 TEXT,
    address_3 TEXT,
    PRIMARY KEY (txid, type, n, timestamp)
) WITH (
   tsdb.hypertable,
   tsdb.partition_column='timestamp',
   timescaledb.enable_columnstore, 
   tsdb.orderby = 'timestamp DESC',
   tsdb.segmentby='address_2'
);
CREATE INDEX ON tx_vinout(address, timestamp);
CREATE INDEX ON tx_vinout(txid, timestamp);


----------------------------------
-- Load Bitcoin Blockchain data --
----------------------------------
\! wget https://timescale-demo-data.s3.us-east-1.amazonaws.com/900000_900999_blocks.csv.gz
\! wget https://timescale-demo-data.s3.us-east-1.amazonaws.com/900000_900999_transactions.csv.gz
\! wget https://timescale-demo-data.s3.us-east-1.amazonaws.com/900000_900999_tx_vinout.csv.gz

\COPY blocks FROM PROGRAM 'gunzip -c 900000_900999_blocks.csv.gz' WITH (FORMAT CSV, HEADER);
\COPY transactions FROM PROGRAM 'gunzip -c 900000_900999_transactions.csv.gz' WITH (FORMAT CSV, HEADER);
\COPY tx_vinout FROM PROGRAM 'gunzip -c 900000_900999_tx_vinout.csv.gz' WITH (FORMAT CSV, HEADER);

------------------------------
-- Basic Blockchain Queries --
------------------------------   

-- You can verify the results on block explorer:
-- https://blockexplorer.one/bitcoin/mainnet/blockId/900500

-- Get all transactions in block 900500
SELECT * 
FROM transactions 
WHERE block_height = 900500;

-- Get details of the third transaction in block 900500
-- https://blockexplorer.one/bitcoin/mainnet/tx/53473c9303a02b559929a3fcca84ec7cd20c0931cda482c36f7dfc4fb8144e3f
SELECT * 
FROM transactions 
WHERE txid = '53473c9303a02b559929a3fcca84ec7cd20c0931cda482c36f7dfc4fb8144e3f';

-- Get all inputs and outputs for transaction with txid '53473c9303a02b559929a3fcca84ec7cd20c0931cda482c36f7dfc4fb8144e3f'

SELECT type, address, value 
FROM tx_vinout 
WHERE txid = '53473c9303a02b559929a3fcca84ec7cd20c0931cda482c36f7dfc4fb8144e3f';

-- Balance for the specific address 'bc1qjjcn46tmuf3wnpe987u5lpkkgwgv9pc82f6n2gcq7al6d8dyguxs3svvhy'
-- Note: since you are working with only small part of the entire blockchain, this is not the real balance of that address
SELECT sum(value), count(*)
FROM tx_vinout 
WHERE address = 'bc1qjjcn46tmuf3wnpe987u5lpkkgwgv9pc82f6n2gcq7al6d8dyguxs3svvhy';

-- all transactions for the address 'bc1qjjcn46tmuf3wnpe987u5lpkkgwgv9pc82f6n2gcq7al6d8dyguxs3svvhy'
SELECT *
FROM tx_vinout 
WHERE address = 'bc1qjjcn46tmuf3wnpe987u5lpkkgwgv9pc82f6n2gcq7al6d8dyguxs3svvhy'
ORDER BY timestamp DESC
LIMIT 10;
    
---------------------------------
-- Advanced Blockchain Queries --
---------------------------------   

--Where did the bitcoin go from that address?
WITH transactions_out AS (
SELECT distinct txid, timestamp
FROM tx_vinout 
WHERE address = 'bc1qjjcn46tmuf3wnpe987u5lpkkgwgv9pc82f6n2gcq7al6d8dyguxs3svvhy'
    AND type = 'vin'
 ORDER BY timestamp
) 
SELECT address, timestamp, value
FROM tx_vinout
WHERE 
   (txid, timestamp) IN (SELECT txid, timestamp FROM transactions_out)
   AND type = 'vout'; 

-- Trace miner of block 900000
WITH block AS (
    SELECT timestamp 
    FROM blocks 
    WHERE height = 900000
)
SELECT address, value 
FROM tx_vinout 
WHERE block_height = 900000
    AND timestamp = (SELECT timestamp FROM block)
    AND coinbase = True; --look for coinbase transaction

-- How much miner of block 900000 made?
SELECT SUM(value), COUNT(*) 
FROM tx_vinout 
WHERE address = '1PuJjnF476W3zXfVYmJfGnouzFDAXakkL4' -- miner address
    AND coinbase = True;

-- Where the miner sends funds?
WITH transactions_out AS (
SELECT distinct txid, timestamp
FROM tx_vinout 
WHERE address = '1PuJjnF476W3zXfVYmJfGnouzFDAXakkL4'
    AND type = 'vin'
ORDER BY timestamp
) 
select address, count(*), SUM(value)
from tx_vinout
where 
   (txid, timestamp) IN (select txid, timestamp from transactions_out)
   and type = 'vout'
GROUP BY address; -- limit 2;