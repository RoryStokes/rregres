#!/bin/bash
dropdb rregres
createdb rregres

for script in src/*.sql; do
    psql -U postgres -d rregres -f $script;
done
