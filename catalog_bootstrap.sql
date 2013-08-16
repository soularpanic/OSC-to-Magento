set @migrate_flag = 'FLAG';
set @product_entity_type_id = 4;

set @name_attr = 'name';
set @price_attr = 'price';
set @status_attr = 'status';
set @visibility_attr = 'visibility';
set @long_desc_attr = 'description';
set @short_desc_attr = 'short_description';
set @whats_included_attr = 'whats_included';
set @technical_details_attr = 'technical_addl';
set @compatibility_attr = 'compatibility_addl';
set @weight_attr = 'weight';

drop temporary table if exists mag_attributes;
create temporary table mag_attributes as (
	select attribute_id,
		attribute_code
	from MAGENTO_DB.eav_attribute
		where entity_type_id = @product_entity_type_id);

drop temporary table if exists type_map;
create temporary table type_map (
	osc_type varchar(255),
	mag_attribute varchar(255),
	mag_category varchar(255));
insert into type_map values
	('accessories',				'TRSDefault',	'accessories'),
	('complete-retrofit-kits',	'RetroKit',		'complete-retrofit-kits'),
	('hid-component-kits',		'HIDSystem',	'hid-systems'),
	('hid-systems',				'HIDSystem',	'hid-systems'),
	('off-road-lighting',		'TRSDefault',	'trs-root'),
	('hid-bulbs',				'Bulbs',		'bulbs'),
	('hid-projectors',			'Projectors',	'projectors'),
	('projector-shrouds',		'Shrouds',		'shrouds'),
	('hid-ballasts',			'Ballasts',		'ballasts'),
	('relay-harnesses',			'Harnesses',	'harnesses'),
	('clear-lenses',			'Lenses',		'lenses'),
	('bargain-basement',		'TRSDefault',	'closeouts');
	
drop temporary table if exists osc_products;
create temporary table osc_products as (
	select p.products_id,
		pd.products_name,
		p.products_model,
		pd.products_description,
		pd.products_short_description,
		pd.products_whats_included,
		pd.products_compatibility,
		pd.products_tech_specs,
		p.products_image,
		p.products_image_med,
		p.products_image_pop,
		p.products_price,
		p.products_weight,
		substring_index(substring_index(p.products_image, '/', -2), '/', 1) as product_type
	from OSC_DB.products as p
		join OSC_DB.products_description as pd
			on p.products_id = pd.products_id
	where p.products_model is not null and p.products_model != '');

set sql_safe_updates = 0;
delete from MAGENTO_DB.catalog_product_entity
	where sku like concat('%', @migrate_flag);
set sql_safe_updates = 1;

insert into MAGENTO_DB.catalog_product_entity (
		sku,
		attribute_set_id,
		type_id,
		entity_type_id,
		has_options,
		required_options,
		created_at,
		updated_at)
	select 
		concat_ws('-', op.product_type, op.products_name, @migrate_flag),
		eas.attribute_set_id,
		'simple',
		@product_entity_type_id,
		0,
		0,
		now(),
		now()
	from osc_products as op
		join type_map as cm
			on op.product_type = cm.osc_type
		join MAGENTO_DB.eav_attribute_set as eas
			on cm.mag_attribute = eas.attribute_set_name;


drop temporary table if exists products_bridge;
create temporary table products_bridge as (
	select
		cpe.entity_id,
		cpe.sku,
		cpe.attribute_set_id,
		ccev.entity_id as category_id,
		op.*
	from osc_products as op
		join MAGENTO_DB.catalog_product_entity as cpe
			on concat_ws('-', op.product_type, op.products_name, @migrate_flag) = cpe.sku
		join type_map as cm
			on op.product_type = cm.osc_type
		join MAGENTO_DB.catalog_category_entity_varchar as ccev
			on cm.mag_category = ccev.value and ccev.attribute_id = 43);

insert into MAGENTO_DB.catalog_category_product (
		product_id,
		category_id,
		position)
	select entity_id,
		category_id,
		1
	from products_bridge;

/* Migrate product name */
insert into MAGENTO_DB.catalog_product_entity_varchar (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select products_name,
		ma.attribute_id,
		entity_id,
		@product_entity_type_id,
		0
	from products_bridge
		join mag_attributes as ma
			on ma.attribute_code = @name_attr;

/* Migrate product price */
insert into MAGENTO_DB.catalog_product_entity_decimal (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select products_price, 
		ma.attribute_id,
		entity_id,
		@product_entity_type_id,
		0
	from products_bridge
		join mag_attributes as ma
			on ma.attribute_code = @price_attr;

/* Migrate product status */
insert into MAGENTO_DB.catalog_product_entity_int (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select 1, 
		ma.attribute_id,
		entity_id,
		@product_entity_type_id,
		0
	from products_bridge
		join mag_attributes as ma
			on ma.attribute_code = @status_attr;

/* Migrate product visibility */

# This block makes legacy products visible in the product grid, but it does not 
# seem to affect their appearance in orders, which is what we care about.

insert into MAGENTO_DB.catalog_product_entity_int (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select 1,
		ma.attribute_id,
		entity_id,
		@product_entity_type_id,
		0
	from products_bridge
		join mag_attributes as ma
			on ma.attribute_code = @visibility_attr;

insert into MAGENTO_DB.catalog_product_entity_text (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select 
		products_description,
		ma.attribute_id,
		entity_id,
		@product_entity_type_id,
		0
	from products_bridge
		join mag_attributes as ma
			on ma.attribute_code = @long_desc_attr;

insert into MAGENTO_DB.catalog_product_entity_text (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select 
		products_short_description,
		ma.attribute_id,
		entity_id,
		@product_entity_type_id,
		0
	from products_bridge
		join mag_attributes as ma
			on ma.attribute_code = @short_desc_attr;

insert into MAGENTO_DB.catalog_product_entity_text (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select 
		products_whats_included,
		ma.attribute_id,
		entity_id,
		@product_entity_type_id,
		0
	from products_bridge
		join mag_attributes as ma
			on ma.attribute_code = @whats_included_attr;

insert into MAGENTO_DB.catalog_product_entity_text (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select 
		products_tech_specs,
		ma.attribute_id,
		entity_id,
		@product_entity_type_id,
		0
	from products_bridge
		join mag_attributes as ma
			on ma.attribute_code = @technical_details_attr;

insert into MAGENTO_DB.catalog_product_entity_text (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select 
		products_compatibility,
		ma.attribute_id,
		entity_id,
		@product_entity_type_id,
		0
	from products_bridge
		join mag_attributes as ma
			on ma.attribute_code = @compatibility_attr;

insert into MAGENTO_DB.catalog_product_entity_decimal (
		value,
		attribute_id,
		entity_id,
		entity_type_id,
		store_id)
	select 
		products_weight,
		ma.attribute_id,
		entity_id,
		@product_entity_type_id,
		0
	from products_bridge
		join mag_attributes as ma
			on ma.attribute_code = @weight_attr;
