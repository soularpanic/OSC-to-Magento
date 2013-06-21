/*delete from mag_restore_1.customer_entity;*/

insert into mag_restore_1.customer_entity (entity_id, email, is_active, website_id, group_id, store_id, entity_type_id)
       select customers_id, customers_email_address, 1, 1, 1, 1, 1 from theretrofitsource_osc22.customers;


insert into mag_restore_1.customer_entity_varchar (entity_type_id, attribute_id, entity_id, value)
       select 1, 5, customers_id, customers_firstname from theretrofitsource_osc22.customers;

insert into mag_restore_1.customer_entity_varchar (entity_type_id, attribute_id, entity_id, value)
       select 1, 7, customers_id, customers_lastname from theretrofitsource_osc22.customers;
