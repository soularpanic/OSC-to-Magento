/* Clear out existing customer data */
set sql_safe_updates=0;
truncate mag_restore_1.customer_address_entity_varchar;
truncate mag_restore_1.customer_address_entity;
truncate mag_restore_1.customer_entity_varchar;
truncate mag_restore_1.customer_entity;
set sql_safe_updates=1;

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

/* Migrate customer address core data */
insert into mag_restore_1.customer_address_entity (
		parent_id,
		entity_type_id,
		attribute_set_id,
		is_active)
	select customers_id, 2, 0, 1 from theretrofitsource_osc22.customers;

/* Migrate customer telephone number */
insert into mag_restore_1.customer_address_entity_varchar (
		entity_id,
		value, 
		attribute_id,
		entity_type_id)
	select cae.entity_id, c.customers_telephone, 31, 2
	from theretrofitsource_osc22.customers as c
		join mag_restore_1.customer_address_entity as cae
		where c.customers_id = cae.parent_id;
		