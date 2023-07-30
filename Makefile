.PHONY: set_namespace create_pipeline_namespace prepare_credentials_namespace prepare_entitlement_key prepare_github_credentials prepare_general_pipeline verify_tekton_pipelines_available prepare_cp4i_overrides
.PHONY: pipeline_ibmcatalog prepare_pipeline_ibmcatalog run_pipeline_ibmcatalog cleanup_pipeline_ibmcatalog
.PHONY: pipeline_platformnavigator prepare_pipeline_platformnavigator run_pipeline_platformnavigator cleanup_pipeline_platformnavigator
.PHONY: pipeline_eventstreams prepare_pipeline_eventstreams run_pipeline_eventstreams cleanup_pipeline_eventstreams
.PHONY: pipeline_eventendpointmanagement_install prepare_pipeline_eventendpointmanagement_install run_pipeline_eventendpointmanagement_install
.PHONY: pipeline_eventendpointmanagement_setup prepare_pipeline_eventendpointmanagement_setup run_pipeline_eventendpointmanagement_setup
.PHONY: pipeline_eventendpointmanagement cleanup_pipeline_eventendpointmanagement
.PHONY: pipeline_kafkaconnectors cleanup_pipeline_kafkaconnectors
.PHONY: output_details


wait_for_pipelinerun = \
	PIPELINERUN=$1; \
	echo "$$PIPELINERUN"; \
	STATUS="Running"; \
	while [ $$STATUS = "Running" ]; do \
		oc wait $$PIPELINERUN --for=condition=Succeeded --timeout=30m; \
		STATUS=$$(oc get $$PIPELINERUN -o jsonpath='{.status.conditions[0].reason}'); \
	done; \
	if [ "$$STATUS" != "Succeeded" ]; \
	then \
		echo "$$PIPELINERUN failed"; \
		exit 1; \
	fi


#
#
#


ensure_operator_installed = \
	OPERATORNAME=$1; \
	OPERATORINSTALLER=$2; \
	ISOPERATORINSTALLED=$$(oc get subscription -n openshift-operators  -o go-template='{{len .items}}' --field-selector metadata.name=$$OPERATORNAME); \
	if [ $$ISOPERATORINSTALLED -eq 0 ]; \
	then \
		oc apply -f $$OPERATORINSTALLER ; \
		QUERY="{.items[?(@.metadata.ownerReferences[0].name==\"$$OPERATORNAME\")].status.phase}"; \
		sleep 30 ; \
		OPERATORSTATUS=""; \
		while [ "$$OPERATORSTATUS" != "Complete" ]; do \
			OPERATORSTATUS=$$(oc get installplan -n openshift-operators -o jsonpath="$$QUERY"); \
			sleep 180 ; \
		done; \
	fi


#
#
#


create_pipeline_namespace:
	@oc create namespace pipeline-eventdrivendemo --dry-run=client -o yaml | oc apply -f -

set_namespace: create_pipeline_namespace
	@oc project pipeline-eventdrivendemo

prepare_github_credentials: create_pipeline_namespace
	@oc apply -f ./github-credentials.yaml


prepare_credentials_namespace:
	@oc create namespace pipeline-credentials --dry-run=client -o yaml | oc apply -f -

prepare_entitlement_key: prepare_credentials_namespace
	@oc apply -f ./ibm-entitlement-key.yaml

prepare_stockprice_apikey: prepare_credentials_namespace
	@oc apply -f ./alphavantage-apikey.yaml

prepare_cp4i_overrides: create_pipeline_namespace
	@oc apply -f ./cp4i-overrides.yaml





verify_tekton_pipelines_available: create_pipeline_namespace
	@$(call ensure_operator_installed,"openshift-pipelines-operator-rh","./01-install-tekton/tekton-subscription.yaml")


prepare_general_pipeline: verify_tekton_pipelines_available prepare_entitlement_key set_namespace prepare_github_credentials prepare_stockprice_apikey prepare_cp4i_overrides
	@oc apply -f ./00-common/permissions
	@oc apply -f ./00-common/tasks

#
#
#


prepare_pipeline_ibmcatalog: prepare_general_pipeline
	@oc apply -f ./02-install-ibm-catalog/permissions
	@oc apply -f ./02-install-ibm-catalog/pipeline.yaml

run_pipeline_ibmcatalog:
	@echo "------------------------------------------------------------"
	@echo "Installing the IBM Catalog into the cluster..."
	@echo "------------------------------------------------------------"
	@$(call wait_for_pipelinerun,$(shell oc create -f ./02-install-ibm-catalog/pipelinerun.yaml -o name))

pipeline_ibmcatalog: prepare_pipeline_ibmcatalog run_pipeline_ibmcatalog

cleanup_pipeline_ibmcatalog: set_namespace
	@oc delete --ignore-not-found=true -f ./02-install-ibm-catalog/permissions
	@oc delete -l tekton.dev/pipeline=pipeline-ibmcatalog pipelineruns
	@oc delete --ignore-not-found=true -f ./02-install-ibm-catalog/pipeline.yaml


#
#
#


prepare_pipeline_commonservices: prepare_general_pipeline
	@oc apply -f ./03-install-ibm-common-services/permissions
	@oc apply -f ./00-common/pipelines/cp4i.yaml

run_pipeline_commonservices:
	@echo "------------------------------------------------------------"
	@echo "Configuring IBM Common Services..."
	@echo "------------------------------------------------------------"
	@$(call wait_for_pipelinerun,$(shell oc create -f ./03-install-ibm-common-services/pipelinerun.yaml -o name))

pipeline_commonservices: prepare_pipeline_commonservices run_pipeline_commonservices

cleanup_pipeline_commonservices: set_namespace
	@oc delete --ignore-not-found=true -f ./03-install-ibm-common-services/permissions


#
#
#


prepare_pipeline_platformnavigator: prepare_general_pipeline
	@oc apply -f ./04-install-platform-navigator/permissions
	@oc apply -f ./00-common/pipelines/cp4i.yaml

run_pipeline_platformnavigator:
	@echo "------------------------------------------------------------"
	@echo "Creating the Cloud Pak for Integration Platform Navigator..."
	@echo "------------------------------------------------------------"
	@$(call wait_for_pipelinerun,$(shell oc create -f ./04-install-platform-navigator/pipelinerun.yaml -o name))

pipeline_platformnavigator: prepare_pipeline_platformnavigator run_pipeline_platformnavigator

cleanup_pipeline_platformnavigator: set_namespace
	@oc delete --ignore-not-found=true -f ./04-install-platform-navigator/permissions


#
#
#


prepare_pipeline_eventstreams: prepare_general_pipeline
	@oc apply -f ./05-install-event-streams/permissions
	@oc apply -f ./00-common/pipelines/cp4i.yaml

run_pipeline_eventstreams:
	@echo "------------------------------------------------------------"
	@echo "Creating the Event Streams instance..."
	@echo "------------------------------------------------------------"
	@$(call wait_for_pipelinerun,$(shell oc create -f ./05-install-event-streams/pipelinerun.yaml -o name))

pipeline_eventstreams: prepare_pipeline_eventstreams run_pipeline_eventstreams

cleanup_pipeline_eventstreams: set_namespace
	@oc delete --ignore-not-found=true -f ./05-install-event-streams/permissions


#
#
#

prepare_pipeline_kafkaconnectors: prepare_general_pipeline
	@oc apply -f ./06-start-kafka-connectors/permissions
	@oc apply -f ./06-start-kafka-connectors/tasks
	@oc apply -f ./06-start-kafka-connectors/pipeline-maven-settings.yaml
	@oc apply -f ./06-start-kafka-connectors/pipeline.yaml
	@oc adm policy add-scc-to-user privileged -z pipeline-deployer-serviceaccount

run_pipeline_kafkaconnectors:
	@echo "------------------------------------------------------------"
	@echo "Building and starting Kafka connectors..."
	@echo "------------------------------------------------------------"
	@oc create secret generic ibm-entitlement-key-config-json --from-file=config.json=dockerconfig.json --dry-run=client -o yaml | oc apply -n pipeline-eventdrivendemo -f -
	@$(call wait_for_pipelinerun,$(shell oc create -f ./06-start-kafka-connectors/pipelinerun.yaml -o name))

pipeline_kafkaconnectors: prepare_pipeline_kafkaconnectors run_pipeline_kafkaconnectors

cleanup_pipeline_kafkaconnectors: set_namespace
	@oc delete --ignore-not-found=true -f ./06-start-kafka-connectors/tasks
	@oc delete --ignore-not-found=true -f ./06-start-kafka-connectors/pipeline-maven-settings.yaml
	@oc delete -l tekton.dev/pipeline=pipeline-kafkaconnectors pipelineruns
	@oc delete --ignore-not-found=true -f ./06-start-kafka-connectors/pipeline.yaml
	@oc delete --ignore-not-found=true -f ./06-start-kafka-connectors/permissions
	@oc adm policy remove-scc-from-user privileged -z pipeline-deployer-serviceaccount
	@oc delete -n pipeline-eventdrivendemo ibm-entitlement-key-config-json


#
#
#


prepare_pipeline_eventendpointmanagement_install: prepare_general_pipeline
	@oc apply -f ./07-install-event-endpoint-management/permissions
	@oc apply -f ./00-common/pipelines/cp4i.yaml

run_pipeline_eventendpointmanagement_install:
	@echo "------------------------------------------------------------"
	@echo "Creating the Event Endpoint Management instance..."
	@echo "------------------------------------------------------------"
	@$(call wait_for_pipelinerun,$(shell oc create -f ./07-install-event-endpoint-management/pipelinerun-install.yaml -o name))

pipeline_eventendpointmanagement_install: prepare_pipeline_eventendpointmanagement_install run_pipeline_eventendpointmanagement_install


prepare_pipeline_eventendpointmanagement_setup: prepare_general_pipeline
	@oc apply -f ./07-install-event-endpoint-management/permissions
	@oc apply -f ./07-install-event-endpoint-management/tasks
	@oc apply -f ./07-install-event-endpoint-management/pipelines

run_pipeline_eventendpointmanagement_setup:
	@echo "------------------------------------------------------------"
	@echo "Setting up the Event Endpoint Management instance..."
	@echo "------------------------------------------------------------"
	@$(call wait_for_pipelinerun,$(shell oc create -f ./07-install-event-endpoint-management/pipelinerun-setup.yaml -o name))

pipeline_eventendpointmanagement_setup: prepare_pipeline_eventendpointmanagement_setup run_pipeline_eventendpointmanagement_setup


pipeline_eventendpointmanagement: pipeline_eventendpointmanagement_install pipeline_eventendpointmanagement_setup

cleanup_pipeline_eventendpointmanagement: set_namespace
	@oc delete --ignore-not-found=true -f ./07-install-event-endpoint-management/permissions
	@oc delete --ignore-not-found=true -f ./07-install-event-endpoint-management/tasks
	@oc delete -l tekton.dev/pipeline=pipeline-event-endpoint-management pipelineruns
	@oc delete --ignore-not-found=true -f ./07-install-event-endpoint-management/pipelines


#
#
#


prepare_pipeline_asyncapi: prepare_general_pipeline
	@oc apply -f ./08-publish-topics-to-eem/permissions
	@oc apply -f ./08-publish-topics-to-eem/tasks
	@oc apply -f ./08-publish-topics-to-eem/pipeline.yaml

run_pipeline_asyncapi:
	@echo "------------------------------------------------------------"
	@echo "Generating and publishing doc for connectors..."
	@echo "------------------------------------------------------------"
	@$(call wait_for_pipelinerun,$(shell oc create -f ./08-publish-topics-to-eem/pipelinerun.yaml -o name))

pipeline_asyncapi: prepare_pipeline_asyncapi run_pipeline_asyncapi

cleanup_pipeline_asyncapi: set_namespace
	@oc delete --ignore-not-found=true -f ./08-publish-topics-to-eem/tasks
	@oc delete -l tekton.dev/pipeline=pipeline-stockpricesasyncapi pipelineruns
	@oc delete --ignore-not-found=true -f ./08-publish-topics-to-eem/pipeline.yaml
	@oc delete --ignore-not-found=true -f ./08-publish-topics-to-eem/permissions


#
#
#


output_details:
	@echo "Install complete.\n\n"
	@echo "Cloud Pak for Integration : `oc get route -nintegration cpd -o jsonpath='https://{.spec.host}'`"
	@echo "username                  : `oc get secret -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 -d`"
	@echo "password                  : `oc get secret -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d`\n"

	@echo "Event Streams             : `oc get eventstreams -neventstreams es -o jsonpath='{.status.endpoints[?(@.name=="ui")].uri}'`"
	@echo "username                  : `oc get secret -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 -d`"
	@echo "password                  : `oc get secret -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d`\n"

	@echo "Event Endpoint Management : `oc get eventendpointmanager -neventendpointmanagement eem -o jsonpath='{.status.endpoints[?(@.name=="ui")].uri}'`"
	@echo "username                  : `oc get secret -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 -d`"
	@echo "password                  : `oc get secret -n ibm-common-services platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d`\n"

	@echo "Developer Portal          : `oc get route -neventendpointmanagement eem-ptl-portal-web -o jsonpath='https://{.spec.host}'/events-demo/events-catalog/`"
	@echo "username                  : `oc get secret -n pipeline-credentials portal-credentials -o jsonpath='{.data.username}' | base64 -d`"
	@echo "password                  : `oc get secret -n pipeline-credentials portal-credentials -o jsonpath='{.data.password}' | base64 -d`\n"


#
#
#


all: pipeline_ibmcatalog \
	pipeline_commonservices \
	pipeline_platformnavigator \
	pipeline_eventstreams \
	pipeline_kafkaconnectors \
	pipeline_eventendpointmanagement \
	pipeline_asyncapi \
	output_details

#
#
#

clean: cleanup_pipeline_ibmcatalog \
	cleanup_pipeline_commonservices \
	cleanup_pipeline_platformnavigator \
	cleanup_pipeline_eventstreams \
	cleanup_pipeline_kafkaconnectors \
	cleanup_pipeline_eventendpointmanagement \
	cleanup_pipeline_asyncapi
	@oc delete --ignore-not-found=true -f ./00-common/tasks
	@oc delete --ignore-not-found=true -f ./00-common/pipelines
	@oc delete -l tekton.dev/pipeline=pipeline-cp4i pipelineruns
	@oc delete --ignore-not-found=true -f ./00-common/permissions
	@oc delete --ignore-not-found=true -f ./github-credentials.yaml
	@oc delete --ignore-not-found=true -f ./cp4i-overrides.yaml
