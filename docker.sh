#!/usr/bin/env bash

#default
IMAGE_NAME="aoc2026-env"
CONTAINER_NAME="aoc2026-env"
USER_NAME="customuser"
HOSTNAME="$CONTAINER_NAME"
VOLUME_PATH=""

#ask for container name
#image name
#username
#hostname
#directory path for container
HOSTNAME_SET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        --user)
            USER_NAME="$2"
            shift 2
            ;;
        --host)
            HOSTNAME="$2"
            HOSTNAME_SET=true
            shift 2
            ;;
        --volume)
            VOLUME_PATH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo
            echo "Usage:"
            echo "  bash docker.sh [options]"
            echo
            echo "Options:"
            echo "  --image <image_name>"
            echo "  --name <container_name>"
            echo "  --user <username>"
            echo "  --host <hostname>"
            echo "  --volume <host_directory>"
            exit 1
            ;;
    esac
done

# If user changed the container name but did not explicitly
# specify a hostname, make hostname match container name.
# to prevent confusion with hostname and container name differ
if [ "$HOSTNAME_SET" = false ]; then
    HOSTNAME="$CONTAINER_NAME"
fi

# Prepare volume option
DOCKER_VOLUME=""

if [ -n "$VOLUME_PATH" ]; then
    DOCKER_VOLUME="-v $VOLUME_PATH:/workspace"
fi

#function to build image
build_image() {
    # check if image already exist with set name
    if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        echo "Docker image '$IMAGE_NAME' already exists."
        echo "To remove it, run:"
        echo "docker rmi $IMAGE_NAME"
        return
    fi

    echo "Building Docker image '$IMAGE_NAME'..."
    #docker build command
    docker build -t "$IMAGE_NAME" .

    if [ $? -eq 0 ]; then
        echo "Build successful!"
    else
        echo "Build failed!"
        exit 1
    fi
}

run_container() {


    CONTAINER_EXISTS=$(docker ps -a -q -f name="^/${CONTAINER_NAME}$")
    CONTAINER_RUNNING=$(docker ps -q -f name="^/${CONTAINER_NAME}$")

    # Container does not exist
    if [ -z "$CONTAINER_EXISTS" ]; then
        #delete repeting configs
        check_container_config
        echo "Container does not exist."
        echo "Creating and starting container..."

        docker run -it \
            --name "$CONTAINER_NAME" \
            --hostname "$HOSTNAME" \
            --user "$USER_NAME" \
            $DOCKER_VOLUME \
            "$IMAGE_NAME" \
            bash

        return
    fi

    # Container already running
    if [ -n "$CONTAINER_RUNNING" ]; then

        echo "Container is already running."
        echo "Entering bash..."

        docker exec -it \
            --user "$USER_NAME" \
            "$CONTAINER_NAME" \
            bash

        return
    fi

    # Container exists but is stopped
    echo "Container exists but is stopped."
    echo "Starting container..."

    docker start "$CONTAINER_NAME"

    docker exec -it \
        --user "$USER_NAME" \
        "$CONTAINER_NAME" \
        bash
}


check_container_config() {

    if [ -z "$(docker ps -a -q -f name="^/${CONTAINER_NAME}$")" ]; then
        return 0
    fi

    EXISTING_HOSTNAME=$(docker inspect "$CONTAINER_NAME" --format '{{.Config.Hostname}}')
    EXISTING_USER=$(docker inspect "$CONTAINER_NAME" --format '{{.Config.User}}')

    # NOTE: volume check is simplified (lab level)
    EXISTING_VOLUME=$(docker inspect "$CONTAINER_NAME" \
        --format '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}')

    # Normalize expected volume
    EXPECTED_VOLUME=""
    if [ -n "$VOLUME_PATH" ]; then
        EXPECTED_VOLUME="$VOLUME_PATH:/workspace"
    fi

    MISMATCH=false

    if [ "$EXISTING_HOSTNAME" != "$HOSTNAME" ]; then
        MISMATCH=true
    fi

    if [ "$EXISTING_USER" != "$USER_NAME" ]; then
        MISMATCH=true
    fi

    if [ "$EXPECTED_VOLUME" != "" ] && [[ "$EXISTING_VOLUME" != *"$EXPECTED_VOLUME"* ]]; then
        MISMATCH=true
    fi

    if [ "$MISMATCH" = true ]; then
        echo "WARNING: Existing container configuration does not match requested settings."
        echo ""
        echo "Existing container:"
        echo "  Name: $CONTAINER_NAME"
        echo "  Hostname: $EXISTING_HOSTNAME"
        echo "  User: $EXISTING_USER"
        echo "  Volume: $EXISTING_VOLUME"
        echo ""
        echo "Requested:"
        echo "  Hostname: $HOSTNAME"
        echo "  User: $USER_NAME"
        echo "  Volume: $VOLUME_PATH"
        echo ""
        echo "To apply changes, recreate container:"
        echo "  docker rm -f $CONTAINER_NAME"
        exit 1
    fi
}

#run build
build_image


run_container





