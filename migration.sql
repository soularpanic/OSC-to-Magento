set @legacy_product_category_name = 'Legacy';
set @magento_store_id = 1;

/* Clear out existing customer data */
set sql_safe_updates = 0;
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

drop temporary table if exists osc_to_magento_order_status;
drop temporary table if exists osc_orders;
drop temporary table if exists osc_customer_addresses;
drop temporary table if exists osc_products;

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
/*
select @legacy_attr_set_id := attribute_set_id
	from mag_restore_1.eav_attribute_set
	where attribute_set_name = 'Legacy';
*/
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

/* Migrate product name */
insert into mag_restore_1.catalog_product_entity_varchar (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select products_name, 71, products_id, 4, @magento_store_id
	from osc_products;

/* Migrate product name */
insert into mag_restore_1.catalog_product_entity_decimal (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select products_price, 75, products_id, 4, @magento_store_id
	from osc_products;

/* Migrate product status */
insert into mag_restore_1.catalog_product_entity_int (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select 1, 96, products_id, 4, @magento_store_id
	from osc_products;

/* Migrate product visibility */
insert into mag_restore_1.catalog_product_entity_int (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select 1, 102, products_id, 4, @magento_store_id
	from osc_products;

/**********
 * ORDERS
 **********/
create temporary table osc_to_magento_order_status (
	osc_status_id int,
	status varchar(32));
insert into osc_to_magento_order_status values
	(1, 'pending'),
	(2, 'complete'),
	(3, 'holded'),
	(4, 'pending'),
	(5, 'fraud'),
	(6, 'pending'),
	(7, 'canceled'),
	(8, 'pending_paypal');

create temporary table osc_orders as (
	select o.orders_id,
		os.status as orders_status,
		o.date_purchased,
		o.last_modified,
		o.customers_id,
		c.customers_firstname,
		c.customers_lastname,
		c.customers_email_address as customers_email,
		o.delivery_name,
		o.billing_name,
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
		join theretrofitsource_osc22.customers as c
			on o.customers_id = c.customers_id
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

insert into mag_restore_1.sales_flat_order_payment (
		parent_id,
		base_amount_ordered,
		amount_ordered,
		base_shipping_amount,
		shipping_amount)
	select orders_id,
		order_total,
		order_total,
		order_shipping_cost,
		order_shipping_cost + ifnull(order_insurance, 0.0) + ifnull(order_signature, 0.0)
	from osc_orders;