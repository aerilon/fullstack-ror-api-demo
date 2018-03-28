#!/bin/sh

for var in AMAZON_ACCESS_KEY_ID \
	AMAZON_SECRET_KEY \
	AMAZON_ASSOCIATE_TAG_ID; do

	eval "val=\${${var}}"
	[ -n "${val}" ] || { echo "${var} not set"; exit 1; }
done

su postgresql -c 'pg_ctl start -D /home/postgresql/db'
su postgresql -c 'createuser -s root'
rake db:create
rake db:migrate
rails server
