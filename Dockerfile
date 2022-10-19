FROM postgres:10.6
ENV POSTGRES_PASSWORD password
ENV POSTGRES_HOST localhost
ENV POSTGRES_PORT 5432
ENV POSTGRES_DB database
COPY gpdb.sql /docker-entrypoint-initdb.d/