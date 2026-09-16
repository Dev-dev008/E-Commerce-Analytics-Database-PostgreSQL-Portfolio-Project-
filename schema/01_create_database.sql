-- ============================================================================
-- 01_create_database.sql
-- E-Commerce Analytics Database: Database & Environment Initialization
-- PostgreSQL 12+ compatible
-- ============================================================================

-- Create the database (execute connected to default 'postgres' database)
-- CREATE DATABASE ecommerce_analytics;

-- Connect to the database:
-- \c ecommerce_analytics

-- ----------------------------------------------------------------------------
-- Extensions
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For high-performance text search

-- Configure session settings for analytics
SET timezone = 'UTC';
SET client_encoding = 'UTF8';

COMMENT ON DATABASE ecommerce_analytics IS 'E-Commerce Analytics Portfolio Project database for BI, customer segmentation, and cohort analysis.';
