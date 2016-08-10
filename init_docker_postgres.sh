#!/bin/bash

# this script is runned when the docker container is built
# it imports the base database structure and create the database for the tests

gosu postgres postgres --single <<- EOSQL
	CREATE USER root;
	CREATE DATABASE gis OWNER root ENCODING 'UTF-8' TEMPLATE template0;
	CREATE EXTENSION postgis; 
	CREATE EXTENSION hstore;
EOSQL