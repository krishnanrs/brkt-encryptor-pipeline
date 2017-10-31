#!/bin/bash

ROOT="$PWD"
FILENAME="$(basename ${ROOT}/base-stemcell/*.tgz)"

pip install brkt-cli

# Get the base AMI
tmp_dir="/tmp/$$"
mkdir -p $tmp_dir

# Update this line for any additional supported Bracket regions
BRKT_REGIONS="us-east-1 us-east-2 us-west-1 us-west-2 eu-central-1 eu-west-1"

# Change this to refer to the actual location of the base stemcell
tar zxf ${ROOT}/base-stemcell/light-bosh-stemcell-*-aws-xen-hvm-ubuntu-trusty-go_agent.tgz -C $tmp_dir

# auth_cmd="brkt auth --email $EMAIL --password $PASSWORD --root-url $URL"
# export BRKT_API_TOKEN=`$auth_cmd`

echo "${CA_CERT}" > ${ROOT}/ca.crt

for region in $BRKT_REGIONS; do
	ami_id=`cat ${tmp_dir}/stemcell.MF | grep region | awk '{print $2}'`
	echo "Encrypting stemcell image $ami_id in $region"
	# cmd="brkt aws encrypt --service-domain $SERVICE_DOMAIN --region $region --metavisor-version ${METAVISOR_VERSION} --ca-cert ${ROOT}/ca.crt --token ${BRKT_TOKEN} $ami_id"
    cmd="brkt aws encrypt --service-domain $SERVICE_DOMAIN --region $region --metavisor-version ${METAVISOR_VERSION} --token ${BRKT_TOKEN} $ami_id"
    $cmd | tee ${tmp_dir}/encrypt_$region.log &
done

# Wait for all background tasks to complete
wait

for region in $BRKT_REGIONS; do
    # Get output AMI from the encrypt command
    output_ami=`tail -1 ${tmp_dir}/_$region.log | awk '{print $1}'`
    if [[ $output_ami =~ ^ami- ]]; then
    	sed -i "s/\b$region\b.*$/$region: $output_ami/" ${tmp_dir}/stemcell.MF
    else
    	echo "Encryption failed in region $region"
    fi
done

pushd $tmp_dir > /dev/null
tar czf "${ROOT}/brkt-stemcell/${FILENAME}" `ls`
popd > /dev/null

rm -rf $tmp_dir
