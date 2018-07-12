#!/usr/bin/env python
import argparse
import base64
import os
import sys
import time
import uuid

from azure.common.client_factory import get_client_from_cli_profile
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.authorization import AuthorizationManagementClient

REGION_NAME='eastus'
RESOURCE_GROUP_PARAMS = {'location': REGION_NAME}

def initial_setup(args):
    RESOURCE_GROUP_NAME = "%s-rg" % args.project
    KEYVAULT_NAME = "%s-kv" % args.project
    SECRET_NAME="%s-sct"  % args.project
    SSH_KEY_NAME="%s-key" % args.project

    print "Initializing Setup"

    resource_client = get_client_from_cli_profile(ResourceManagementClient)
    authorization_client = get_client_from_cli_profile(AuthorizationManagementClient)
    contributor_role = authorization_client.role_definitions.get('Contributor')
    print(contributor_role)
    sys.exit(1)
    
    print("Checking Resource Group: %s in Region: %s" % (RESOURCE_GROUP_NAME, REGION_NAME))
    if not resource_client.resource_groups.check_existence(RESOURCE_GROUP_NAME):
        RESOURCE_GROUP_PARAMS.update({ 'managed_by': args.subscription })
        print("Creating Resource Group: %s in Region: %s" % (RESOURCE_GROUP_NAME, REGION_NAME))
        resource_group = resource_client.resource_groups.create_or_update(RESOURCE_GROUP_NAME, RESOURCE_GROUP_PARAMS)
        print("Created Resource Group: %s in Region: %s" % (RESOURCE_GROUP_NAME, REGION_NAME))

        print("Assigment Role to: %s in Region: %s" % (RESOURCE_GROUP_NAME, REGION_NAME))
        authorization_client.role_definitions.get('Contributor')
        role_assignment = authorization_client.role_assignments.create(
            resource_group.id,
            uuid.uuid4(), # Role assignment random name
            {
                'role_definition_id': contributor_role.id,
                'principal_id': args.service
            }
        )
    else:
        resource_group = resource_client.resource_groups.get(RESOURCE_GROUP_NAME)

    

def deploy(args):
    print "Deploy"

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Bootstrap Openshift in Azure')

    parser.add_argument('--project', help='Project Name', required=True)
    parser.add_argument('--service', help='Service Principal ID', required=True)
    parser.add_argument('--subscription', help='Subscription ID')    
    parser.add_argument('--action', default='initial-setup', help='Action to execute')

    args = parser.parse_args()

    if args.action == 'initial-setup':
        initial_setup(args)
    elif args.action == 'deploy':
        deploy(args)