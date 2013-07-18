set @legacy_product_category_name = 'Legacy';
set @magento_store_id = 1;

/* Clear out existing customer data */
set sql_safe_updates = 0;
truncate mag_restore_1.sales_flat_order_status_history;
truncate mag_restore_1.sales_flat_order_address;
truncate mag_restore_1.sales_flat_order;
truncate mag_restore_1.sales_flat_order_payment;
truncate mag_restore_1.sales_flat_order_grid;
delete from mag_restore_1.eav_attribute_set 
	where attribute_set_name = @legacy_product_category_name;
truncate mag_restore_1.customer_address_entity_int;
truncate mag_restore_1.customer_address_entity_text;
truncate mag_restore_1.customer_address_entity_varchar;
truncate mag_restore_1.customer_address_entity;
truncate mag_restore_1.customer_entity_int;
truncate mag_restore_1.customer_entity_varchar;
truncate mag_restore_1.customer_entity;
set sql_safe_updates = 1;

/***********
 * CUSTOMERS
 ***********/

/* Migrate customer core data */
insert into mag_restore_1.customer_entity (
		entity_id,
		email,
		is_active,
		website_id,
		group_id,
		store_id,
		entity_type_id)
	select customers_id, customers_email_address, 1, 1, 1, @magento_store_id, 1
	from theretrofitsource_osc22.customers;

/* Migrate customer first names */
insert into mag_restore_1.customer_entity_varchar (
		entity_type_id,
		attribute_id,
		entity_id,
		value)
	select 1, 5, customers_id, customers_firstname
	from theretrofitsource_osc22.customers;

/* Migrate customer last names */
insert into mag_restore_1.customer_entity_varchar (
		entity_type_id, 
		attribute_id,
		entity_id,
		value)
	select 1, 7, customers_id, customers_lastname
	from theretrofitsource_osc22.customers;

drop temporary table if exists osc_customer_addresses;
create temporary table osc_customer_addresses as (
	select ab.address_book_id,
			c.customers_id,
			c.customers_default_address_id,
			ab.entry_company,
			ab.entry_firstname,
			ab.entry_lastname,
			ab.entry_street_address,
			ab.entry_suburb,
			ab.entry_postcode,
			ab.entry_city,
			z.zone_name,
			z.zone_id,
			cn.countries_iso_code_2 as country_code,
			c.customers_telephone
	from theretrofitsource_osc22.address_book as ab
		join theretrofitsource_osc22.customers as c
			on ab.customers_id = c.customers_id
		join theretrofitsource_osc22.zones as z
			on ab.entry_zone_id = z.zone_id
		join theretrofitsource_osc22.countries as cn
			on ab.entry_country_id = cn.countries_id);

/* Migrate customer address core data */
insert into mag_restore_1.customer_address_entity (
		entity_id,
		parent_id,
		entity_type_id,
		attribute_set_id,
		is_active)
	select address_book_id, customers_id, 2, 0, 1 
	from osc_customer_addresses;

/* Address - First Name */
insert into mag_restore_1.customer_address_entity_varchar (
		value,
		attribute_id,
		entity_id,
		entity_type_id)
	select entry_firstname, 20, address_book_id, 2
	from osc_customer_addresses;

/* Address - Last Name */
insert into mag_restore_1.customer_address_entity_varchar (
		value,
		attribute_id,
		entity_id,
		entity_type_id)
	select entry_lastname, 22, address_book_id, 2
	from osc_customer_addresses;

/* Address - Company Name */
insert into mag_restore_1.customer_address_entity_varchar (
		value,
		attribute_id,
		entity_id,
		entity_type_id)
	select entry_company, 24, address_book_id, 2
	from osc_customer_addresses;

/* Address - Street */
insert into mag_restore_1.customer_address_entity_text (
		value,
		attribute_id,
		entity_id,
		entity_type_id)
	select concat_ws('\n', entry_street_address, nullif(entry_suburb, "")),
		25, address_book_id, 2
	from osc_customer_addresses;

/* Address - City */
insert into mag_restore_1.customer_address_entity_varchar (
		value,
		attribute_id,
		entity_id,
		entity_type_id)
	select entry_city, 26, address_book_id, 2
	from osc_customer_addresses;

/* Address - Zone/State */
insert into mag_restore_1.customer_address_entity_varchar (
		value,
		attribute_id,
		entity_id,
		entity_type_id)
	select zone_name, 28, address_book_id, 2
	from osc_customer_addresses;

/* Address - Country */
insert into mag_restore_1.customer_address_entity_varchar (
		value,
		attribute_id,
		entity_id,
		entity_type_id)
	select country_code, 27, address_book_id, 2
	from osc_customer_addresses;

/* Address - US, Canada State Dropdown */
insert into mag_restore_1.customer_address_entity_int (
		value,
		attribute_id,
		entity_id,
		entity_type_id)
	select zone_id, 29, address_book_id, 2
	from osc_customer_addresses
	where zone_id <= 78;

/* Address - Zip Code */
insert into mag_restore_1.customer_address_entity_varchar (
		value,
		attribute_id,
		entity_id,
		entity_type_id)
	select entry_postcode, 30, address_book_id, 2
	from osc_customer_addresses;

/* Address - Telephone number */
insert into mag_restore_1.customer_address_entity_varchar (
		value,
		attribute_id,
		entity_id,
		entity_type_id)
	select customers_telephone, 31, address_book_id, 2
	from osc_customer_addresses;

/* Associate customers' default addresses */
insert into mag_restore_1.customer_entity_int (
		value,
		attribute_id,
		entity_id,
		entity_type_id)
	select distinct customers_default_address_id, 13, customers_id, 1
	from osc_customer_addresses;

insert into mag_restore_1.customer_entity_int (
		value,
		attribute_id,
		entity_id,
		entity_type_id)
	select distinct customers_default_address_id, 14, customers_id, 1
	from osc_customer_addresses;

/***********
 * PRODUCTS
 ***********/

/* Create legacy product attribute set */
insert into mag_restore_1.eav_attribute_set (
		attribute_set_name,
		entity_type_id)
	select @legacy_product_category_name, 4;

set @legacy_attr_set_id = LAST_INSERT_ID();

insert into mag_restore_1.eav_attribute_group (
		attribute_set_id,
		attribute_group_name)
	select @legacy_attr_set_id, 'Legacy Attributes';

set @legacy_attr_set_grp_id = LAST_INSERT_ID();

insert into mag_restore_1.eav_entity_attribute (
		attribute_id,
		attribute_group_id,
		attribute_set_id,
		entity_type_id)
	select attribute_id, @legacy_attr_set_grp_id, @legacy_attr_set_id, 4
	from mag_restore_1.eav_attribute
		where entity_type_id = 4 and (attribute_code in ('name', 'price', 'status'));

drop temporary table if exists osc_products;
create temporary table osc_products as (
	select p.products_id,
			p.products_model,
			pd.products_name,
			p.products_price
	from theretrofitsource_osc22.products as p
		join theretrofitsource_osc22.products_description as pd
			on p.products_id = pd.products_id);

/* Migrate product core data */
insert into mag_restore_1.catalog_product_entity (
		entity_id,
		sku,
		entity_type_id,
		attribute_set_id,
		type_id
	)
	select products_id, products_model, 4, @legacy_attr_set_id, 'simple'
	from osc_products;

/* TODO - Why are these store ids 0 when the others are 1? */

/* Migrate product name */
insert into mag_restore_1.catalog_product_entity_varchar (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select products_name, 71, products_id, 4, 0
	from osc_products;

/* Migrate product name */
insert into mag_restore_1.catalog_product_entity_decimal (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select products_price, 75, products_id, 4, 0
	from osc_products;

/* Migrate product status */
insert into mag_restore_1.catalog_product_entity_int (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select 1, 96, products_id, 4, 0 
	from osc_products;

/* Migrate product visibility */
insert into mag_restore_1.catalog_product_entity_int (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select 1, 102, products_id, 4, 0
	from osc_products;

/**********
 * ORDERS
 **********/

/* Artisan, hand-crafted mapping between OSC and Magento statuses. */
drop temporary table if exists osc_to_magento_order_status;
create temporary table osc_to_magento_order_status (
	osc_status_id int,
	status varchar(32));
insert into osc_to_magento_order_status values
	(0, 'closed'),
	(1, 'pending'),
	(2, 'complete'),
	(3, 'holded'),
	(4, 'pending'),
	(5, 'fraud'),
	(6, 'pending'),
	(7, 'canceled'),
	(8, 'pending_paypal');

drop temporary table if exists osc_to_magento_payment_map;
create temporary table osc_to_magento_payment_map (
	osc_method varchar(255),
	magento_method varchar(255));
insert into osc_to_magento_payment_map values
	('PayPal Express Checkout', 'paypal_express'),
	('PayPal', 'paypal_express'),
	('PayPal Direct Payment', 'paypal_direct'),
	('Credit Card', 'paypal_direct');

drop temporary table if exists osc_to_magento_cc_type_map;
create temporary table osc_to_magento_cc_type_map (
	osc_cc_type varchar(20),
	magento_cc_type varchar(255));
insert into osc_to_magento_cc_type_map values
	('', ''),
	('Visa', 'VI'),
	('MasterCard', 'MC'),
	('Amex', 'AE'),
	('Discover', 'DI');

drop temporary table if exists osc_order_product_count;
create temporary table osc_order_product_count as (
	select orders_id, count(*) as product_count 
				from theretrofitsource_osc22.orders_products
				group by orders_id 
);
create index `orders_id` on osc_order_product_count(`orders_id`);

drop temporary table if exists osc_orders;
create temporary table osc_orders as (
	select o.orders_id,
		os.status as orders_status,
		o.date_purchased,
		o.last_modified,
		c.customers_id,
		ifnull(c.customers_firstname, substring(o.customers_name, 1, locate(' ', o.customers_name) - 1)) as customers_firstname, 
		ifnull(c.customers_lastname, substring(o.customers_name, locate(' ', o.customers_name) + 1))  as customers_lastname,
		o.customers_email_address as customers_email,
		o.customers_telephone,
		o.delivery_name,
		o.delivery_company,
		o.delivery_street_address,
		o.delivery_suburb,
		o.delivery_city,
		o.delivery_postcode,
		o.delivery_state,
		o.delivery_country,
		o.billing_name,
		o.billing_company,
		o.billing_street_address,
		o.billing_suburb,
		o.billing_city,
		o.billing_postcode,
		o.billing_state,
		o.billing_country,
		o_count.product_count,
		o.currency as currency_code,
		o.currency_value,
		o_total.value as order_total,
		o_shipping.value as order_shipping_cost,
		o_shipping.title as order_shipping_carrier,
		o_subtotal.value as order_subtotal,
		o_discount.value as order_discount,
		o_discount.title as order_discount_detail,
		o_tax.value as order_tax,
		o_refund.value as order_refund,
		o_insurance.value as order_insurance,
		o_signature.value as order_signature
	from theretrofitsource_osc22.orders as o
		join osc_to_magento_order_status as os
			on o.orders_status = os.osc_status_id
		left join theretrofitsource_osc22.customers as c
			on o.customers_id = c.customers_id
		left join osc_order_product_count as o_count
			on o.orders_id = o_count.orders_id
		left join theretrofitsource_osc22.orders_total as o_total
			on (o.orders_id = o_total.orders_id and o_total.class = 'ot_total')
		left join theretrofitsource_osc22.orders_total as o_shipping
			on (o.orders_id = o_shipping.orders_id and o_shipping.class = 'ot_shipping')
		left join theretrofitsource_osc22.orders_total as o_subtotal
			on (o.orders_id = o_subtotal.orders_id and o_subtotal.class = 'ot_subtotal')
		left join theretrofitsource_osc22.orders_total as o_discount
			on (o.orders_id = o_discount.orders_id and o_discount.class = 'ot_discount_coupon')
		left join theretrofitsource_osc22.orders_total as o_tax
			on (o.orders_id = o_tax.orders_id and o_tax.class = 'ot_tax')
		left join theretrofitsource_osc22.orders_total as o_refund
			on (o.orders_id = o_refund.orders_id and o_refund.class = 'ot_refund')
		left join theretrofitsource_osc22.orders_total as o_insurance
			on (o.orders_id = o_insurance.orders_id and o_insurance.class = 'ot_insurance')
		left join theretrofitsource_osc22.orders_total as o_signature
			on (o.orders_id = o_signature.orders_id and o_signature.class = 'ot_signature'));
create index `orders_id` on osc_orders(`orders_id`);

/*
 * The payments module was changed Nov, 2012, changing how order transations were recorded.
 */
drop temporary table if exists osc_order_history;
create temporary table osc_order_history as (
	select o.orders_id,
		osh.orders_status_history_id,
		os.status,
		osh.customer_notified,
		ctm.magento_cc_type as cc_type,
		o.cc_owner,
		replace(o.cc_number, 'X', '') as cc_last_four,
		nullif(substring(o.cc_expires, 1, 2), '') as cc_expire_month,
		concat(20, nullif(substring(o.cc_expires, 3, 2), '')) as cc_expire_year,
		o.last_modified as order_last_modified,
		o.date_purchased as order_date_purchased,
		osh.date_added,
		pm.magento_method as payment_method,
		osh.comments,
		osht.transaction_id,
		osht.transaction_type,
		osht.transaction_amount,
		osht.transaction_avs,
		osht.transaction_cvv2,
		osht.transaction_msgs
	from theretrofitsource_osc22.orders as o
		join osc_to_magento_payment_map as pm
			on o.payment_method = pm.osc_method
		join osc_to_magento_cc_type_map as ctm
			on o.cc_type = ctm.osc_cc_type
		join theretrofitsource_osc22.orders_status_history as osh
			on o.orders_id = osh.orders_id
		join osc_to_magento_order_status as os
			on osh.orders_status_id = os.osc_status_id
		left join theretrofitsource_osc22.orders_status_history_transactions as osht
			on osh.orders_status_history_id = osht.orders_status_history_id);
create index `orders_id` on osc_order_history(`orders_id`);

set sql_safe_updates = 0;
update osc_order_history ooh, theretrofitsource_osc22.orders o
	set ooh.transaction_id = o.paypal_txn_id,
		ooh.transaction_type = if(ooh.comments regexp '.*; \\$[0-9]+.*', 'CHARGE', 'REFUND'),
		ooh.transaction_amount = substring(comments, locate('; ', comments) + 3, locate(')', comments) - locate('; ', comments) - 3),
		ooh.transaction_avs = o.cc_avs_response,
		ooh.transaction_cvv2 = o.cc_cvv2_response,
		ooh.transaction_msgs = 'Post Nov 2013 PayPal Transaction'
	where ooh.orders_id = o.orders_id and ooh.comments regexp '.*; \\$-?[0-9]+\\.[0-9][0-9].*';

update osc_order_history ooh, theretrofitsource_osc22.orders o, osc_orders oo
	set ooh.transaction_id = o.paypal_txn_id,
		ooh.transaction_type = 'CHARGE',
		ooh.transaction_amount = oo.order_total,
		ooh.transaction_avs = o.cc_avs_response,
		ooh.transaction_cvv2 = o.cc_cvv2_response,
		ooh.transaction_msgs = 'Post Nov 2013 Credit Transaction'
	where ooh.order_date_purchased = ooh.date_added 
		and ooh.status = 'pending'
		and ooh.transaction_id is null
		and o.paypal_txn_id != ''
		and ooh.orders_id = o.orders_id
		and o.orders_id = oo.orders_id;
set sql_safe_updates = 1;

drop temporary table if exists osc_order_payments;
create temporary table osc_order_payments as (
	select o.orders_id,
		o.order_total,
		o.order_shipping_cost,
		o.order_insurance,
		o.order_signature,
		tx.status,
		tx.cc_type,
		tx.cc_owner,
		tx.cc_last_four,
		tx.cc_expire_month,
		tx.cc_expire_year,
		tx.order_last_modified,
		tx.order_date_purchased,
		tx.date_added,
		tx.payment_method,
		tx.comments,
		tx.transaction_id,
		tx.transaction_type,
		tx.transaction_amount,
		tx.transaction_avs,
		tx.transaction_cvv2,
		tx.transaction_msgs
	from osc_orders as o
		left join osc_order_history as tx
			on o.orders_id = tx.orders_id and tx.transaction_amount is not null);

/* Migrate order core details */
insert into mag_restore_1.sales_flat_order (
		entity_id,
		increment_id,
		status,
		store_id,
		created_at,
		updated_at,
		customer_id,
		customer_firstname,
		customer_lastname,
		customer_email,
		total_item_count,
		base_currency_code,
		global_currency_code,
		order_currency_code,
		store_currency_code,
		base_grand_total,
		grand_total,
		base_subtotal,
		subtotal,
		base_shipping_amount,
		shipping_amount,
		base_shipping_tax_amount,
		shipping_tax_amount,
		base_tax_amount,
		tax_amount,
		base_discount_amount,
		discount_amount,
		base_total_refunded,
		total_refunded)
	select orders_id,
		orders_id,
		orders_status,
		@magento_store_id,
		date_purchased,
		last_modified,
		customers_id,
		customers_firstname,
		customers_lastname,
		customers_email,
		product_count,
		currency_code,
		currency_code,
		currency_code,
		currency_code,
		order_total,
		order_total,
		order_subtotal,
		order_subtotal,
		order_shipping_cost,
		order_shipping_cost + ifnull(order_insurance, 0.0) + ifnull(order_signature, 0.0),
		0.0,
		0.0,
		order_tax,
		order_tax,
		order_discount,
		order_discount,
		order_refund,
		order_refund
	from osc_orders;

/* Migrate order summary details */
insert into mag_restore_1.sales_flat_order_grid (
		entity_id,
		increment_id,
		status,
		store_id,
		created_at,
		updated_at,
		customer_id,
		shipping_name,
		billing_name,
		base_currency_code,
		order_currency_code,
		base_grand_total,
		grand_total)
	select orders_id,
		orders_id,
		orders_status,
		@magento_store_id,
		date_purchased,
		last_modified,
		customers_id,
		delivery_name,
		billing_name,
		currency_code,
		currency_code,
		order_total,
		order_total
	from osc_orders;

/* Migrate order payment details */
insert into mag_restore_1.sales_flat_order_payment (
		parent_id,
		base_amount_ordered,
		amount_ordered,
		base_shipping_amount,
		shipping_amount,
		method,
		cc_type,
		cc_last4,
		cc_exp_month,
		cc_exp_year,
		base_amount_authorized,
		amount_authorized,
		last_trans_id)
	select orders_id,
		order_total,
		order_total,
		order_shipping_cost,
		order_shipping_cost + ifnull(order_insurance, 0.0) + ifnull(order_signature, 0.0),
		payment_method,
		cc_type,
		cc_last_four,
		cc_expire_month,
		cc_expire_year,
		transaction_amount,
		transaction_amount,
		transaction_id
	from osc_order_payments;

set sql_safe_updates = 0;
update mag_restore_1.sales_flat_order sfo, osc_order_payments payments
	set sfo.base_total_paid = payments.transaction_amount,
		sfo.total_paid = payments.transaction_amount
	where sfo.entity_id = payments.orders_id and payments.transaction_type = 'CHARGE';
set sql_safe_updates = 1;

/* Migrate order history */
insert into mag_restore_1.sales_flat_order_status_history (
		parent_id,
		entity_id,
		comment,
		status,
		created_at,
		is_customer_notified,
		entity_name)
	select orders_id,
		orders_status_history_id,
		comments,
		status,
		date_added,
		customer_notified,
		'order'
	from osc_order_history;

/* Migrate order shipping addresses */
insert into mag_restore_1.sales_flat_order_address (
		lastname,
		company,
		street,
		city,
		postcode,
		region,
		email,
		telephone,
		parent_id,
		address_type)
	select delivery_name,
		delivery_company,
		delivery_street_address,
		delivery_city,
		delivery_postcode,
		delivery_state,
		customers_email,
		customers_telephone,
		orders_id,
		'shipping'
	from osc_orders;

/* Migrate order billing addresses */
insert into mag_restore_1.sales_flat_order_address (
		lastname,
		company,
		street,
		city,
		postcode,
		region,
		email,
		telephone,
		parent_id,
		address_type)
	select billing_name,
		billing_company,
		billing_street_address,
		billing_city,
		billing_postcode,
		billing_state,
		customers_email,
		customers_telephone,
		orders_id,
		'billing'
	from osc_orders;