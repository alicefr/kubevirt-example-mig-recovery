#!/bin/bash
set -x

kubectl patch kubevirt kubevirt -n kubevirt --type='json' -p='[
    {"op": "replace", "path": "/spec/configuration/vmRolloutStrategy", "value": "LiveUpdate"},
    {"op": "add", "path": "/spec/configuration/developerConfiguration/featureGates", "value": [
        "VolumesUpdateStrategy", "VolumeMigration", "VMPersistentState",
    ]},
    {"op": "add", "path": "/spec/workloadUpdateStrategy", value: {
            "workloadUpdateMethods": ["LiveMigrate"]},
    },
    {"op": "add", "path": "/spec/configuration/vmStateStorageClass", "value": "local"},
]'

kubectl apply -f vm-dv.yaml
kubectl apply -f migration-policy.yaml
virtctl start vm-dv
kubectl wait virtualmachineinstance.kubevirt.io/vm-dv --for jsonpath='{.status.phase}'='Running'
kubectl apply -f vm-dv-update.yaml

sleep 3
mig=""
until [ ! -z "${mig}" ]
do
    mig=$(kubectl get virtualmachineinstancemigration -l kubevirt.io/vmi-name=vm-dv -o jsonpath={.items[0].metadata.name})
    sleep 1
done
kubectl wait virtualmachineinstancemigration.kubevirt.io/${mig} --for jsonpath='{.status.phase}'='Running'

src=""
until [ ! -z "${src}" ]
do
    src=$(kubectl get vmi vm-dv -o jsonpath='{.status.migrationState.sourcePod}')
    sleep 1
done
kubectl delete pod $src
