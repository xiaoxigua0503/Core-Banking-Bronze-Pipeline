CREATE TABLE IF NOT EXISTS `{project_id}.{dataset_id}.accounts` (
    account_id INT64,
    account_number STRING,
    customer_id INT64,
    branch_id INT64,
    product_id INT64,
    currency_code STRING,
    account_status STRING,
    opened_at TIMESTAMP,
    closed_at TIMESTAMP,
    current_balance NUMERIC(18, 2),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `{project_id}.{dataset_id}.branches` (
    branch_id INT64,
    branch_code STRING,
    branch_name STRING,
    city STRING,
    region STRING,
    opened_date DATE,
    is_active BOOL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `{project_id}.{dataset_id}.cards` (
    card_id INT64,
    masked_card_number STRING,
    account_id INT64,
    card_type STRING,
    card_status STRING,
    issued_at TIMESTAMP,
    expired_at TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `{project_id}.{dataset_id}.channels` (
    channel_id INT64,
    channel_code STRING,
    channel_name STRING,
    is_active BOOL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `{project_id}.{dataset_id}.currencies` (
    currency_code STRING,
    currency_name STRING,
    decimal_places INT64,
    is_active BOOL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `{project_id}.{dataset_id}.customers` (
    customer_id INT64,
    customer_code STRING,
    full_name STRING,
    date_of_birth DATE,
    gender STRING,
    phone_number STRING,
    email STRING,
    city STRING,
    customer_segment STRING,
    kyc_status STRING,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `{project_id}.{dataset_id}.merchants` (
    merchant_id INT64,
    merchant_code STRING,
    merchant_name STRING,
    merchant_category STRING,
    city STRING,
    is_active BOOL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `{project_id}.{dataset_id}.products` (
    product_id INT64,
    product_code STRING,
    product_name STRING,
    product_type STRING,
    currency_code STRING,
    is_active BOOL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS
`{project_id}.{dataset_id}.transaction_status_history` (
    event_id INT64,
    transaction_id INT64,
    old_status STRING,
    new_status STRING,
    event_time TIMESTAMP,
    source_system STRING,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS
`{project_id}.{dataset_id}.transaction_types` (
    transaction_type_id INT64,
    transaction_type_code STRING,
    transaction_type_name STRING,
    is_active BOOL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `{project_id}.{dataset_id}.transactions` (
    transaction_id INT64,
    transaction_reference STRING,
    source_account_id INT64,
    destination_account_id INT64,
    card_id INT64,
    merchant_id INT64,
    branch_id INT64,
    channel_id INT64,
    transaction_type_id INT64,
    currency_code STRING,
    amount NUMERIC(18, 2),
    fee_amount NUMERIC(18, 2),
    status STRING,
    failure_reason STRING,
    transaction_time TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Tạo bảng staging theo schema của bảng chính.
FOR item IN (
    SELECT table_name
    FROM UNNEST([
        'accounts',
        'branches',
        'cards',
        'channels',
        'currencies',
        'customers',
        'merchants',
        'products',
        'transaction_status_history',
        'transaction_types',
        'transactions'
    ]) AS table_name
)
DO
    EXECUTE IMMEDIATE FORMAT(
        '''
        CREATE TABLE IF NOT EXISTS
        `{project_id}.{dataset_id}.stg_%s`
        LIKE `{project_id}.{dataset_id}.%s`
        ''',
        item.table_name,
        item.table_name
    );
END FOR;