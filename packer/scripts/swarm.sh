#!/bin/bash

#docker swarm init


CM_JOIN=$(docker swarm join-token worker |grep join)


function delete_nodes() {

docker node ls |grep Down | cut -d " " -f 1 |xargs -i docker node rm {}

                        }

function get_nodes()   {

for i in `aws --region=eu-central-1 autoscaling describe-auto-scaling-groups --auto-scaling-group-names terraform-asg-node | jq '.AutoScalingGroups[].Instances[].InstanceId' -r`; do aws --region=eu-central-1 ec2 describe-instances --instance-ids $i | jq '.Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddress ' -r; done

                       }

function join_node() {
     ssh -o "StrictHostKeyChecking=no" swarm@$i 'docker swarm leave'
     ssh -o "StrictHostKeyChecking=no" swarm@$i eval $CM_JOIN
                    }


##### ==========  main()==============

delete_nodes

for i in $(get_nodes); do
     skeep=false
     hname="ip-"$(echo $i |sed 's/\./-/g'i)

            for k in $(docker node ls -f "role=worker"  --format "{{.Hostname}} {{.Status}}" |grep Ready |cut -d " " -f 1);
            do
               if  [[ "$k" == "$hname" ]]; then skeep=true
                                           else skeep=false;
               fi
            done

     if [[ "$skeep"  == "false" ]]; then join_node && skeep=false; fi

done
