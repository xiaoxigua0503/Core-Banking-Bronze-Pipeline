DECLARE update_columns STRING;
DECLARE insert_columns STRING;
DECLARE source_columns STRING;
DECLARE invalid_keys INT64;

FOR item IN (
    SELECT *
    FROM UNNEST([
        STRUCT('accounts' AS table_name, 'account_id' AS key_column),
        STRUCT('branches', 'branch_id'),
        STRUCT('cards', 'card_id'),
        STRUCT('channels', 'channel_id'),
        STRUCT('currencies', 'currency_code'),
        STRUCT('customers', 'customer_id'),
        STRUCT('merchants', 'merchant_id'),
        STRUCT('products', 'product_id'),
        STRUCT('transaction_status_history', 'event_id'),
        STRUCT('transaction_types', 'transaction_type_id'),
        STRUCT('transactions', 'transaction_id')
    ])
    WHERE table_name IN UNNEST(@tables)
)
DO
    -- Dừng nếu khóa staging bị null hoặc trùng.
    EXECUTE IMMEDIATE FORMAT(
        '''
        SELECT COUNT(*)
        FROM (
            SELECT `%s`
            FROM `{project_id}.{dataset_id}.stg_%s`
            GROUP BY `%s`
            HAVING `%s` IS NULL OR COUNT(*) > 1
        )
        ''',
        item.key_column,
        item.table_name,
        item.key_column,
        item.key_column
    )
    INTO invalid_keys;

    ASSERT invalid_keys = 0
        AS 'Staging có khóa null/trùng. Kiểm tra dữ liệu trước khi MERGE.';

    -- Kiểm tra cả khóa trong bảng đích.
    EXECUTE IMMEDIATE FORMAT(
        '''
        SELECT COUNT(*)
        FROM (
            SELECT `%s`
            FROM `{project_id}.{dataset_id}.%s`
            GROUP BY `%s`
            HAVING `%s` IS NULL OR COUNT(*) > 1
        )
        ''',
        item.key_column,
        item.table_name,
        item.key_column,
        item.key_column
    )
    INTO invalid_keys;

    ASSERT invalid_keys = 0
        AS 'Bảng đích có khóa null/trùng. Kiểm tra dữ liệu trước khi MERGE.';

    SET (update_columns, insert_columns, source_columns) = (
        SELECT AS STRUCT
            STRING_AGG(
                IF(
                    column_name != item.key_column,
                    FORMAT('`%s` = S.`%s`', column_name, column_name),
                    NULL
                ),
                ', ' ORDER BY ordinal_position
            ),
            STRING_AGG(
                FORMAT('`%s`', column_name),
                ', ' ORDER BY ordinal_position
            ),
            STRING_AGG(
                FORMAT('S.`%s`', column_name),
                ', ' ORDER BY ordinal_position
            )
        FROM `{project_id}.{dataset_id}.INFORMATION_SCHEMA.COLUMNS`
        WHERE table_name = item.table_name
    );

    EXECUTE IMMEDIATE FORMAT(
        '''
        MERGE `{project_id}.{dataset_id}.%s` AS T
        USING `{project_id}.{dataset_id}.stg_%s` AS S
        ON T.`%s` = S.`%s`

        WHEN MATCHED THEN
            UPDATE SET %s

        WHEN NOT MATCHED THEN
            INSERT (%s)
            VALUES (%s)
        ''',
        item.table_name,
        item.table_name,
        item.key_column,
        item.key_column,
        update_columns,
        insert_columns,
        source_columns
    );
END FOR;