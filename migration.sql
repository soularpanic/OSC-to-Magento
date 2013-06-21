/*delete from mag_restore_1.customer_entity;*/

insert into mag_restore_1.customer_entity (entity_id, email, is_active)
	select customers_id, customers_email_address, 1 from theretrofitsource_osc22.customers;