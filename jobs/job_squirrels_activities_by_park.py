from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, split, explode

spark = SparkSession.builder \
    .appName("JobSquirrelsActivities") \
    .getOrCreate()

df_squirrels = spark.read.table("playground.squirreldb.squirrels").alias("s")
df_parks = spark.read.table("playground.squirreldb.parks").alias("p")

df_parks_group_by_squirrel_colors = (
    df_parks.join(df_squirrels, col("p.Park_ID") == col("s.Park_ID"), "inner")
    .select(
        "p.Park_Name", "p.Park_ID", "p.Number_of_Squirrels", "p.Park_Conditions",
        explode(split("s.Activities", ", ").alias("Activities"))
    )
    .groupBy("p.Park_Name", "p.Park_ID", "p.Number_of_Squirrels", "p.Park_Conditions", "col")
    .agg(((count("*") / col("p.Number_of_Squirrels") * 100)).alias("Percentage"))
)

df_parks_group_by_squirrel_colors.write.insertInto(
    "playground.squirreldb.squirrels_activities_by_park", True
)
