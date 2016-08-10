FROM ubuntu:14.04
MAINTAINER Molnar Tamas <tamas.molnar@webvalto.hu>

ENV LANG C.UTF-8
RUN update-locale LANG=C.UTF-8

RUN apt-get update -y
RUN apt-get install -y software-properties-common python-software-properties

RUN apt-get install -y libboost-dev libboost-filesystem-dev libboost-program-options-dev libboost-python-dev libboost-regex-dev libboost-system-dev libboost-thread-dev

RUN apt-get install -y subversion git-core tar unzip wget bzip2 build-essential autoconf libtool libxml2-dev libgeos-dev libpq-dev libbz2-dev munin-node munin libprotobuf-c0-dev protobuf-c-compiler libprotobuf-dev protobuf-compiler pkg-config libfreetype6-dev libpng12-dev libtiff4-dev libicu-dev libgdal-dev libcairo-dev libcairomm-1.0-dev apache2 apache2-dev libagg-dev liblua5.2-dev ttf-unifont

RUN apt-get install -y autoconf apache2-dev libtool libxml2-dev libbz2-dev libgeos-dev libgeos++-dev libproj-dev gdal-bin libgdal1-dev mapnik-utils python-mapnik libmapnik-dev curl node-carto


RUN apt-get -y install postgresql postgresql-contrib postgis postgresql-9.3-postgis-2.1 

USER postgres
RUN /etc/init.d/postgresql start \
    && psql --command "CREATE USER root;" \
    && createdb -T template0 -E UTF8 -O root gis \
	&& psql --command "CREATE EXTENSION postgis;CREATE EXTENSION hstore;" -d gis

USER root

# Ensure the webserver user can connect to the gis database
RUN sed -i -e 's/local   all             all                                     peer/local gis root peer/' /etc/postgresql/9.3/main/pg_hba.conf

# Tune postgresql
ADD postgresql.conf.sed /tmp/
RUN sed --file /tmp/postgresql.conf.sed --in-place /etc/postgresql/9.3/main/postgresql.conf

#Install osm2pgsql
RUN apt-get -y install osm2pgsql

#Install Mapnik
RUN mkdir ~/src && \
	cd ~/src && \
	git clone git://github.com/mapnik/mapnik && \
	cd mapnik && \
	git branch 2.2 origin/2.2.x && \
	git checkout 2.2 && \
	python scons/scons.py configure INPUT_PLUGINS=all OPTIMIZATION=3 SYSTEM_FONTS=/usr/share/fonts/truetype/ && \
	make && make install && ldconfig

RUN cd ~/src && \
	git clone git://github.com/openstreetmap/mod_tile.git && \
	cd mod_tile && \
	./autogen.sh && \
	./configure && \
	make && make install && make install-mod_tile && ldconfig

#Openstreetmap-carto
RUN mkdir -p /usr/local/share/maps/style && \
	cd /usr/local/share/maps/style && \ 
	git clone https://github.com/gravitystorm/openstreetmap-carto.git && \
	cd openstreetmap-carto/ && \
	./get-shapefiles.sh

RUN cd /usr/local/share/maps/style/openstreetmap-carto/ && carto project.mml > mapnik.xml

ADD renderd.conf /usr/local/etc/
RUN echo 'LoadModule tile_module /usr/lib/apache2/modules/mod_tile.so' >> /etc/apache2/conf-available/mod_tile.conf
ADD 000-default.conf /etc/apache2/sites-available/

# Create the files required for the mod_tile system to run
RUN mkdir /var/run/renderd && chown root /var/run/renderd
RUN mkdir /var/lib/mod_tile && chown root /var/lib/mod_tile

RUN a2enconf mod_tile
#RUN  service apache2 reload
RUN cd ~/src && \
	wget http://download.geofabrik.de/europe/hungary-latest.osm.pbf

RUN /etc/init.d/postgresql start && \
	osm2pgsql --create --slim --cache 1000 --number-processes 2 --hstore --style /usr/local/share/maps/style/openstreetmap-carto/openstreetmap-carto.style ~/src/hungary-latest.osm.pbf

RUN sudo cp  ~/src/mod_tile/debian/renderd.init /etc/init.d/renderd
RUN sudo chmod u+x /etc/init.d/renderd
RUN sed -i -e 's#DAEMON=/usr/bin/$NAME#DAEMON=/usr/local/bin/$NAME#g' /etc/init.d/renderd
RUN sed -i -e 's#DAEMON_ARGS=""#DAEMON_ARGS="-c /usr/local/etc/renderd.conf"#g' /etc/init.d/renderd

# Expose the webserver and database ports
EXPOSE 80 5432

# We need the volume for importing data from
VOLUME ["/data"]

#ENV DAEMON=/usr/local/bin/$NAME
#ENV DAEMON_ARGS="-c /usr/local/etc/renderd.conf"



COPY ./docker-entrypoint.sh /
RUN chmod +x docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]



