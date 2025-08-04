-- This script creates a subscription on a user shard, connecting to the admin shard's publication.
-- It expects the following variables to be passed via psql's -v option:
-- sub_name: The name for the new subscription (e.g., 'user_db_sub').
-- pub_name: The name of the publication to subscribe to (e.g., 'main_pub').
-- conn_info: The connection string for the admin database.

-- drop if it exists first
DROP SUBSCRIPTION IF EXISTS :"sub_name";

CREATE SUBSCRIPTION :"sub_name"
    CONNECTION :'conn_info'
    PUBLICATION :"pub_name"
    WITH (
        copy_data = false,       
        create_slot = true,
        slot_name = :"sub_name",
        enabled = true           
    );