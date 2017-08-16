#!/usr/bin/env python

import os
import sys
import re
import signal
from datetime import datetime
from optparse import OptionParser
import ConfigParser
import boto
import boto.ec2
from boto.ec2.connection import EC2Connection
 
parser = OptionParser(usage='%prog [options]',
		version='%prog 1.0.' + re.search('(\d+)', '$LastChangedRevision: 1 $').group(1)
		)

# parser.add_option("-V", "--verbose", action="store_true", dest="Verbose", default=False, help="Toggles printing extra information to the console [default: %default]")

parser.add_option("-S", "--simulate",
		action="store_true",
		dest="Simulate",
		default=False,
		help="Simulated run, no changed will be performed. [default: %default]")

parser.add_option("-K", "--keep",
		dest="Keep",
		default=7,
		help="Number of days the given snapshot to keep [default: %default]")

parser.add_option("-A", "--account",
		dest="Account",
		help="Account name: either PLATFORM or PS or FRANCHISE, DEV or UK3. Mandatory option",
		action="store")

parser.add_option("--pruneonly",
		action="store_true",
		dest="Pruneonly",
		default=False,
		help="Do pruning only, don't create new snapshots")

parser.add_option("--snaponly",
		action="store_true",
		dest="Snaponly",
		default=False,
		help="Do snapshotting only, don't prune")

parser.add_option("-X", "--exclude",
		dest="Excludes",
		help="Name tags of instances to be excluded from snapshotting, comma-separated",
		action="store")

		
(options, args) = parser.parse_args()

if options.Account is None:
	print "Account name is missing\n"
	parser.print_help()
	exit(-1)

if options.Keep < 2:
	print "Cowardly refusing to prune the latest snapshos. Exiting"
	parser.print_help()
	exit(-1)
	
if options.Simulate == True:
	print """DRY RUN: the "Simulate" option has been selected. Performing a dry run. No changes will be made.
Working on account %s
	
	""" % options.Account

def email(SUBJ, TEXT):
    SERVER = 'smtp.gmail.com'
    FROM = 'opsteam@syncapse.com'
    TO = 'v.gupta@syncapse.com'
    SUBJECT = SUBJ
    
    from time import strftime
    TIMESTAMP = strftime("%Y-%m-%d %H:%M")
    cmd = "/usr/bin/fortune -sa"
    FORT = os.popen(cmd).read()
        
    message = """\
From: %s
To: %s
Subject: %s

Message from Snapshotting script. 
The time is %s EDT

%s

""" % (FROM, TO, SUBJ, TIMESTAMP, TEXT)
    
    server = smtplib.SMTP(SERVER)
    server.sendmail(FROM, TO, message)
    server.quit

def date_compare(snap1, snap2):
    if snap1.start_time < snap2.start_time:
        return -1
    elif snap1.start_time == snap2.start_time:
        return 0
    return 1

def prune_create_snapshots():
	# this gets all reservation ids:
	tInstances = conn.get_all_instances()
	for oInstances in tInstances:
		# iterate over al instance ids:
		for oInstance in oInstances.instances:
			sId = oInstance.id
			sState = oInstance.state
			tTags = oInstance.tags
			if tTags.has_key('Name'):
				sInstanceName = tTags["Name"]
			else:
				sInstanceName = "no_name"
			
			# Skip the snapshotting if the instance is in exclude list
			if options.Excludes:
				excludes = options.Excludes.split(',')
				if sInstanceName in excludes:
					print """Volumes belonging to the instance %s, named "%s" are EXCLUDED from snapshotting as per command-line option\n""" % (oInstance, sInstanceName)
					break
			

			# iterate over all volumes of the given instance, check the volume, prune old snapshots and create a new one.	
			for key, value in oInstance.block_device_mapping.items():
				tstamp = datetime.today()
				
				description = "SNAP:%s:%s:%s:%s" % (sInstanceName, sId, key, value.volume_id)
				
				# find snapshots of the given volume id:	
				volumes = conn.get_all_volumes([value.volume_id])
				volume = volumes[0]
				snapshots = volume.snapshots()
				# snapshot = snapshots[0]
				
				snapshots.sort(date_compare)
				delta = len(snapshots) - int(options.Keep)
				# TODO: find a balance between number of snapshots to keep and the age of oldest snapshot.	
				if delta > 1:
					print "Going to prune snapshots of volume %s that are older than %s days" % (value.volume_id, options.Keep)
					for i in range(delta):
						if re.search("Created by CreateImage", snapshots[i].description):
							print "Skipping pruning manually created snapshot \"%s\" " % snapshots[i].description
						else:	
							print 'Deleting %s described as "%s"' % (snapshots[i], snapshots[i].description)
							if options.Simulate:
								print "Skipping deleting %s since the \"Simulate\" option was chosen" % snapshots[i]
							elif options.Snaponly == True:
								print "Skipping deleting %s since the \"Snapshotonly\" option was chosen" % snapshots[i]
							else:
								try:
									snapshots[i].delete()
								except:
									print 'Could not delete %s: ERR: %s' % (snapshots[i], sys.exc_info()[1])
				else:
					print "No snapshots to prune for %s" % description

				# Done with pruning, let's start snapshotting, yeah!:

				print "Creating snapshot: %s" % description
				if options.Simulate:
					print "Skipping creating snapshot for %s since the \"Simulate\" option was selected" % description
				elif options.Pruneonly == True:
					print "Skipping creating snapshot for %s since the \"Pruneonly\" option was selected" % description
				else:
					conn.create_snapshot(value.volume_id, description)	
				print
					

# Main Program
if __name__ == "__main__":
	
	# Get AWS config
	config = ConfigParser.ConfigParser()
	config.read('configs/boto.cfg')

	# connect to ec2
	key = config.get(options.Account, "aws_access_key_id")
	secret = config.get(options.Account, "aws_secret_access_key")

	try:
		conn = EC2Connection(key, secret)
	except:
		print "Could not connect to the account %s. Error %s" % (options.Account, sys.exc_info()[1])
		sys.exit(-1)

	try:
		prune_create_snapshots()	
	except KeyboardInterrupt:
		print "Ctr+C was pressed. Exiting"
		sys.exit(-1)
	
