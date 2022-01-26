#!/usr/bin/env bash
PATH="$(find $(pwd)/scanner/sonar-scanner/sonar*/bin  -printf "%p" -quit )":${PATH}
sonar_up="$( docker ps | grep  sonarqube )"; 
if [ ! -z "${sonar_up}" ]; then 
    docker stop sonarqube; 
fi;

docker run -d --rm --name sonarqube -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true -p 9000:9000 sonarqube:latest 
sleep 50
curl -u admin:admin -X POST "http://localhost:9000/api/projects/create?project=mesh2cloud.project&name=mesh2cloud&branch=develop"     
sleep 5 
export token=$(curl -u admin:admin -X POST "http://localhost:9000/api/user_tokens/generate?name=test_token" | jq -r '.  | .token')
sleep 5 
echo  $token
sonar-scanner -Dsonar.projectKey=mesh2cloud.project   -Dsonar.sources=.   -Dsonar.host.url=http://localhost:9000   -Dsonar.login="$token"