# govpollingdb-postgres

This repo will create a docker image out of an SQL dump for use in our e2e testing setup. The created docker image is a base for the postgres database required by the [gov-polling-db](https://github.com/makerdao/gov-polling-db). These instructions assume you are already running the docker services from [The Governance Portal](https://github.com/makerdao/governance-portal-v2) and you have modified the database with your desired changes.

To update this docker image, follow these steps:

1. Attach to the running docker image:

```
docker exec -it <YOUR_CONTAINER_ID> /bin/bash
```

2. Dump the postgres database

```
pg_dump -U user database > gpdb.sql
```

3. Type `exit` to exit the container. Now copy the SQL file to this directory

```
docker cp <YOUR_CONTAINER_ID>:/gpdb.sql .
```

4. Build the new image

```
docker build -t makerdaodux/govpolldb-postgres ./
```

5. Push the image to dockerhub

```
docker push makerdaodux/govpolldb-postgres:latest
```
