#!/usr/bin/env nu

print "Content-Type: application/json\n"

print ({hello: world} | to json -r)
