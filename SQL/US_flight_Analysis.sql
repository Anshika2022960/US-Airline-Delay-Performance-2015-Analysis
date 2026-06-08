------------------------------------------- Phase-1 --------------------------------------------
CREATE TABLE airlines (
    iata_code VARCHAR(10),
    airline VARCHAR(255)
);

CREATE TABLE airports (
    iata_code VARCHAR(10),
    airport VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(50),
    country VARCHAR(50),
    latitude NUMERIC,
    longitude NUMERIC
);

CREATE TABLE flights (
    year INT,
    month INT,
    day INT,
    day_of_week INT,
    airline VARCHAR(10),
    flight_number INT,
    tail_number VARCHAR(20),
    origin_airport VARCHAR(10),
    destination_airport VARCHAR(10),
    scheduled_departure VARCHAR(10),
    departure_time VARCHAR(10),
    departure_delay INT,
    taxi_out INT,
    wheels_off VARCHAR(10),
    scheduled_time INT,
    elapsed_time INT,
    air_time INT,
    distance INT,
    wheels_on VARCHAR(10),
    taxi_in INT,
    scheduled_arrival VARCHAR(10),
    arrival_time VARCHAR(10),
    arrival_delay INT,
    diverted INT,
    cancelled INT,
    cancellation_reason VARCHAR(10),
    air_system_delay INT,
    security_delay INT,
    airline_delay INT,
    late_aircraft_delay INT,
    weather_delay INT
);

------------------ Verify Tables Exist--------------

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public';



------------------ Verify Row Counts ---------------

select count(*) From airlines;

select count(*) From airports;

select count(*) From flights;

----------------------------------------------------------Phase 2-----------------------------------------------------

--------------Step 1: Create Full Scheduled Departure Timestamp--------------

ALTER TABLE flights
ADD COLUMN scheduled_departure_ts TIMESTAMP;


UPDATE flights
SET scheduled_departure_ts =
TO_TIMESTAMP(
year || '-' ||
LPAD(month::text,2,'0') || '-' ||
LPAD(day::text,2,'0') || ' ' ||
LPAD(scheduled_departure,4,'0'),
'YYYY-MM-DD HH24MI'
);

SELECT scheduled_departure,
scheduled_departure_ts
FROM flights
LIMIT 10;
--------------- Step 2: Investigate Missing Values (Null values) -------------------------

SELECT
COUNT(*) AS total_rows,
COUNT(arrival_delay) AS arrival_delay_not_null,
COUNT(departure_delay) AS departure_delay_not_null,
COUNT(cancellation_reason) AS cancellation_reason_not_null
FROM flights;

----------Check delay columns individually----------

SELECT
SUM(CASE WHEN departure_delay IS NULL THEN 1 ELSE 0 END) AS dep_delay_nulls,
SUM(CASE WHEN arrival_delay IS NULL THEN 1 ELSE 0 END) AS arr_delay_nulls,
SUM(CASE WHEN weather_delay IS NULL THEN 1 ELSE 0 END) AS weather_delay_nulls,
SUM(CASE WHEN airline_delay IS NULL THEN 1 ELSE 0 END) AS airline_delay_nulls
FROM flights;


SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN iata_code IS NULL THEN 1 ELSE 0 END) AS iata_code_nulls,
    SUM(CASE WHEN airport IS NULL THEN 1 ELSE 0 END) AS airport_nulls,
    SUM(CASE WHEN city IS NULL THEN 1 ELSE 0 END) AS city_nulls,
    SUM(CASE WHEN state IS NULL THEN 1 ELSE 0 END) AS state_nulls,
    SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END) AS country_nulls,
    SUM(CASE WHEN latitude IS NULL THEN 1 ELSE 0 END) AS latitude_nulls,
    SUM(CASE WHEN longitude IS NULL THEN 1 ELSE 0 END) AS longitude_nulls
FROM airports;


SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN year IS NULL THEN 1 ELSE 0 END) AS year_nulls,
    SUM(CASE WHEN month IS NULL THEN 1 ELSE 0 END) AS month_nulls,
    SUM(CASE WHEN day IS NULL THEN 1 ELSE 0 END) AS day_nulls,
    SUM(CASE WHEN airline IS NULL THEN 1 ELSE 0 END) AS airline_nulls,
    SUM(CASE WHEN flight_number IS NULL THEN 1 ELSE 0 END) AS flight_number_nulls,
    SUM(CASE WHEN origin_airport IS NULL THEN 1 ELSE 0 END) AS origin_airport_nulls,
    SUM(CASE WHEN destination_airport IS NULL THEN 1 ELSE 0 END) AS destination_airport_nulls,
    SUM(CASE WHEN departure_delay IS NULL THEN 1 ELSE 0 END) AS departure_delay_nulls,
    SUM(CASE WHEN arrival_delay IS NULL THEN 1 ELSE 0 END) AS arrival_delay_nulls,
    SUM(CASE WHEN cancellation_reason IS NULL THEN 1 ELSE 0 END) AS cancellation_reason_nulls,
    SUM(CASE WHEN weather_delay IS NULL THEN 1 ELSE 0 END) AS weather_delay_nulls,
    SUM(CASE WHEN airline_delay IS NULL THEN 1 ELSE 0 END) AS airline_delay_nulls,
    SUM(CASE WHEN security_delay IS NULL THEN 1 ELSE 0 END) AS security_delay_nulls,
    SUM(CASE WHEN late_aircraft_delay IS NULL THEN 1 ELSE 0 END) AS late_aircraft_delay_nulls
FROM flights

------------  airline_analysis_view ------------------
CREATE OR REPLACE VIEW airline_analysis_view AS
SELECT
    f.*,

    COALESCE(f.weather_delay, 0) AS weather_delay_clean,
    COALESCE(f.airline_delay, 0) AS airline_delay_clean,
    COALESCE(f.security_delay, 0) AS security_delay_clean,
    COALESCE(f.late_aircraft_delay, 0) AS late_aircraft_delay_clean,

    a.airline AS airline_name

FROM flights f
LEFT JOIN airlines a
ON f.airline = a.iata_code;

SELECT
    airline,
    airline_name,
    weather_delay,
    weather_delay_clean,
    airline_delay,
    airline_delay_clean
FROM airline_analysis_view
LIMIT 10;

----------------Step 3: Data Enrichment --------------------

------------Create Cancellation Description---------

ALTER TABLE flights
ADD COLUMN cancellation_reason_desc VARCHAR(50);

UPDATE flights
SET cancellation_reason_desc =
CASE cancellation_reason
WHEN 'A' THEN 'Airline/Carrier'
WHEN 'B' THEN 'Weather'
WHEN 'C' THEN 'National Air System'
WHEN 'D' THEN 'Security'
ELSE 'Not Cancelled'
END;

----------view---------

SELECT cancellation_reason,
cancellation_reason_desc
FROM flights
LIMIT 20;

------------Create FLIGHT_DATE Column---------------

ALTER TABLE flights
ADD COLUMN flight_date DATE;

UPDATE flights
SET flight_date =
MAKE_DATE(year, month, day);

------------view---------
SELECT flight_date
FROM flights
LIMIT 10;

-----------------Step 4: Create Integrated Dataset------------------

CREATE OR REPLACE VIEW US_airline_analysis AS

SELECT

    f.*,

    a.airline AS airline_name,

    oa.airport AS origin_airport_name,
    oa.city AS origin_city,
    oa.state AS origin_state,

    da.airport AS destination_airport_name,
    da.city AS destination_city,
    da.state AS destination_state

FROM flights f

LEFT JOIN airlines a
ON f.airline = a.iata_code

LEFT JOIN airports oa
ON f.origin_airport = oa.iata_code

LEFT JOIN airports da
ON f.destination_airport = da.iata_code;

-----------View-----------
SELECT
airline_name,
origin_airport_name,
origin_city,
origin_state,
destination_airport_name,
destination_city,
destination_state
FROM US_airline_analysis
LIMIT 10;



------------------------------------------------- Phase 3 ------------------------------------------------------------

---------- Step 1A: Overall Flight Volume----------------

SELECT 
    COUNT(*) AS total_flights
FROM airline_analysis_view;

----------- Step 1B: Total Cancelled Flights -------------

SELECT
    COUNT(*) AS total_flights,
    SUM(CASE WHEN cancelled = 1 THEN 1 ELSE 0 END) AS total_cancelled,
    ROUND(
        SUM(CASE WHEN cancelled = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS cancellation_rate_percentage
FROM airline_analysis_view;

-------------- Step 1C: Cancellation by Reason- ------------

SELECT cancellation_reason_desc
FROM flights
LIMIT 5;

SELECT column_name
FROM information_schema.columns
WHERE table_name = 'airline_analysis_view';


SELECT
    cancellation_reason_desc,
    COUNT(*) AS cancelled_flights
FROM flights
WHERE cancelled = 1
GROUP BY cancellation_reason_desc
ORDER BY cancelled_flights DESC

-------------- Step 1D: Total Diverted Flights -----------

SELECT
    COUNT(*) AS total_flights,
    SUM(CASE WHEN diverted = 1 THEN 1 ELSE 0 END) AS total_diverted,
    ROUND(
        SUM(CASE WHEN diverted = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS diversion_rate_percentage
FROM airline_analysis_view;


-------------- Step 1E: Monthly Flight Volume ------------

SELECT
    month,
    COUNT(*) AS total_flights
FROM airline_analysis_view
GROUP BY month
ORDER BY month;


-------------- Step 1F: Airline-wise Flight Volume ----------

SELECT
    airline_name,
    COUNT(*) AS total_flights
FROM airline_analysis_view
GROUP BY airline_name
ORDER BY total_flights DESC;

--------------Step 2A: Basic Statistics for Departure and Arrival Delay-----------

SELECT
    ROUND(AVG(departure_delay), 2) AS avg_departure_delay,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY departure_delay) AS median_departure_delay,
    MIN(departure_delay) AS min_departure_delay,
    MAX(departure_delay) AS max_departure_delay,

    ROUND(AVG(arrival_delay), 2) AS avg_arrival_delay,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY arrival_delay) AS median_arrival_delay,
    MIN(arrival_delay) AS min_arrival_delay,
    MAX(arrival_delay) AS max_arrival_delay
FROM airline_analysis_view
WHERE cancelled = 0;

-------------- Step 2B: Distribution of Different Delay Types-------------------

SELECT 'Airline Delay' AS delay_type, SUM(COALESCE(airline_delay, 0)) AS total_delay_minutes
FROM airline_analysis_view
UNION ALL
SELECT 'Weather Delay', SUM(COALESCE(weather_delay, 0))
FROM airline_analysis_view
UNION ALL
SELECT 'Air System Delay', SUM(COALESCE(air_system_delay, 0))
FROM airline_analysis_view
UNION ALL
SELECT 'Security Delay', SUM(COALESCE(security_delay, 0))
FROM airline_analysis_view
UNION ALL
SELECT 'Late Aircraft Delay', SUM(COALESCE(late_aircraft_delay, 0))
FROM airline_analysis_view
ORDER BY total_delay_minutes DESC;

---------------Step 3- KPI 1: On-Time Performance (OTP) Rate ----------------------

SELECT
    COUNT(*) AS total_flights,

    SUM(
        CASE
            WHEN arrival_delay <= 15 THEN 1
            ELSE 0
        END
    ) AS on_time_flights,

    ROUND(
        SUM(
            CASE
                WHEN arrival_delay <= 15 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS otp_rate_percentage

FROM airline_analysis_view
WHERE cancelled = 0;

---------------- KPI 2: Average Departure Delay---------
SELECT
    ROUND(AVG(departure_delay),2) AS avg_departure_delay
FROM airline_analysis_view
WHERE cancelled = 0;

---------------KPI 3: Average Arrival Delay-------------

SELECT
    ROUND(AVG(arrival_delay),2) AS avg_arrival_delay
FROM airline_analysis_view
WHERE cancelled = 0;

--------------- KPI 4: Cancellation Rate --------------
SELECT
    ROUND(
        SUM(
            CASE
                WHEN cancelled = 1 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS cancellation_rate
FROM airline_analysis_view;

--------------- KPI 5: Diversion Rate ------------------

SELECT
    ROUND(
        SUM(
            CASE
                WHEN diverted = 1 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS diversion_rate
FROM airline_analysis_view;

---------------- KPI 6: Percentage Contribution of Delay Types-----------

SELECT
    'Airline Delay' AS delay_type,
    ROUND(
        SUM(COALESCE(airline_delay,0))*100.0/
        (
            SUM(COALESCE(airline_delay,0))
          + SUM(COALESCE(weather_delay,0))
          + SUM(COALESCE(air_system_delay,0))
          + SUM(COALESCE(security_delay,0))
          + SUM(COALESCE(late_aircraft_delay,0))
        ),
        2
    ) AS percentage

FROM airline_analysis_view

UNION ALL

SELECT
    'Weather Delay',
    ROUND(
        SUM(COALESCE(weather_delay,0))*100.0/
        (
            SUM(COALESCE(airline_delay,0))
          + SUM(COALESCE(weather_delay,0))
          + SUM(COALESCE(air_system_delay,0))
          + SUM(COALESCE(security_delay,0))
          + SUM(COALESCE(late_aircraft_delay,0))
        ),
        2
    )
FROM airline_analysis_view

UNION ALL

SELECT
    'NAS Delay',
    ROUND(
        SUM(COALESCE(air_system_delay,0))*100.0/
        (
            SUM(COALESCE(airline_delay,0))
          + SUM(COALESCE(weather_delay,0))
          + SUM(COALESCE(air_system_delay,0))
          + SUM(COALESCE(security_delay,0))
          + SUM(COALESCE(late_aircraft_delay,0))
        ),
        2
    )
FROM airline_analysis_view

UNION ALL

SELECT
    'Security Delay',
    ROUND(
        SUM(COALESCE(security_delay,0))*100.0/
        (
            SUM(COALESCE(airline_delay,0))
          + SUM(COALESCE(weather_delay,0))
          + SUM(COALESCE(air_system_delay,0))
          + SUM(COALESCE(security_delay,0))
          + SUM(COALESCE(late_aircraft_delay,0))
        ),
        2
    )
FROM airline_analysis_view

UNION ALL

SELECT
    'Late Aircraft Delay',
    ROUND(
        SUM(COALESCE(late_aircraft_delay,0))*100.0/
        (
            SUM(COALESCE(airline_delay,0))
          + SUM(COALESCE(weather_delay,0))
          + SUM(COALESCE(air_system_delay,0))
          + SUM(COALESCE(security_delay,0))
          + SUM(COALESCE(late_aircraft_delay,0))
        ),
        2
    )
FROM airline_analysis_view;

---------------- Step-4 : 1. KPI by Airline---------------

SELECT
    airline_name,
    COUNT(*) AS total_flights,
    ROUND(AVG(departure_delay), 2) AS avg_departure_delay,
    ROUND(AVG(arrival_delay), 2) AS avg_arrival_delay,
    ROUND(SUM(CASE WHEN arrival_delay <= 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS otp_rate,
    ROUND(SUM(CASE WHEN cancelled = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS cancellation_rate
FROM airline_analysis_view
GROUP BY airline_name
ORDER BY otp_rate DESC;


---------------- 2. KPI by Origin Airport-----------------
SELECT
    origin_airport,
    origin_airport_name,
    origin_city,
    origin_state,
    COUNT(*) AS total_flights,
    ROUND(AVG(departure_delay), 2) AS avg_departure_delay,
    ROUND(AVG(arrival_delay), 2) AS avg_arrival_delay,
    ROUND(SUM(CASE WHEN arrival_delay <= 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS otp_rate,
    ROUND(SUM(CASE WHEN cancelled = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS cancellation_rate
FROM  US_airline_analysis
GROUP BY origin_airport, origin_airport_name, origin_city, origin_state
ORDER BY avg_departure_delay DESC;

---------------- 3. KPI by Destination Airport ------------

SELECT
    destination_airport,
    destination_airport_name,
    destination_city,
    destination_state,
    COUNT(*) AS total_flights,
    ROUND(AVG(departure_delay), 2) AS avg_departure_delay,
    ROUND(AVG(arrival_delay), 2) AS avg_arrival_delay,
    ROUND(SUM(CASE WHEN arrival_delay <= 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS otp_rate,
    ROUND(SUM(CASE WHEN cancelled = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS cancellation_rate
FROM US_airline_analysis
GROUP BY destination_airport, destination_airport_name, destination_city, destination_state
ORDER BY avg_arrival_delay DESC;

----------------- 4. KPI by Month ---------------------------

SELECT
    month,
    COUNT(*) AS total_flights,
    ROUND(AVG(departure_delay), 2) AS avg_departure_delay,
    ROUND(AVG(arrival_delay), 2) AS avg_arrival_delay,
    ROUND(SUM(CASE WHEN arrival_delay <= 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS otp_rate,
    ROUND(SUM(CASE WHEN cancelled = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS cancellation_rate
FROM US_airline_analysis
GROUP BY month
ORDER BY month;


----------------- 5. KPI by Day of Week ---------------------

SELECT
    day_of_week,
    COUNT(*) AS total_flights,
    ROUND(AVG(departure_delay), 2) AS avg_departure_delay,
    ROUND(AVG(arrival_delay), 2) AS avg_arrival_delay,
    ROUND(SUM(CASE WHEN arrival_delay <= 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS otp_rate,
    ROUND(SUM(CASE WHEN cancelled = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS cancellation_rate
FROM US_airline_analysis
GROUP BY day_of_week
ORDER BY day_of_week;


---------------- 6. KPI by Time of Day ------------------------

SELECT
    CASE
        WHEN CAST(SUBSTRING(LPAD(scheduled_departure, 4, '0'), 1, 2) AS INT) BETWEEN 5 AND 11 THEN 'Morning'
        WHEN CAST(SUBSTRING(LPAD(scheduled_departure, 4, '0'), 1, 2) AS INT) BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN CAST(SUBSTRING(LPAD(scheduled_departure, 4, '0'), 1, 2) AS INT) BETWEEN 17 AND 21 THEN 'Evening'
        ELSE 'Night'
    END AS time_of_day,
    COUNT(*) AS total_flights,
    ROUND(AVG(departure_delay), 2) AS avg_departure_delay,
    ROUND(AVG(arrival_delay), 2) AS avg_arrival_delay,
    ROUND(SUM(CASE WHEN arrival_delay <= 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS otp_rate,
    ROUND(SUM(CASE WHEN cancelled = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS cancellation_rate
FROM airline_analysis_view
GROUP BY time_of_day
ORDER BY total_flights DESC;


------------Delay Type --------------------

CREATE OR REPLACE VIEW delay_type_summary AS
SELECT 'Airline Delay' AS delay_type, SUM(COALESCE(airline_delay,0)) AS total_delay_minutes
FROM us_airline_analysis
UNION ALL
SELECT 'Weather Delay', SUM(COALESCE(weather_delay,0))
FROM us_airline_analysis
UNION ALL
SELECT 'NAS Delay', SUM(COALESCE(air_system_delay,0))
FROM us_airline_analysis
UNION ALL
SELECT 'Security Delay', SUM(COALESCE(security_delay,0))
FROM us_airline_analysis
UNION ALL
SELECT 'Late Aircraft Delay', SUM(COALESCE(late_aircraft_delay,0))
FROM us_airline_analysis;


--------------- create time_of_day----------------------------

CREATE OR REPLACE VIEW us_airline_analysis_time_of_day AS
SELECT
    *,
    CASE
        WHEN CAST(SUBSTRING(LPAD(scheduled_departure, 4, '0'), 1, 2) AS INT) BETWEEN 5 AND 11 THEN 'Morning'
        WHEN CAST(SUBSTRING(LPAD(scheduled_departure, 4, '0'), 1, 2) AS INT) BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN CAST(SUBSTRING(LPAD(scheduled_departure, 4, '0'), 1, 2) AS INT) BETWEEN 17 AND 21 THEN 'Evening'
        ELSE 'Night'
    END AS time_of_day
FROM airline_analysis_view;




