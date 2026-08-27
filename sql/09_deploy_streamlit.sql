/*
  NEXUS 360 — Streamlit Deployment
  Create stage, upload files, deploy Streamlit app
*/

USE WAREHOUSE SHAN_WH;
USE DATABASE SFK_HACKATHON;
USE SCHEMA SFK_HACK_1;

-- Create stage for Streamlit files
CREATE OR REPLACE STAGE NEXUS360_STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for NEXUS 360 Streamlit application files';

-- Upload files (run via SnowSQL or Snowsight)
-- PUT file://streamlit/nexus360_app.py @NEXUS360_STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
-- PUT file://streamlit/environment.yml @NEXUS360_STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Create Streamlit application
CREATE OR REPLACE STREAMLIT NEXUS360_APP
    ROOT_LOCATION = '@SFK_HACKATHON.SFK_HACK_1.NEXUS360_STREAMLIT_STAGE'
    MAIN_FILE = 'nexus360_app.py'
    QUERY_WAREHOUSE = SHAN_WH
    COMMENT = 'NEXUS 360 Insurance Customer 360 Dashboard';
