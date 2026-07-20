version: 2

models:
  - name: dim_store
    description: Store dimension with SCD2 history from snapshot_store.
    columns:

      - name: store_key
        description: Surrogate key, unique per SCD2 version of a store.
        data_tests:
          - unique
          - not_null

      - name: store_id
        description: Durable business key for the store.
        data_tests:
          - not_null

      - name: manager_id
        description: Foreign key to the employee managing this store.
        data_tests:
          - relationships:
              to: ref('dim_employee')
              field: employee_id

      - name: store_name
        data_tests:
          - not_null

      - name: store_size_category
        description: Size segment derived from size_sq_ft.
        data_tests:
          - accepted_values:
              values: ['Small', 'Medium', 'Large']

      - name: is_active
        data_tests:
          - accepted_values:
              values: [true, false]

      - name: has_performance_issue
        description: Flag derived from sales_target_achievement_percentage < 90%.
        data_tests:
          - accepted_values:
              values: [true, false]

      - name: is_current
        data_tests:
          - accepted_values:
              values: [true, false]