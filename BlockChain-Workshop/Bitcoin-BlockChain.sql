/*
======================================
    BITCOIN BLOCKCHAIN ANALYSIS
======================================

In this workshop you will load and analyze a small subset of Bitcoin Blockchain data
between blocks 900,000 and 900,999 (June 6-13, 2025)
*/


-- ==========================================
-- DROP EXISTING TABLES IF ANY
-- ==========================================

DROP TABLE IF EXISTS blocks;
DROP TABLE IF EXISTS tx_vinout CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;

-- ==========================================
-- BITCOIN BLOCKCHAIN SCHEMA
-- ==========================================

-- Blocks table: stores blockchain block information
CREATE TABLE IF NOT EXISTS blocks (
    height       BIGINT,        -- Block height (number)
    timestamp    TIMESTAMPTZ,   -- Block timestamp
    hash         TEXT,          -- Block hash
    value        NUMERIC,       -- Total value in block
    fee          NUMERIC,       -- Total fees in block
    ntx          INTEGER,       -- Number of transactions
    PRIMARY KEY (height)
);

-- Index on block hash for faster lookups
CREATE INDEX ON blocks(hash);

-- Transactions table: stores individual transaction data (hypertable)
CREATE TABLE IF NOT EXISTS transactions (
    txid         TEXT,          -- Transaction ID
    timestamp    TIMESTAMPTZ,   -- Transaction timestamp
    block_height BIGINT,        -- Block height where transaction is included
    value        NUMERIC,       -- Transaction value
    fee          NUMERIC,       -- Transaction fee
    coinbase     BOOLEAN,       -- Is this a coinbase transaction?
    txid_2       TEXT,          -- Additional txid field for segmenting
    txid_3       TEXT,          -- Additional txid field
    PRIMARY KEY (txid, timestamp)
) WITH (
    tsdb.hypertable,
    tsdb.partition_column = 'timestamp',
    timescaledb.enable_columnstore,
    tsdb.orderby = 'timestamp ASC',
    tsdb.segmentby = 'txid_2'
);

-- Indexes for faster queries
CREATE INDEX ON transactions (block_height);
CREATE INDEX ON transactions (txid);

-- Transaction inputs/outputs table: stores detailed transaction I/O data (hypertable)
CREATE TABLE IF NOT EXISTS tx_vinout (
    timestamp    TIMESTAMPTZ,   -- Transaction timestamp
    type         TEXT,          -- 'vin' (input) or 'vout' (output)
    address      TEXT,          -- Bitcoin address
    value        NUMERIC,       -- Value transferred
    txid         TEXT,          -- Transaction ID
    n            INTEGER,       -- Input/output index
    coinbase     BOOLEAN,       -- Is this from a coinbase transaction?
    block_height BIGINT,        -- Block height
    address_2    TEXT,          -- Additional address field for segmenting
    address_3    TEXT,          -- Additional address field
    PRIMARY KEY (txid, type, n, timestamp)
) WITH (
    tsdb.hypertable,
    tsdb.partition_column = 'timestamp',
    timescaledb.enable_columnstore,
    tsdb.orderby = 'timestamp DESC',
    tsdb.segmentby = 'address_2'
);

-- Indexes for faster address and transaction lookups
CREATE INDEX ON tx_vinout(address, timestamp);
CREATE INDEX ON tx_vinout(txid, timestamp);


-- ==========================================
-- LOAD BITCOIN BLOCKCHAIN DATA
-- ==========================================

-- Download compressed CSV files containing blockchain data
\! wget https://timescale-demo-data.s3.us-east-1.amazonaws.com/900000_900999_blocks.csv.gz
\! wget https://timescale-demo-data.s3.us-east-1.amazonaws.com/900000_900999_transactions.csv.gz
\! wget https://timescale-demo-data.s3.us-east-1.amazonaws.com/900000_900999_tx_vinout.csv.gz

-- Load data from compressed files directly into tables
\COPY blocks 
    FROM PROGRAM 'gunzip -c 900000_900999_blocks.csv.gz' 
    WITH (FORMAT CSV, HEADER);
    
\COPY transactions 
    FROM PROGRAM 'gunzip -c 900000_900999_transactions.csv.gz' 
    WITH (FORMAT CSV, HEADER);
    
\COPY tx_vinout 
    FROM PROGRAM 'gunzip -c 900000_900999_tx_vinout.csv.gz' 
    WITH (FORMAT CSV, HEADER);

-- ==========================================
-- BASIC BLOCKCHAIN QUERIES
-- ==========================================

/*
You can verify the results on block explorer:
https://blockexplorer.one/bitcoin/mainnet/blockId/900500
*/

-- Query 1: Get all transactions in block 900500
SELECT *
FROM transactions
WHERE block_height = 900500;


-- Query 2: Get details of a specific transaction in block 900500
-- Transaction reference: https://blockexplorer.one/bitcoin/mainnet/tx/53473c9303a02b559929a3fcca84ec7cd20c0931cda482c36f7dfc4fb8144e3f
SELECT *
FROM transactions
WHERE txid = '53473c9303a02b559929a3fcca84ec7cd20c0931cda482c36f7dfc4fb8144e3f';


-- Query 3: Get all inputs and outputs for a specific transaction
SELECT 
    type,
    address,
    value
FROM tx_vinout
WHERE txid = '53473c9303a02b559929a3fcca84ec7cd20c0931cda482c36f7dfc4fb8144e3f';

-- Query 4: Calculate balance for a specific Bitcoin address
-- Note: This shows only partial balance since we're working with a subset of blockchain data
SELECT 
    SUM(value) AS total_value,
    COUNT(*) AS transaction_count
FROM tx_vinout
WHERE address = 'bc1qjjcn46tmuf3wnpe987u5lpkkgwgv9pc82f6n2gcq7al6d8dyguxs3svvhy';


-- Query 5: Get recent transactions for a specific address
SELECT *
FROM tx_vinout
WHERE address = 'bc1qjjcn46tmuf3wnpe987u5lpkkgwgv9pc82f6n2gcq7al6d8dyguxs3svvhy'
ORDER BY timestamp DESC
LIMIT 10;
    
-- ==========================================
-- ADVANCED BLOCKCHAIN QUERIES
-- ==========================================

-- Query 6: Trace where Bitcoin went from a specific address
-- This follows the money flow by finding outputs of transactions where the address was an input
WITH transactions_out AS (
    SELECT DISTINCT 
        txid, 
        timestamp
    FROM tx_vinout
    WHERE address = 'bc1qjjcn46tmuf3wnpe987u5lpkkgwgv9pc82f6n2gcq7al6d8dyguxs3svvhy'
        AND type = 'vin'
    ORDER BY timestamp
)
SELECT 
    address,
    timestamp,
    value
FROM tx_vinout
WHERE (txid, timestamp) IN (SELECT txid, timestamp FROM transactions_out)
    AND type = 'vout'; 


-- Query 7: Identify the miner of block 900000
-- Miners receive coinbase transactions as block rewards
WITH block AS (
    SELECT timestamp
    FROM blocks
    WHERE height = 900000
)
SELECT 
    address,
    value
FROM tx_vinout
WHERE block_height = 900000
    AND timestamp = (SELECT timestamp FROM block)
    AND coinbase = TRUE;  -- Look for coinbase transaction


-- Query 8: Calculate total earnings for the miner
SELECT 
    SUM(value) AS total_earnings,
    COUNT(*) AS coinbase_transactions
FROM tx_vinout
WHERE address = '1PuJjnF476W3zXfVYmJfGnouzFDAXakkL4'  -- Miner address from previous query
    AND coinbase = TRUE;

-- Query 9: Trace where the miner sends their funds
-- Analyze spending patterns of the mining rewards
WITH transactions_out AS (
    SELECT DISTINCT 
        txid, 
        timestamp
    FROM tx_vinout
    WHERE address = '1PuJjnF476W3zXfVYmJfGnouzFDAXakkL4'
        AND type = 'vin'
    ORDER BY timestamp
)
SELECT 
    address,
    COUNT(*) AS transaction_count,
    SUM(value) AS total_value
FROM tx_vinout
WHERE (txid, timestamp) IN (SELECT txid, timestamp FROM transactions_out)
    AND type = 'vout'
GROUP BY address
ORDER BY total_value DESC;


-- ==========================================
-- AGENTIC AI ANALYSIS SETUP
-- ==========================================

/*
Configure MCP PostgreSQL agent with MCP-capable model (e.g., Claude Desktop):

{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": [
        "@modelcontextprotocol/server-postgres",
        "postgres://tsdbadmin:XXXXXX@YYYYY.ZZZZZ.tsdb.cloud.timescale.com:30688/tsdb?sslmode=require"
      ]
    }
  }
}
*/

-- ==========================================
-- ANALYSIS QUESTIONS FOR LLM
-- ==========================================

/*
1. IDENTIFY MOST ACTIVE BITCOIN ADDRESSES AND TRANSACTION PATTERNS
   Expected finding: Dust spamming from address '3Fh5XYeEKzqomEtLnc7155tZ3Dr1aC4CjM'

2. IDENTIFY HIGHEST VALUE BITCOIN TRANSACTIONS
   Expected findings:
   - Consolidation of large amounts to address 'bc1qx2x5cqhymfcnjtg902ky6u5t5htmt7fvqztdsm028hkrvxcl4t2sjtpd9l'
   - Multiple transactions of ~19,000 BTC
   - Institutional player activity patterns

3. IDENTIFY EXCHANGE-LIKE ACTIVITY
   Expected finding: Exchange address 'bc1qrqlamjhy2qp0xj5mxv4sx7ra9qfmfxllf93l26'
*/
