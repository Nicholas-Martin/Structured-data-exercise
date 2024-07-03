# Structured-data-exercise

## Before you start
**All** of my coding work/ analysis was done inside of my `Main Notebook.ipynb` notebook. I like to use Jupyter Notebooks inside of VSCode for my workflow for organizational/ aesthetic purposes. Beyond my writeup to the questions in this README there is a LOT more markup data explaining what I did and how I got to my answers there. I thought if this workflow is not easily previewable in native Jupyter Notebooks, that I could add a quick guide to what I use inside of my setup to use Jupyter Notebooks inside of VS Code.

For reference, this is what my notebook looks like:

<img src="images\VS Code Preview.png" width="80%" alt="VS Code Preview">
 
- I used python `3.11.4`
- I will also include a list of the extensions I use for the previews/ Jupyter Notebooks to work well within VS Code

<img src="images\Extensions for VS Code.png" width="30%" alt="VS Code Preview">

## First: Review Existing Unstructured Data and Diagram a New Structured Relational Data Model
### Develop a simplified, structured, relational diagram to represent how you would model the data in a data warehouse. 


I diagrammed the database inside of Excel for easy formatting, so you can view it in the file `Relational Database Tables.xlsx` or you can see a more simple image/ screenshot of it within `Relational Database Diagram.png`

I am going to add a preview of it here, although it is a very wide image so it may not be very readable in the README itself.

NOTE: There is `Source Column` inside of the diagram, which refers to where I would be extracting the information from the sample files provided to me. In these source file names, I have some shorthand names for each file. For example,`receipts` represents the general data inside `receipts.json.gz`, and if I wanted to get the `_id` column from the receipt file, it would be `receipts._id`

<img src="Relational Database Diagram.png" alt="Relational Database Preview">

While constructing this database, I did have to make assumptions despite what some of my data analysis showed.
1. There is a distinct 1:1 relationship between `barcode` and `brand_id` - I saw 7 barcodes that were tied to 2 brands inside of my notebook, but I thought for data simplicity, it would be best to make the assumption that the `barcode` is distinct
2. The CPG category is generally very unclear to me on it's purpose. I understand CPG as a consumer packaged good, but was not familiar with how the label would work inside of the `brands.json.gz` file that was sent. Becuase of this unfamiliarity, I thought it would be best to link it to a granular level like `barcode` but wasn't sure if it could be a many to many relationship, so I thought it would be best to silo this inside it's own table. If there is a distinct relationship of `barcode` to `cpg` then I would just remove the `barcode_cpg` table, and just include the `cpg_id` column into the `brand_barcode` table instead (image below for reference)

<img src="images\Merging CPG and Brand table.png" alt="Alternate brand_barcode Table Structure">

3. There was generally some other data quality issues like `categoryCode` seeming to be `NULL` more often than `categoryName` which is strange but I thought I shouldn't bother to have that alter the main table structure, since their names imply they are so closely related, so I decided to keep `categoryCode` as the primary key, even though it seemed to have more NULLS in the data sample

4. This is not a data issue, but I think it is worth mentioning I would have truncated the `unixtimeMS` that is the base format of the `date` style columns. I would have truncated them to the second instead of the millisecond. This is relevant for my Presto SQL query later which assumes all of the `UNIXTIME`'s are in seconds and not Milliseconds. Otherwise the query would not work


## Second: Write a query that directly answers a predetermined question from a business stakeholder

### Write a SQL query against your new structured relational data model that answers one of the following bullet points below of your choosing.

The question I chose for this section was:

 **What are the top 5 brands by receipts scanned for most recent month?**

Here is the code preview of the query in the markdown, but you can also find it within the `Query.sql` file

```sql
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
```

## Third: Evaluate Data Quality Issues in the Data Provided

### Using the programming language of your choice (SQL, Python, R, Bash, etc...) identify at least one data quality issue. We are not expecting a full blown review of all the data provided, but instead want to know how you explore and evaluate data of questionable provenance.


This is where looking into my `Main Notebook.ipynb` would be best to show my work, and I don't want to make you read things twice, but I will create a quick preview of my primary findings from my analysis:

**`receipts.json.gz`**
 - Within the `rewardsReceiptItemList` column, if you break out the array to one row per product map, there is some large data holes where:
    - The barcode is `NULL` and `description` is `NULL`
    - The barcode is `NULL` but a populated `description`

    <img src="images\Data Holes Receipts.png" width="25%" alt="Data Holes Recepits">
 - I also tested SUM(`quantityPurchased`) from the Unnested `rewardsReceiptItemList` array to see if the sum of products would align with the `purchasedItemCount` field inside of the base file, and there was some misalignment within that file
    - In this example, `purchasedItemCoumt` is the number in the base file, and `total_quantity_purchased` is the sum of the `quantityPurchased` field inside of the product map within `rewardsReceiptItemList`
    - I subtracted `purchasedItemCount` from `total_quantity_purchased` to see the `quantity_difference`. Most of them were accurate, but there were a handful that weren't aligned, and a few records with as much as a discrepancy of 10 items

    <img src="images\quantity purchased.png" width="30%" alt="quantity purchased">

    <img src="images\quantity aggregate.png" width="20%" alt="quantity purchased">

**`brands.json.gz`**
 - There was a lot of `NULL` values within the brand dataframe in general. This was particularly bad within categoryCode which had 650 NULL values out of 1167 records total. Additionally, brandCode had 234 NULL values within 1167 records
 - There are more `NULL` values for `brandCode` than `name` which is an issue if brandCode could be a more important key, and names are usually not good keys to use
 - There are more `NULL` values for `categoryCode` than `category`. Again this is the same issue that the code/ id should not be having more NULL's than the name/ descriptor field.
 - Within the `cpg` column, the dictionary/ map had an inconsistent key called `'$ref'` which would either have:
    - `Cogs`
    - `Cpgs`
    - A missing `'$ref'` key:value pair entirely
 - This `'$ref'` key seems very important to identify what source the main `'$id'` comes from - since there may be different kinds of ID's relating to CPG categories
 - `topBrand` does have a large amount of NULLs, which isn't a huge data issue since that won't really link to any attribution problems, and seems to be a descriptive feature of the brands, but 612 Null values out of 1167 is a lot. A potential work around could be assuming all NULL values are just False, since there are likely very few "Top Brands" and they could be more easily marked off, but that's very much just a suspicion.

## Fourth: Communicate with Stakeholders

### Construct an email or slack message that is understandable to a product or business leader who isn’t familiar with your day to day work. This part of the exercise should show off how you communicate and reason about data with others.

 - What questions do you have about the data?
 - How did you discover the data quality issues?
 - What do you need to know to resolve the data quality issues?
 - What other information would you need to help you optimize the data assets you're trying to create?
 - What performance and scaling concerns do you anticipate in production and how do you plan to address them?
***
**Subject: Summary of Initial Data Quality Analysis and Next Steps**

Dear [Business Leader's Name],


I hope this email finds you well. Following our recent data assessments, I've compiled a detailed review of key data quality issues across our datasets. For each topic, I have outlined the challenges we ran into and what information we will need to proceed with ingesting the provided data. I have also included some preliminary recommendations for how we could handle these challenges.

1. **Inconsistencies in Receipts Data**
There are occasional discrepancies between the purchasedItemCount field provided to us, and the added quantityPurchased values, with some receipts showing up to 10 items not accounted for.

    - **Information Needed:** Could you provide insight into how these figures are tracked and reported at the transaction level? Knowing which field should serve as the source of truth for analytics is crucial.

     - **Proposed Solution:** We need to align on a source of truth for recording the number of items on each receipt if discrepancies between purchasedItemCount and total_quantityPurchased arise.

2. **Null Values in Brand Data**
There is a high incidence of nulls in brandCode (234) and categoryCode (650) out of 1167 records.

     - **Information Needed:** How critical are these codes for your team's data analysis, and what are the fallbacks when data is unavailable?

     - **Proposed Solution:** If these fields are not critical, we can create a default mapping as a quick fix for missing entries to enhance data completeness. Otherwise, we should review steps to improve the data feed quality.

3. **CPG Category Identification Issues in Brand Data**
The cpg column's reference key varies between 'Cogs', 'Cpgs', or is missing entirely. Proper differentiation of these references is needed.

     - **Information Needed:** Could your team share the significance and origin of the cpg column's reference key, and how it is generated?

     - **Proposed Solution:** Standardizing these entries to not rely on the reference key would be ideal. If the reference key is crucial, please share how your team utilizes these so we can align our data processing methods.

4. **Handling of topBrand Null Values**
A significant number of nulls in the topBrand column (612 out of 1167) may impact brand categorization. 

     - **Proposed Solution:** I would recommend defaulting all missing topBrand values to 0 and explicitly marking top brands as 1. This simplification will aid in maintaining data integrity and simplify analysis.


Addressing these issues will significantly enhance our data quality and the reliability of our analytics. I recommend we schedule a meeting to discuss these findings and refine our solutions further.
Please let me know your availability for a discussion, or if there are other areas you would like us to explore.

Thank you for your attention, and I look forward to your feedback.

Best regards,

Nicholas Martin

Senior Data Analyst
