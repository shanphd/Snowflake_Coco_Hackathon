/*
  NEXUS 360 — Cortex Analyst Setup
  Create stage and upload semantic model YAML
*/

USE WAREHOUSE SHAN_WH;
USE DATABASE SFK_HACKATHON;
USE SCHEMA SFK_HACK_1;

-- Create stage for semantic model
CREATE OR REPLACE STAGE NEXUS360_SEMANTIC_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for NEXUS 360 Cortex Analyst semantic model YAML';

-- Upload YAML file (run from SnowSQL or Snowsight)
-- PUT file://semantic_model/nexus360_analyst.yaml @NEXUS360_SEMANTIC_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Verify upload
-- LIST @NEXUS360_SEMANTIC_STAGE;
