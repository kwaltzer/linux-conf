#!/usr/bin/env bash
# Java opts setting files
# This file should be used with caution ; be sure to understand the flags before using them !
# No configuration is magic, no configuration is eternal.

# Platform :
# - local is when running the application locally (dev machine)
# - dev is when running the application on dev platforms (integration, ...)
# - prod is when running the application in production
PTF="local" # dev, prod

# Activated profiles. Each profile is defined by a function.
function profiles {
	basic
	ssl
	debug
	#profile
	monitoring
	tuning
}

# Variables
CERT_FOLDER="${pwd}"
LOG_FOLDER="/var/log/application"

# Note: more info for -D options: 
# http://www.mindspring.com/~mgrand/java-system-properties.htm

# Other note: -XX:+UnlockExperimentalVMOptions


function basic {
	# Force server-mode VM (theoricaly already set by default on server-class machines)
	add "-server"

	# Basic memory configuration ; for more, see tuning()
	#add -Xms32m
	add -Xmx512m
	#add -Xss1M
	#add -XX:MaxPermSize=256m

	# Disable System.gc() calls.
	add -XX:+DisableExplicitGC

	# Network config
	# http://docs.oracle.com/javase/7/docs/technotes/guides/net/properties.html
	add -Djava.net.preferIPv4Stack=true
}

function ssl {
	# SSL configuration
	# http://docs.oracle.com/javase/7/docs/technotes/guides/security/jsse/JSSERefGuide.html
	add -Djavax.net.ssl.keyStore=$CERT_FOLDER/keystore.p12
	add -Djavax.net.ssl.keyStoreType=PKCS12
	add -Djavax.net.ssl.keyStorePassword=password # Caution: will be seen by any "ps aux"
	add -Djavax.net.ssl.trustStore=$CERT_FOLDER/truststore.jks
	add -Djavax.net.ssl.trustStoreType=JKS
	add -Djavax.net.ssl.trustStorePassword=password # Caution: will be seen by any "ps aux"
	add -Djavax.net.debug=ssl,handshake
	# Note: uncomment following to get more info (warn: force vm to exit)
	#add -Djavax.net.debug=help
}

function debug {
	# Required for some of the next options
	add -XX:+UnlockDiagnosticVMOptions

	# Print flags
	add -XX:+PrintFlagsFinal

	# See effect of internal string cache (at VM shutdown)
	add -XX:+PrintStringTableStatistics

	# Expert: Hotspot compiler main diagnosis functions
	#add -XX:+PrintCompilation
	#add -XX:+LogCompilation # Optional: -XX:LogFile=hotspot.log

	# Sample JPDA settings for remote socket debugging
	# Note: execute "java -agentlib:jdwp=help" for more options
	# Note bis: -Xdebug -Xrunjdwp is deprecated in java 1.5+
	case "$PTF" in
	"local")
		add -agentlib:jdwp=transport=dt_shmem,server=y,suspend=n
	;;
	"dev")
		add -agentlib:jdwp=transport=dt_socket,address=localhost:8787,server=y,suspend=n,timeout=5000
	;;
	esac
}

function profile {
	# Activate jmc profiler (JRE 7u45+)
	add -XX:+UnlockCommercialFeatures -XX:+FlightRecorder

	# Hprof help
	#add -Xrunhprof:help
}

function monitoring {
	# GC Log configuration	
	case "$PTF" in
	"local")
		# For "local", don't externalize gc logs (put them in the console output)
		add -verbose:gc -XX:+PrintGCTimeStamps
		add -XX:+PrintGCDetails
		add -XX:+PrintGCApplicationStoppedTime # Print GC pauses duration
		add -XX:+PrintTenuringDistribution # Useful to detect premature promotion
	;;
	"dev" | "prod")
		add -Xloggc:$LOG_FOLDER/gc/gc.log
		add -XX:+UseGCLogFileRotation
		add -XX:NumberOfGCLogFiles=10
		add -XX:GCLogFileSize=10M #X(K,M,G)
		add -XX:+PrintGCDetails
		add -XX:+PrintGCApplicationStoppedTime # Print GC pauses duration
	;;
	esac

	# Get heapdump on error
	add -XX:+HeapDumpOnOutOfMemoryError
	
	# JMX configuration
	# http://docs.oracle.com/javase/7/docs/technotes/guides/management/agent.html
	add -Dcom.sun.management.jmxremote # Not required if JRE 6+
	case "$PTF" in
	"local")
		# Nothing to do for shared jmx for local usage
	;;
	"dev")
		add -Dcom.sun.management.jmxremote.port=9999
		add -Dcom.sun.management.jmxremote.authenticate=false
		add -Dcom.sun.management.jmxremote.ssl=false
	    add -Dcom.sun.management.jmxremote.local.only=false
	;;
	"prod")
		# Note: instead of setting all the properties here, you can use the management config file :
		# add -Dcom.sun.management.config.file=$JRE_HOME/lib/management/management.properties
		add -Dcom.sun.management.jmxremote.port=9999
		add -Dcom.sun.management.jmxremote.authenticate=true
		add -Dcom.sun.management.jmxremote.password.file=$JRE_HOME/lib/management/jmxremote.password
		add -Dcom.sun.management.jmxremote.access.file=$JRE_HOME/lib/management/jmxremote.access
		add -Dcom.sun.management.jmxremote.ssl=true # by default
		add -Dcom.sun.management.jmxremote.ssl.need.client.auth=false
		add -Dcom.sun.management.jmxremote.local.only=false
	;;
	esac 
}

function tuning {
	# @see http://www.techpaste.com/2012/02/22/java-command-line-options-jvm-performance-improvement/#more-3585

	# Memory pools tuning
	#add -Xmn256m # Note: same as setting -XX:NewSize=64m -XX:MaxNewSize=64m
	#add -XX:NewSize=64m -XX:MaxNewSize=256m # Set either Xmn, or these two, but not all at the same time
	#add -XX:SurvivorRatio=2
	# With parallel collectors only, adapt survivor & eden size automatically :
	#add -XX:UseAdaptativeSizePolicy # Note: use -XX:+PrintFlagsFinal to see if activated by default or not

	# Large pages support. Note: must be activated in the running OS (if supported)
	# Note bis: it can help to decrease swapping of Java app, as large pages are not swappable
	#add -XX:+UseLargePages
	#add -XX:LargePageSizeInBytes=<n>[g|m|k]

	# GC collectors ; do either 1) (for throughput-constrained applications) or 2) (for latency-constrained applications)

	# 1) Activate parallel collectors for better throughput
	# add -XX:+UseParallelGC -XX:+UseParallelOldGC 

	# 2) Activate CMS for a low-pause collector : Use ParNew for young gen and CMS for old gen
	add -XX:+UseParNewGC -XX:+UseConcMarkSweepGC
	add -XX:+CMSParallelRemarkEnabled
	# The following options can be used when gc pauses length are a strong constraint
	# Following 3 parameters are for setting pause goals for low pauses (but not guaranteed)
	#add -XX:MaxGCPauseMillis=N # Max gc pause goal for parallel GC
	#add -XX:GCTimeRatio=n # Max gc ratio goal (i.e. in business code / in gc) for parallel GC
	#add -XX:GCPauseIntervalMillis=100 # Min gc pauses interval goal
	# Allow the CMS gc to stop its concurrent phases to let the application run
	# Generally not recommended for multicore systems or large Java heaps, but can help to reduce GC pauses length.
	#add -XX:+CMSIncrementalMode -XX:+CMSIncrementalPacing

	# Concerning strings
	#add -XX:+UseStringCache # Note: use -XX:+PrintFlagsFinal to see if activated by default or not
	#add -XX:StringTableSize=10m # Note: useful if UseStringCache is on. Use -XX:+PrintStringTableStatistics to tune it
	#add -XX:+OptimizeStringConcat # Note: use -XX:+PrintFlagsFinal to see if activated by default or not
	# Note: -XX:+UseCompressedStrings was removed in jre 7+ (when activated, decreases memory usage but increases CPU usage)

	# Other tuning
	#add -XX:+AggressiveOpts # meta-flag for experimental performance tips ; changes for each version
	#add -XX:+UseCompressedOops # x64 only ; Note: use -XX:+PrintFlagsFinal to see if activated by default or not
	#add -XX:+UseBiasedLocking # Can improve performance if there is significant amounts of uncontended synchronization
}



#### End of configuration ####

# Helper Functions
function add {
  JAVA_OPTS="$JAVA_OPTS ${@}"
}

# Reset java options
JAVA_OPTS=""
# Main entry point
profiles
# Print result & exit
echo $JAVA_OPTS
export JAVA_OPTS




