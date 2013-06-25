/* Clear out existing customer data */
set sql_safe_updates=0;
truncate mag_restore_1.customer_address_entity_varchar;
truncate mag_restore_1.customer_address_entity;
truncate mag_restore_1.customer_entity_varchar;
truncate mag_restore_1.customer_entity;
set sql_safe_updates=1;

drop temporary table if exists osc_customer_addresses;

/* Migrate customer core data */
insert into mag_restore_1.customer_entity (
		entity_id,
		email,
		is_active,
		website_id,
		group_id,
		store_id,
		entity_type_id)
	select customers_id, customers_email_address, 1, 1, 1, 1, 1 from theretrofitsource_osc22.customers;

/* Migrate customer first names */
insert into mag_restore_1.customer_entity_varchar (
		entity_type_id,
		attribute_id,
		entity_id,
		value)
	select 1, 5, customers_id, customers_firstname from theretrofitsource_osc22.customers;

/* Migrate customer last names */
insert into mag_restore_1.customer_entity_varchar (
		entity_type_id, 
		attribute_id,
		entity_id,
		value)
	select 1, 7, customers_id, customers_lastname from theretrofitsource_osc22.customers;

create temporary table osc_customer_addresses as (
	select ab.address_book_id,
			c.customers_id,
			ab.entry_company,
			ab.entry_firstname,
			ab.entry_lastname,
			ab.entry_street_address,
			ab.entry_suburb,
			ab.entry_postcode,
			ab.entry_city
	from theretrofitsource_osc22.address_book as ab
		join theretrofitsource_osc22.customers as c
		where ab.customers_id = c.customers_id);

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

/* Migrate customer telephone number */
/*
insert into mag_restore_1.customer_address_entity_varchar (
		entity_id,
		value, 
		attribute_id,
		entity_type_id)
	select cae.entity_id, c.customers_telephone, 31, 2
	from theretrofitsource_osc22.customers as c
		join mag_restore_1.customer_address_entity as cae
		where c.customers_id = cae.parent_id;
*/

