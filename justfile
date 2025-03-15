# Docker commands for nginx-php8.2-fpm
# Usage: just <command>

# Default container name and image name
container_name := "nginx-php82-fpm"
image_name := "merchantprotocol/nginx-php82-fpm"
image_tag := "latest"
host_port := "8082"
container_port := "80"
ssl_port := "8443"
container_ssl_port := "443"

# Default recipe to show available commands
default:
    @just --list

# Build the Docker image
build:
    docker build -t {{image_name}}:{{image_tag}} .

# Build the Docker image with no cache
build-fresh:
    docker build --no-cache -t {{image_name}}:{{image_tag}} .

# Run the container in detached mode
run:
    docker run -d \
        --name {{container_name}} \
        -p {{host_port}}:{{container_port}} \
        -p {{ssl_port}}:{{container_ssl_port}} \
        -v $(pwd)/html:/var/www/html \
        {{image_name}}:{{image_tag}}

# Run the container with interactive shell
run-interactive:
    docker run -it \
        --name {{container_name}} \
        -p {{host_port}}:{{container_port}} \
        -p {{ssl_port}}:{{container_ssl_port}} \
        -v $(pwd)/html:/var/www/html \
        {{image_name}}:{{image_tag}} /bin/bash

# Run the container with custom user ID and group ID
run-with-uid uid="1000" gid="1000":
    docker build \
        --build-arg USER_ID={{uid}} \
        --build-arg GROUP_ID={{gid}} \
        -t {{image_name}}:{{image_tag}} .
    docker run -d \
        --name {{container_name}} \
        -p {{host_port}}:{{container_port}} \
        -p {{ssl_port}}:{{container_ssl_port}} \
        -v $(pwd)/html:/var/www/html \
        {{image_name}}:{{image_tag}}

# Stop and remove the container
stop:
    docker stop {{container_name}} || true
    docker rm {{container_name}} || true

# Restart the container
restart: stop run

# Execute a shell inside the running container
shell:
    docker exec -it {{container_name}} /bin/bash

# View container logs
logs:
    docker logs {{container_name}}

# Follow container logs
logs-follow:
    docker logs -f {{container_name}}

# Clean up all related Docker resources
clean: stop
    docker rmi {{image_name}}:{{image_tag}} || true

# Show container status
status:
    docker ps -a | grep {{container_name}} || echo "Container not found"

# Run a one-off command in the container
exec command="":
    docker exec -it {{container_name}} {{command}}
