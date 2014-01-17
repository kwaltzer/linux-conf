# Java opts setting files

CERT_FOLDER="${pwd}"
LOG_FOLDER="/var/log/application"

PTF="local" # dev, prod

function profiles {
	basic
	ssl
	tuning
	debug
	#profile
	monitoring
}

# Note: ref
# http://www.mindspring.com/~mgrand/java-system-properties.htm


function basic {
	# Force server-mode VM
	add "-server"

	# Basic memory configuration ; for more, see tuning()
	#add -Xms32m
	add -Xmx512m
	#add -XX:MaxPermSize=256m

	# Network config
	# http://docs.oracle.com/javase/7/docs/technotes/guides/net/properties.html
	add -Djava.net.preferIPv4Stack=true

}

function ssl {
	# SSL configuration
	# http://docs.oracle.com/javase/7/docs/technotes/guides/security/jsse/JSSERefGuide.html
	add -Djavax.net.ssl.keyStore=$CERT_FOLDER/keystore.p12
	add -Djavax.net.ssl.keyStoreType=PKCS12
	add -Djavax.net.ssl.keyStorePassword=coucou
	add -Djavax.net.ssl.trustStore=$CERT_FOLDER/truststore.jks
	add -Djavax.net.ssl.trustStoreType=JKS
	add -Djavax.net.ssl.trustStorePassword=coucou
	add -Djavax.net.debug=ssl,handshake
	# Note: uncomment following to get more info (warn: force vm to exit)
	#add -Djavax.net.debug=help
}

function tuning {
	# Memory tuning
	#add -XX:UseAdaptativeSizePolicy
	#add -XX:NewSize=64m
	#add -XX:MaxNewSize=256m
	#add -XX:SurvivorRatio=2

	# Activate CMS (low-pause collector)
	add -XX:+UseParNewGC
	add -XX:+UseConcMarkSweepGC
	add -XX:+CMSParallelRemarkEnabled

	# Other tuning
	add -XX:+OptimizeStringConcat
	add -XX:+UseCompressedStrings
	add -XX:+UseCompressedOops #x64 only
}

function debug {
	# Print flags
	add -XX:+UnlockDiagnosticVMOptions -XX:+PrintFlagsFinal

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
}

function monitoring {
	# GC Log configuration	
	case "$PTF" in
	"dev" | "prod")
		add -Xloggc:$LOG_FOLDER/gc/gc.log
		add -XX:+UseGCLogFileRotation
		add -XX:NumberOfGCLogFiles=10
		add -XX:GCLogFileSize=10M #X(K,M,G)
		add -XX:+PrintGCDetails
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




