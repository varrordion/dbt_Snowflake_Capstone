{% macro create_all_external_tables() %}

    {% set datasets = [
        ['supplier_data', 'supplier_data'],
        ['store_data', 'store_data'],
        ['product_data', 'product_data'],
        ['orders_data', 'orders_data'],
        ['employee_data', 'employee_data'],
        ['customer_data', 'customer_data'],
        ['campaign_data', 'campaign_data']
    ] %}

    {% for dataset in datasets %}
        
        {# Create the SQL query directly using string concatenation to avoid scoping bugs #}
        {% set sql = "CREATE OR REPLACE EXTERNAL TABLE " ~ target.schema ~ ".ext_" ~ dataset[0] ~ " ( json_content VARIANT AS (value) ) LOCATION = @CT_VARNAN_DEWANGAN_DB.CAPSTONE.STAGE1/Capstone_Project_Data/" ~ dataset[1] ~ "/ FILE_FORMAT = (TYPE = 'JSON');" %}

        {{ log("Creating external table: ext_" ~ dataset[0], info=True) }}
        {% do run_query(sql) %}

    {% endfor %}

{% endmacro %}