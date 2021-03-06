#!/bin/bash
set -e
rootDir=$quickstartRootDir
logDir="$rootDir/log"

# Predix Dev Bootstrap Script
# Authors: GE SDLP 2015
#
# Welcome new Predix Developers! Run this script to instantiate the following Predix
# services: Timeseries, Asset, and UAA. The script will also configure each service with
# the necessary authorities and scopes, create a UAA user, create UAA client id, and
# post sample data to the Asset service
#

source "$rootDir/bash/scripts/predix_funcs.sh"
source "$rootDir/bash/scripts/variables.sh"
source "$rootDir/bash/scripts/error_handling_funcs.sh"
source "$rootDir/bash/scripts/files_helper_funcs.sh"
source "$rootDir/bash/scripts/curl_helper_funcs.sh"

if ! [ -d "$logDir" ]; then
	mkdir "$logDir"
	chmod 744 "$logDir"
fi
touch "$logDir/quickstart.log"

# Trap ctrlc and exit if encountered
trap "trap_ctrlc" 2
#__append_new_head_log "Creating Predix Services" "#" "$logDir"

function pushAnAppForBinding()
{
	__append_new_head_log "Pushing an app to bind to Predix Services..." "-" "$logDir"

	# Push a test app to get VCAP information for the Predix Services
	getGitRepo "Predix-HelloWorld-WebApp"
	cd Predix-HelloWorld-WebApp

	if __echo_run px push $1 --random-route; then
		__append_new_line_log "App \"$1\" successfully pushed to CloudFoundry!" "$logDir"
	else
		if __echo_run px push $1 --random-route; then
			__append_new_line_log "App \"$1\" successfully pushed to CloudFoundry!" "$logDir"
		else
			__error_exit "There was an error pushing the app \"$1\" to CloudFoundry..." "$logDir"
		fi
	fi
}

function createUaa()
{
	__append_new_head_log "Create UAA Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
		 __try_delete_service $UAA_INSTANCE_NAME
	fi

	if [[ $USE_TRAINING_UAA == 1 ]]; then
		configParameters="{\"adminClientSecret\":\"$UAA_ADMIN_SECRET\"}"
		__try_create_service_using_cfcli $UAA_SERVICE_NAME $UAA_PLAN $UAA_INSTANCE_NAME $configParameters "Predix UAA"
	else
		# Create instance of Predix UAA Service
		__try_create_uaa $UAA_SERVICE_NAME $UAA_PLAN $UAA_INSTANCE_NAME $UAA_ADMIN_SECRET "Predix UAA"
	fi

	# Bind Temp App to UAA instance
	__try_bind $1 $UAA_INSTANCE_NAME

	# if uaaURL=$(px env $1 | grep predix-uaa* | grep uri*| awk 'BEGIN {FS=":"}{print "https:"$3}' | awk 'BEGIN {FS="\","}{print $1}' ); then
	#   if [[ "$uaaURL" == "" ]] ; then
	#     __error_exit "The UAA URL was not found for \"$1\"..." "$logDir"
	#   fi
	#   __append_new_line_log "UAA URL copied from environmental variables!" "$logDir"
	# else
	# 	__error_exit "There was an error getting the UAA URL..." "$logDir"
	# fi
}

function createTimeseries()
{
	__append_new_head_log "Create Time Series Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $TIMESERIES_INSTANCE_NAME
	fi

	if [[ "$TRUSTED_ISSUER_ID" == "" ]]; then
    getTrustedIssuerId $1
  fi

	if [[ $USE_TRAINING_UAA == 1 ]]; then
		configParameters="{\"trustedIssuerIds\":[\"$TRUSTED_ISSUER_ID\"]}"
		__try_create_service_using_cfcli $TIMESERIES_SERVICE_NAME $TIMESERIES_SERVICE_PLAN $TIMESERIES_INSTANCE_NAME $configParameters "Predix Timeseries"
	else
		# Create instance of Predix TimeSeries Service
		__try_create_predix_service $TIMESERIES_SERVICE_NAME $TIMESERIES_SERVICE_PLAN $TIMESERIES_INSTANCE_NAME $UAA_INSTANCE_NAME $UAA_ADMIN_SECRET $UAA_CLIENTID_GENERIC $UAA_CLIENTID_GENERIC_SECRET "Predix TimeSeries"
	fi

	# Bind Temp App to TimeSeries Instance
	__try_bind $1 $TIMESERIES_INSTANCE_NAME
}

function createACSService() {
	__append_new_head_log "Create Access Control Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $ACCESS_CONTROL_SERVICE_INSTANCE_NAME
	fi

	if [[ "$TRUSTED_ISSUER_ID" == "" ]]; then
		getTrustedIssuerId $1
	fi

	if [[ $USE_TRAINING_UAA == 1 ]]; then
		configParameters="{\"trustedIssuerIds\":[\"$TRUSTED_ISSUER_ID\"]}"
		__try_create_service_using_cfcli $ACCESS_CONTROL_SERVICE_NAME $ACCESS_CONTROL_SERVICE_PLAN $ACCESS_CONTROL_INSTANCE_NAME $configParameters "Predix Access Control Service"
	else
		# Create instance of Predix Access Control Service
		__try_create_predix_service $ACCESS_CONTROL_SERVICE_NAME $ACCESS_CONTROL_SERVICE_PLAN $ACCESS_CONTROL_SERVICE_INSTANCE_NAME $UAA_INSTANCE_NAME $UAA_ADMIN_SECRET $UAA_CLIENTID_GENERIC $UAA_CLIENTID_GENERIC_SECRET "Predix Access Control Service"
	fi

	# Bind Temp App to ACS Instance
	__try_bind $1 $ACCESS_CONTROL_SERVICE_INSTANCE_NAME

}

function createAssetService() {
	__append_new_head_log "Create Asset Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $ASSET_INSTANCE_NAME
	fi

	if [[ "$TRUSTED_ISSUER_ID" == "" ]]; then
    getTrustedIssuerId $1
  fi

	if [[ $USE_TRAINING_UAA == 1 ]]; then
		configParameters="{\"trustedIssuerIds\":[\"$TRUSTED_ISSUER_ID\"]}"
		__try_create_service_using_cfcli $ASSET_SERVICE_NAME $ASSET_SERVICE_PLAN $ASSET_INSTANCE_NAME $configParameters "Predix Asset Service"
	else
		# Create instance of Predix Asset Service
		__try_create_predix_service $ASSET_SERVICE_NAME $ASSET_SERVICE_PLAN $ASSET_INSTANCE_NAME $UAA_INSTANCE_NAME $UAA_ADMIN_SECRET $UAA_CLIENTID_GENERIC $UAA_CLIENTID_GENERIC_SECRET "Predix Asset"
	fi

	# Bind Temp App to Asset Instance
	__try_bind $1 $ASSET_INSTANCE_NAME

	# Get the Zone ID from the environment variables (for use when querying Asset data)
	if [[ "$ASSET_ZONE_ID" == "" ]]; then
    getAssetZoneId $1
  fi
}

function createMobileService() {
	__append_new_head_log "Create Mobile Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $MOBILE_INSTANCE_NAME
	fi

	# Create instance of Predix Mobile Service
	__try_create_predix_service $MOBILE_SERVICE_NAME $MOBILE_SERVICE_PLAN $MOBILE_INSTANCE_NAME $UAA_INSTANCE_NAME $UAA_ADMIN_SECRET \"\" \"\" "Predix Mobile"

	# Bind Temp App to Asset Instance
	#__try_bind $1 $MOBILE_INSTANCE_NAME

}

function createAnalyticFrameworkServiceInstance() {
	__append_new_head_log "Create Analytic Framework Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $ANALYTIC_FRAMEWORK_SERVICE_INSTANCE_NAME
	fi

	if [[ "$TRUSTED_ISSUER_ID" == "" ]]; then
	  getTrustedIssuerId $1
	fi

	if [[ $USE_TRAINING_UAA == 1 ]]; then
		configParameters="{\"trustedIssuerIds\":[\"$TRUSTED_ISSUER_ID\"]}"
		__try_create_service_using_cfcli $ANALYTIC_FRAMEWORK_SERVICE_NAME $ANALYTIC_FRAMEWORK_SERVICE_PLAN $ANALYTIC_FRAMEWORK_SERVICE_INSTANCE_NAME $configParameters "Analytic Framework Service"
	else
		configParameters="{\"trustedIssuerIds\":[\"$TRUSTED_ISSUER_ID\"]}"
		# Create instance of Predix Analytic Framework Service
		__try_create_predix_service $ANALYTIC_FRAMEWORK_SERVICE_NAME $ANALYTIC_FRAMEWORK_SERVICE_PLAN $ANALYTIC_FRAMEWORK_SERVICE_INSTANCE_NAME $UAA_INSTANCE_NAME $UAA_ADMIN_SECRET $UAA_CLIENTID_GENERIC $UAA_CLIENTID_GENERIC_SECRET "Predix AF Service"
		#__try_create_service_using_cfcli $ANALYTIC_FRAMEWORK_SERVICE_NAME $ANALYTIC_FRAMEWORK_SERVICE_PLAN $ANALYTIC_FRAMEWORK_SERVICE_INSTANCE_NAME $configParameters "Analytic Framework Service"
	fi

	# Bind Temp App to Analytic framework Instance
	__try_bind $1 $ANALYTIC_FRAMEWORK_SERVICE_INSTANCE_NAME
}

function createRabbitMQInstance() {
	__append_new_head_log "Create RabbitMQ Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $RABBITMQ_SERVICE_INSTANCE_NAME
	fi

	# Create instance of RabbitMQ Service
	configParameters="{}" #no config params for rabbit mq creation
	__try_create_service_using_cfcli $RABBITMQ_SERVICE_NAME $RABBITMQ_SERVICE_PLAN $RABBITMQ_SERVICE_INSTANCE_NAME $configParameters "Predix RabbitMQ Service"

	# Bind Temp App to RabbitMQ Service Instance
	__try_bind $1 $RABBITMQ_SERVICE_INSTANCE_NAME
}

function createDeviceService() {
  __append_new_head_log "Create Client for Devices" "-" "$logDir"
	if [[ "$UAA_URL" == "" ]]; then
		getUaaUrl $1
	fi
	__createDeviceClient "$UAA_URL" "$UAA_CLIENTID_DEVICE" "$UAA_CLIENTID_DEVICE_SECRET"
	__addTimeseriesAuthorities $UAA_CLIENTID_DEVICE
}

# one arg: service name
function createRedisInstance() {
    __append_new_head_log "Create Redis Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $REDIS_INSTANCE_NAME
	fi

	# Create instance of RabbitMQ Service
	__try_create_service_using_cfcli $1 $REDIS_SERVICE_PLAN $REDIS_INSTANCE_NAME "{}" "Redis Service"
}

#main sript starts here
function __setupServices() {
	__validate_num_arguments 1 $# "\"predix-services-setup.sh\" expected in order: Name of Predix Application used to get VCAP configurations" "$logDir"

	if [[ ( $BINDING_APP == 1 ) ]]; then
		pushAnAppForBinding $1
	fi

	if [[ $RUN_CREATE_UAA == 1 ]]; then
		createUaa $1
		# Create client ID for generic use by applications - including timeseries and asset scope
		__append_new_head_log "Registering Client on UAA to access the Predix Services" "-" "$logDir"
		if [[ "$UAA_URL" == "" ]]; then
			getUaaUrl $1
		fi

		__createUaaLoginClient "$UAA_URL" "$UAA_CLIENTID_LOGIN" "$UAA_CLIENTID_LOGIN_SECRET"
		if [[ $USE_TRAINING_UAA == 1 ]]; then
			__createUaaAppClient "$UAA_URL" "$UAA_CLIENTID_GENERIC" "$UAA_CLIENTID_GENERIC_SECRET"
		fi
		# Create a new user account
		__addUaaUser "$UAA_URL"
	fi

	if [[ ( $RUN_CREATE_SERVICES == 1 || $RUN_CREATE_ASSET == 1 ) ]]; then
		createAssetService $1
		if [[ $USE_TRAINING_UAA == 1 ]]; then
			__addAssetAuthorities $UAA_CLIENTID_GENERIC
		fi
	fi

	if [[ ( $RUN_CREATE_SERVICES == 1 || $RUN_CREATE_MOBILE == 1 ) ]]; then
		createMobileService $1
	fi

	if [[ ( $RUN_CREATE_SERVICES == 1 || $RUN_CREATE_TIMESERIES == 1 ) ]]; then
		createTimeseries $1
		if [[ $USE_TRAINING_UAA == 1 ]]; then
			__addTimeseriesAuthorities $UAA_CLIENTID_GENERIC
		fi
	fi

	if [[ ( $RUN_CREATE_SERVICES == 1 || $RUN_CREATE_ACS == 1 ) ]]; then
		createACSService $1
		if [[ $USE_TRAINING_UAA == 1 ]]; then
			__addAcsAuthorities $UAA_CLIENTID_GENERIC
		fi
	fi

	if [[ ( $RUN_CREATE_SERVICES == 1 || $RUN_CREATE_ANALYTIC_FRAMEWORK == 1 ) ]]; then
		createAnalyticFrameworkServiceInstance $1
		__addAnalyticFrameworkAuthorities $UAA_CLIENTID_GENERIC
	fi

	#get some variables for printing purposes below
	if [[ "$TIMESERIES_INGEST_URI" == "" ]]; then
		getTimeseriesIngestUri $1
	fi
	if [[ "$TIMESERIES_QUERY_URI" == "" ]]; then
		getTimeseriesQueryUri $1
	fi

	cd "$rootDir"

	__append_new_line_log "Predix Services Configurations found in file: \"$SUMMARY_TEXTFILE\"" "$logDir"

	echo ""  >> $SUMMARY_TEXTFILE
	echo "Predix Services Configuration"  >> $SUMMARY_TEXTFILE
	echo "--------------------------------------------------"  >> $SUMMARY_TEXTFILE
	echo ""  >> $SUMMARY_TEXTFILE
	echo "Installed UAA with a client_id/secret (for your app) and a user/password (for your users to log in to your app)" >> $SUMMARY_TEXTFILE
	echo "Installed Time Series and added time series scopes as client_id authorities" >> $SUMMARY_TEXTFILE
	echo "Installed Asset and added asset scopes as client_id authorities" >> $SUMMARY_TEXTFILE
	echo "" >> $SUMMARY_TEXTFILE
	echo "UAA URL: $UAA_URL" >> $SUMMARY_TEXTFILE
	echo "UAA Admin Client ID: admin" >> $SUMMARY_TEXTFILE
	echo "UAA Admin Client Secret: $UAA_ADMIN_SECRET" >> $SUMMARY_TEXTFILE
	echo "UAA Generic Client ID: $UAA_CLIENTID_GENERIC" >> $SUMMARY_TEXTFILE
	echo "UAA Generic Client Secret: $UAA_CLIENTID_GENERIC_SECRET" >> $SUMMARY_TEXTFILE
	echo "UAA User ID: $UAA_USER_NAME" >> $SUMMARY_TEXTFILE
	echo "UAA User PASSWORD: $UAA_USER_PASSWORD" >> $SUMMARY_TEXTFILE
	echo "TimeSeries Ingest URL:  $TIMESERIES_INGEST_URI" >> $SUMMARY_TEXTFILE
	echo "TimeSeries Query URL:  $TIMESERIES_QUERY_URI" >> $SUMMARY_TEXTFILE
	echo "TimeSeries ZoneID: $TIMESERIES_ZONE_ID" >> $SUMMARY_TEXTFILE
	echo "Asset URL:  $assetURI" >> $SUMMARY_TEXTFILE
	echo "Asset Zone ID: $ASSET_ZONE_ID" >> $SUMMARY_TEXTFILE
	echo "Mobile Zone ID: $MOBILE_ZONE_ID" >> $SUMMARY_TEXTFILE
}
