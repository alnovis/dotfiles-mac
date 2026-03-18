function dclean --description "Clean up Docker: stopped containers, dangling images, unused volumes"
    argparse 'h/help' 'a/all' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: dclean [OPTIONS]"
        echo ""
        echo "Clean up Docker: stopped containers, dangling images, unused volumes."
        echo ""
        echo "Options:"
        echo "  -a, --all    Full prune (all unused images, networks, build cache)"
        echo "  -h, --help   Show this help"
        return 0
    end

    echo "Docker cleanup"

    # Stopped containers
    set -l containers (docker ps -aq --filter status=exited 2>/dev/null)
    set -l container_count (count $containers)
    if test $container_count -gt 0
        set_color yellow
        echo "Stopped containers: $container_count"
        set_color normal
        docker rm $containers 2>/dev/null
    end

    # Dangling images
    set -l images (docker images -q --filter dangling=true 2>/dev/null)
    set -l image_count (count $images)
    if test $image_count -gt 0
        set_color yellow
        echo "Dangling images: $image_count"
        set_color normal
        docker rmi $images 2>/dev/null
    end

    # Unused volumes
    set -l volumes (docker volume ls -q --filter dangling=true 2>/dev/null)
    set -l volume_count (count $volumes)
    if test $volume_count -gt 0
        set_color yellow
        echo "Unused volumes: $volume_count"
        set_color normal
        docker volume rm $volumes 2>/dev/null
    end

    # Full prune with --all flag
    if set -q _flag_all
        set_color red
        echo "Pruning all unused images (not just dangling)..."
        set_color normal
        docker image prune -a -f 2>/dev/null
        docker network prune -f 2>/dev/null
        docker builder prune -f 2>/dev/null
    end

    echo "---"
    set -l space (docker system df --format '{{.Reclaimable}}' 2>/dev/null | head -1)
    set_color green
    echo "Done — $container_count containers, $image_count images, $volume_count volumes removed"
    set_color normal
end
