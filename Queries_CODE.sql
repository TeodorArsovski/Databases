--QUERIES CODE FILE:
-- Items Query 1 - Not stonks
SELECT  
    c.NAME_CROP AS CROP_NAME,
    s.SEED_TYPE AS TYPE,
    i.PRICE_TO_BUY as PRICE_TO_BUY_NORMAL,
    i.PRICE_TO_SELL as PRICE_TO_SELL,
    ROUND( (i.PRICE_TO_SELL-i.PRICE_TO_BUY)
        * 100 / i.PRICE_TO_BUY , 2 )      AS PRICE_DIFFERENCE
FROM        CROP        c
    JOIN        SEED        s  ON s.NAME_CROP = c.NAME_CROP
    JOIN        ITEM        i  ON i.ID_ITEM   = s.ID_SEED
WHERE       UPPER(c.QUALITY) = 'COOPER'
    AND       i.PRICE_TO_BUY  IS NOT NULL
    AND       i.PRICE_TO_SELL IS NOT NULL
    AND       i.PRICE_TO_SELL < i.PRICE_TO_BUY       
ORDER BY    pct_difference ASC;

-- Items Query 2 - Item popularity
SELECT  sh.name_shop           AS STORE_NAME,
        sh.specialization      AS SPECIALIZATION,
        it.name                AS ITEM_NAME,
        SUM(bs.amount)         AS NUM_PURCHASES
FROM    buy_sell bs
JOIN    (  SELECT id_item
           FROM   buy_sell
           WHERE  action = 'BUY'
           GROUP  BY id_item
           ORDER  BY SUM(amount) DESC
           FETCH  FIRST 1 ROW ONLY         
        ) best
      ON best.id_item = bs.id_item
JOIN    shop  sh ON sh.id_shop = bs.id_shop
JOIN    item  it ON it.id_item = bs.id_item
WHERE   bs.action = 'BUY'
GROUP  BY sh.name_shop, sh.specialization, it.name
ORDER  BY times_sold DESC, sh.name_shop;

-- Items Query 3 - Cutting it close
SELECT  sh.name_shop                    AS shop_name,
        sh.specialization               AS specialization,
        pl.nickname                     AS player_name,
        it.name                         AS item_name,
        bs.amount                       AS amount,
        ABS(bs.money_fluctuation)       AS gold_expended,     
        TRUNC(bs.action_time)           AS date_of_purchase   
FROM    buy_sell bs
JOIN    shop   sh ON sh.id_shop   = bs.id_shop
JOIN    player pl ON pl.id_player = bs.id_player
JOIN    item   it ON it.id_item   = bs.id_item
WHERE   bs.action = 'BUY'                                   
  AND   EXTRACT(month FROM bs.action_time) = 12            
  AND   bs.action_time = (                                    
            SELECT MAX(bs2.action_time)
            FROM   buy_sell bs2
            WHERE  bs2.action = 'BUY'
              AND  TRUNC(bs2.action_time) = TRUNC(bs.action_time)
        )
ORDER  BY date_of_purchase;                                 

-- Items Query 4 - Spare no expense
SELECT  i1.name                       AS item1,
        i2.name                       AS item2,
        (f1.health_regain
         + f2.health_regain)          AS total_health
FROM    food  f1
JOIN    food  f2  ON f1.id_food < f2.id_food          -- avoid duplicates and self-pairs
JOIN    item  i1  ON i1.id_item = f1.id_food          -- names for first food
JOIN    item  i2  ON i2.id_item = f2.id_food          -- names for second food
ORDER BY ABS( (f1.health_regain + f2.health_regain) - 100 )
FETCH  FIRST 20 ROWS ONLY;

-- Items Query 5 - The best places
SELECT  p.location_name               AS location_name,
        COUNT(*)                      AS transaction_count
FROM    buy_sell   bs
JOIN    shop       sh  ON sh.id_shop  = bs.id_shop      -- shop of the transaction
JOIN    place      p   ON p.id_place  = sh.id_place     -- village/town/location
WHERE   ABS(bs.money_fluctuation) > 200                 -- > 200 gold, spend or earn
GROUP  BY p.location_name
ORDER  BY transaction_count DESC;                       -- busiest first



--QUERY 1) FARM
SELECT p.ID_PLAYER, p.NICKNAME AS NAME, AVG(pm.END_DATE - pm.START_DATE) AS AVG_TIMESPAN
FROM PLAYER_MISSION pm
JOIN PLAYER p ON p.ID_PLAYER = pm.ID_PLAYER
WHERE pm.IS_COMPLETED = 1 AND pm.END_DATE > pm.START_DATE
GROUP BY p.ID_PLAYER, p.NICKNAME
HAVING AVG(pm.END_DATE - pm.START_DATE) < (
    SELECT AVG(END_DATE - START_DATE)
    FROM PLAYER_MISSION
    WHERE IS_COMPLETED = 1 AND END_DATE > START_DATE
)
ORDER BY AVG_TIMESPAN ASC
FETCH FIRST 10 ROWS ONLY;

--QUERY 2) FARM
SELECT f.ID_FARM, f.SPECIALIZATION, COUNT(*) AS NUM_CROPS
FROM FARM f
JOIN FARMBUILDING fb ON fb.ID_FARM = f.ID_FARM
JOIN CULTIVATIONFIELD cf ON cf.ID_FIELD = fb.ID_FARM_BUILDING
JOIN GROW g ON g.ID_FIELD = cf.ID_FIELD
JOIN CROP c ON c.ID_CROP = g.ID_CROP
WHERE c.QUALITY = 'Gold'
GROUP BY f.ID_FARM, f.SPECIALIZATION
HAVING COUNT(*) = (
    SELECT MAX(GOLD_COUNT)
    FROM (
        SELECT f2.ID_FARM, COUNT(*) AS GOLD_COUNT
        FROM FARM f2
        JOIN FARMBUILDING fb2 ON fb2.ID_FARM = f2.ID_FARM
        JOIN CULTIVATIONFIELD cf2 ON cf2.ID_FIELD = fb2.ID_FARM_BUILDING
        JOIN GROW g2 ON g2.ID_FIELD = cf2.ID_FIELD
        JOIN CROP c2 ON c2.ID_CROP = g2.ID_CROP
        WHERE c2.QUALITY = 'Gold'
        GROUP BY f2.ID_FARM
    )
)
ORDER BY f.ID_FARM;

--FARM QUERY 3)
SELECT 
  a.ID_BARN,
  a.ID_ANIMAL,
  a.NAME_ANIMAL AS ANIMAL_NAME,
  a.AGE,
  a.HEALTH AS HEALTH_STATUS,
  COUNT(p.ID_PRODUCT) AS NUM_PRODUCTS
FROM ANIMAL a
JOIN PRODUCE p ON a.ID_ANIMAL = p.ID_ANIMAL
WHERE a.HEALTH = 'Healthy'
GROUP BY a.ID_BARN, a.ID_ANIMAL, a.NAME_ANIMAL, a.AGE, a.HEALTH
HAVING COUNT(p.ID_PRODUCT) > (
  SELECT AVG(prod_count)
  FROM (
    SELECT COUNT(p2.ID_PRODUCT) AS prod_count
    FROM ANIMAL a2
    JOIN PRODUCE p2 ON a2.ID_ANIMAL = p2.ID_ANIMAL
    WHERE a2.ID_BARN = a.ID_BARN
    GROUP BY a2.ID_ANIMAL
  )
)
ORDER BY a.ID_BARN, a.ID_ANIMAL;

--FARM QUERY 4)
SELECT
  f.ID_FARM,
  f.HECTARES,
  SUM(fb.BUILDING_SIZE) AS OCCUPIED_SPACE,
  f.HECTARES - SUM(fb.BUILDING_SIZE) AS SPACE_LEFT,
  COUNT(*) AS NUM_BUILDINGS,
  FLOOR((f.HECTARES - SUM(fb.BUILDING_SIZE)) / MIN(fb.BUILDING_SIZE)) AS NUM_NEW_BUILDINGS
FROM FARM f
JOIN FARMBUILDING fb ON f.ID_FARM = fb.ID_FARM
GROUP BY f.ID_FARM, f.HECTARES
HAVING f.HECTARES < 600000 AND (f.HECTARES - SUM(fb.BUILDING_SIZE)) > 0
ORDER BY f.ID_FARM;

--FARM QUERY 5)
SELECT
  p.ID_PLAYER,
  p.NICKNAME AS NAME,
  b.ID_BARN AS ID_BARN_BUILDING,
  COUNT(DISTINCT a.ID_ANIMAL_SPECIE) AS SPECIES_COUNT
FROM PLAYER p
JOIN FARM f ON f.ID_PLAYER = p.ID_PLAYER
JOIN FARMBUILDING fb ON fb.ID_FARM = f.ID_FARM
JOIN BARN b ON b.ID_BARN = fb.ID_FARM_BUILDING
JOIN ANIMAL a ON a.ID_BARN = b.ID_BARN
WHERE p.ID_PLAYER NOT IN (
  SELECT DISTINCT ID_PLAYER
  FROM PLAYER_MISSION
  WHERE IS_COMPLETED = 1
)
GROUP BY p.ID_PLAYER, p.NICKNAME, b.ID_BARN
HAVING COUNT(DISTINCT a.ID_ANIMAL_SPECIE) > 1
ORDER BY b.ID_BARN;

