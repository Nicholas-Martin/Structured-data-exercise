-- What are the top 5 brands by receipts scanned for most recent month?

-- Presto SQL

/*
    I am going to assume the "most recent month" in question is the most recently completed month
    So if today is 2024-07-01, the "most recent month" is the June 2024 (2024-06-01 is the first of the month)

    I am also going to assume "top 5 brands by receipts scanned" is counting each entry of an item as a single count.
    So if I bought 5 boxes of the same Kraft Mac and Cheese on my grocery receipt, that would only count as a single 
    entry of a 'scanned' receipt. And not 5 entries.

    In short, I will not be counting the `quantityPurchased` within the receipt to rank the top brands. The goal is to rank
    which brands showed up on the receipts the most, not the most quantity of product purchased.

    BUT if I purchased 3 packs of Kraft Singles American Cheese Slices in addition to my 5 boxes of Kraft Mac and Cheese, this
    would count as 2 brand entries on one receipt, becuase I purchased 2 distinct 'barcodes' of the Kraft brand on my receipt
*/

WITH 
brand_rank as 
(
    SELECT
        bb.brand_id,
        COUNT(*) as total_scans,
        RANK() OVER (ORDER BY COUNT(*) DESC) as rank 

    FROM dim_receipt dr
    JOIN receipt_barcode rb
        ON rb.receipt_id = dr.receipt_id
    JOIN brand_barcode bb
        ON bb.barcode = rb.barcode

    WHERE DATE_TRUNC('month', DATE(FROM_UNIXTIME(dr.scannedUnixtime))) = DATE_TRUNC('month', CURRENT_DATE - interval '1' month)
    GROUP BY bb.brand_id
)

SELECT 
     br.brand_id as "Brand ID",
     db.brandName as "Brand",
     total_scans as "Scans"
FROM brand_rank br
LEFT JOIN dim_brand db
    ON db.brand_id = br.brand_id
WHERE rank <= 5
ORDER BY rank ASC