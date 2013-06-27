/* Clear out existing customer data */
set sql_safe_updates = 0;
delete from mag_restore_1.eav_attribute_set where attribute_set_name != 'Default';
truncate mag_restore_1.customer_address_entity_int;
truncate mag_restore_1.customer_address_entity_text;
truncate mag_restore_1.customer_address_entity_varchar;
truncate mag_restore_1.customer_address_entity;
truncate mag_restore_1.customer_entity_int;
truncate mag_restore_1.customer_entity_varchar;
truncate mag_restore_1.customer_entity;
set sql_safe_updates = 1;

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
	select customers_id, customers_email_address, 1, 1, 1, 1, 1
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
	select 'Legacy', 4;

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