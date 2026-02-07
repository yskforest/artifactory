docker run --name artifactory -d \
    --cpus=4 \
    --memory=6g \
    --memory-swap=6g \
    --ulimit nofile=32000:40000 \
    -e JF_SHARED_DATABASE_TYPE=derby \
    -e JF_SHARED_DATABASE_ALLOWNONPOSTGRESQL=true \
    -e EXTRA_JAVA_OPTIONS="-Xms1g -Xmx4g -XX:+UseG1GC -XX:MaxGCPauseMillis=200" \
    -p 8091:8081 -p 8092:8082 \
    -v artifactory_data:/var/opt/jfrog/artifactory \
    releases-docker.jfrog.io/jfrog/artifactory-cpp-ce:latest
