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


-- Items Query 6 - Item sale -> This is with item_names, but althrouhg
-- i did a query with Item IDs since the .csv file has a same name for item
-- where they have different IDs but when i do with IDs i get 0 for money Fluctation
-- Im going to include both queries

SELECT  item_name,
        shop,
        player_name,
        ROUND(unit_price - baseline_price , 2) AS money_earned_over_base
FROM (
       
        SELECT  it.name                               AS item_name,
                sh.name_shop                          AS shop,
                pl.nickname                           AS player_name,
                ABS(bs.money_fluctuation) / bs.amount AS unit_price,       
                MIN(it.price_to_sell)  OVER (PARTITION BY it.name)
                                                AS baseline_price,    
                MAX(ABS(bs.money_fluctuation)/bs.amount)
                     OVER (PARTITION BY it.name, pl.nickname)
                                                AS max_price,
                MIN(ABS(bs.money_fluctuation)/bs.amount)
                     OVER (PARTITION BY it.name, pl.nickname)
                                                AS min_price
        FROM   buy_sell bs
        JOIN   item   it ON it.id_item   = bs.id_item
        JOIN   shop   sh ON sh.id_shop   = bs.id_shop
        JOIN   player pl ON pl.id_player = bs.id_player
        WHERE  bs.action = 'SELL'
          AND  bs.amount > 0                               
     )
WHERE   unit_price = max_price    
    OR  unit_price = min_price    
ORDER  BY item_name,
          player_name,
          money_earned_over_base DESC;


/*
-- Query with IDs (Query 6)
/* Items Q-6  – highest & lowest sale price per unit   */
/*   version without CTEs, now ignores AMOUNT = 0     */
SELECT  it.name                                    AS item_name,
        sh.name_shop                               AS shop,
        pl.nickname                                AS player_name,
        ROUND( ABS(bs.money_fluctuation)/bs.amount
               - it.price_to_sell , 2)             AS money_earned_over_base
FROM    buy_sell bs
JOIN    item   it ON it.id_item   = bs.id_item
JOIN    shop   sh ON sh.id_shop   = bs.id_shop
JOIN    player pl ON pl.id_player = bs.id_player
WHERE   bs.action = 'SELL'
  AND   bs.amount > 0                                             
  AND ( ABS(bs.money_fluctuation)/bs.amount =
        ( SELECT MAX(ABS(bs2.money_fluctuation)/bs2.amount)
          FROM   buy_sell bs2
          WHERE  bs2.action = 'SELL'
            AND  bs2.amount > 0                                   
            AND  bs2.id_item   = bs.id_item
            AND  bs2.id_player = bs.id_player )
        OR
        ABS(bs.money_fluctuation)/bs.amount =
        ( SELECT MIN(ABS(bs3.money_fluctuation)/bs3.amount)
          FROM   buy_sell bs3
          WHERE  bs3.action = 'SELL'
            AND  bs3.amount > 0                                    
            AND  bs3.id_item   = bs.id_item
            AND  bs3.id_player = bs.id_player )
      )
ORDER  BY it.name, pl.nickname, money_earned_over_base DESC;

*/

-- Trigger
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trigger_1';
EXCEPTION
  WHEN OTHERS THEN                          
    IF SQLCODE != -4080 THEN RAISE; END IF;
END;
/                                         

CREATE OR REPLACE TRIGGER trigger_1
AFTER INSERT ON buy_sell
FOR EACH ROW
WHEN (NEW.action = 'BUY')                  
BEGIN
  
    UPDATE s_stored
       SET quantity = quantity - :NEW.amount
     WHERE id_shop  = :NEW.id_shop
       AND id_item  = :NEW.id_item;

    MERGE INTO p_stored p
    USING (SELECT :NEW.id_player AS id_player, 
                  :NEW.id_item   AS id_item
             FROM dual) src
       ON (p.id_player = src.id_player
           AND p.id_item   = src.id_item)
    WHEN MATCHED THEN
         UPDATE SET p.quantity = p.quantity + :NEW.amount
    WHEN NOT MATCHED THEN
         INSERT (id_player, id_item, quantity)
         VALUES (src.id_player, src.id_item, :NEW.amount);
END;
/
             
