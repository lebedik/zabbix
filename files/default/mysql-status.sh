#!/bin/bash
/usr/bin/mysqladmin --silent \
--user=root \
--password=123456 \
extended-status 2>/dev/null | grep $1 |awk -F'|' '$2~/^ (Com_(delete|insert|replace|select|update)|Connections|Created_tmp_(files|disk_tables|tables)|Key_(reads|read_requests|write_requests|writes)|Max_used_connections|Qcache_(free_memory|hits|inserts|lowmem_prunes|queries_in_cache)|Questions|Slow_queries|Threads_(cached|connected|created|running)|Bytes_(received|sent)|Uptime) +/ { print int($3) }' | head -n 1

