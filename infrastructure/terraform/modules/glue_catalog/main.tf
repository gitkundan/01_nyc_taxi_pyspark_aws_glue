resource "aws_glue_catalog_database" "nyc" {
  name = var.database_name
}

resource "aws_glue_catalog_table" "bronze_trips" {
  name          = "bronze_trips"
  database_name = aws_glue_catalog_database.nyc.name
  table_type    = "EXTERNAL_TABLE"
  parameters = {
    classification = "parquet"
    EXTERNAL       = "TRUE"
  }
  storage_descriptor {
    location      = var.bronze_location
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    ser_de_info {
      name                  = "Parquet"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }
    dynamic "columns" {
      for_each = var.bronze_columns
      content {
        name = columns.value.name
        type = columns.value.type
      }
    }
  }
  dynamic "partition_keys" {
    for_each = [
      { name = "year", type = "int" },
      { name = "month", type = "int" },
      { name = "day", type = "int" }
    ]
    content {
      name = partition_keys.value.name
      type = partition_keys.value.type
    }
  }
}
