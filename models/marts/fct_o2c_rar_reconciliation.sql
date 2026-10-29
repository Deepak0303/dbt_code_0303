select
    company_code,
    customer_id,
    cast(recognized_revenue_usd        as number(18,4)) as recognized_revenue_usd,
    cast(sales_order_open_amount_usd   as number(18,4)) as sales_order_open_amount_usd
from  fct_o2c_rar_reconciliation