#!/bin/bash -x

ROOT="$PWD"
FILENAME="$(basename ${ROOT}/base-stemcell/*.tgz)"

pip install brkt-cli

# Get the base AMI
tmp_dir="/tmp/$$"
mkdir -p $tmp_dir

# Change this to refer to the actual location of the base stemcell
tar zxf ${ROOT}/base-stemcell/light-bosh-stemcell-*-aws-xen-hvm-ubuntu-trusty-go_agent.tgz -C $tmp_dir
ami_id=`cat ${tmp_dir}/stemcell.MF | grep $AWS_REGION | awk '{print $2}'`

# auth_cmd="brkt auth --email $EMAIL --password $PASSWORD --root-url $URL"
# export BRKT_API_TOKEN=`$auth_cmd`

echo "${CA_CERT}" > ${ROOT}/ca.crt

cmd="brkt aws encrypt --service-domain $SERVICE_DOMAIN --region $AWS_REGION --metavisor-version ${METAVISOR_VERSION} --ca-cert ${ROOT}/ca.crt --token ${BRKT_TOKEN} $ami_id"
`$cmd > ${tmp_dir}/encrypt.log 2>&1`
if [ `echo $?` -ne 0 ]; then
    echo "Bracket encryption failed. Please check encryption logs at ${tmp_dir}/encrypt.log"
else
    # Get output AMI from the encrypt command
    output_ami=`tail -1 ${tmp_dir}/encrypt.log | awk '{print $1}'`
    rm -f $tmp_dir/encrypt.log
    sed -i "s/$ami_id/$output_ami/" ${tmp_dir}/stemcell.MF
    pushd $tmp_dir > /dev/null
    # Change this to preserve the stemcell name/version etc.
    tar czf "${ROOT}/brkt-stemcell/${FILENAME}" `ls`
    popd > /dev/null
fi

rm -rf $tmp_dir
