#!/bin/bash

psql --csv -v short_id="$(< temp1)" -f get_user_device_id.sql  aioi-prod_aurora-ro > device_id.csv
