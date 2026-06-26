#!/bin/bash
# Migrate a Docker-based Arch system to rootless Podman.
# Idempotent: safe to re-run; skips steps already done.

set -u

log()  { echo "==> $*"; }
warn() { echo "!!  $*" >&2; }
err()  { echo "ERROR: $*" >&2; }

if [ "$EUID" -eq 0 ]; then
    err "Run as your regular user, not root. The script uses sudo when needed."
    exit 1
fi

has_pkg() { pacman -Qi "$1" &>/dev/null; }

# Pre-authenticate sudo so the script doesn't pause halfway.
sudo -v || { err "sudo required."; exit 1; }

# ---------------------------------------------------------------------------
# 1. Inventory + save images (while real docker is still installed & running).
# ---------------------------------------------------------------------------
docker_pkg_present=0
has_pkg docker && docker_pkg_present=1

migrate_dir=""
if [ "$docker_pkg_present" = "1" ]; then
    log "Current Docker state:"
    echo "  Containers:"
    sudo docker ps -a --format '    {{.ID}}  {{.Image}}  {{.Status}}  {{.Names}}' 2>/dev/null \
        || echo "    (daemon not responding)"
    echo "  Images:"
    sudo docker images --format '    {{.Repository}}:{{.Tag}}  {{.Size}}' 2>/dev/null \
        || echo "    (daemon not responding)"
    echo "  Volumes:"
    sudo docker volume ls --format '    {{.Name}}  ({{.Driver}})' 2>/dev/null \
        || echo "    (daemon not responding)"

    if systemctl is-active --quiet docker.service; then
        migrate_dir="$(mktemp -d -t docker-podman-XXXXXX)"
        log "Saving Docker images to $migrate_dir (for later podman load)."
        mapfile -t imgs < <(sudo docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null \
                            | grep -v '^<none>' | sort -u)
        for img in "${imgs[@]}"; do
            safe="$(echo "$img" | tr '/:' '__')"
            tarfile="$migrate_dir/$safe.tar"
            echo "  saving $img"
            if sudo docker save -o "$tarfile" "$img" 2>/dev/null; then
                sudo chown "$USER:" "$tarfile"
            else
                warn "failed to save $img -- skipping"
                rm -f "$tarfile"
            fi
        done
    else
        log "docker.service not running -- skipping image save."
    fi
else
    log "Docker not installed -- skipping inventory & image save."
fi

# ---------------------------------------------------------------------------
# 2. Stop & disable Docker services.
# ---------------------------------------------------------------------------
for unit in docker.service docker.socket containerd.service; do
    if systemctl is-active --quiet "$unit" 2>/dev/null; then
        log "Stopping $unit"
        sudo systemctl stop "$unit"
    fi
    if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
        log "Disabling $unit"
        sudo systemctl disable "$unit"
    fi
done

# ---------------------------------------------------------------------------
# 3. Remove user from docker group (if present).
# ---------------------------------------------------------------------------
if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    log "Removing $USER from docker group."
    sudo gpasswd -d "$USER" docker >/dev/null
fi

# ---------------------------------------------------------------------------
# 4. Remove docker packages.
# ---------------------------------------------------------------------------
to_remove=()
for p in docker docker-buildx docker-compose containerd; do
    has_pkg "$p" && to_remove+=("$p")
done
if [ "${#to_remove[@]}" -gt 0 ]; then
    log "Removing packages: ${to_remove[*]}"
    sudo pacman -Rns --noconfirm "${to_remove[@]}"
fi

# ---------------------------------------------------------------------------
# 5. Install podman + companions.
# ---------------------------------------------------------------------------
podman_pkgs=(podman podman-compose podman-docker)
to_install=()
for p in "${podman_pkgs[@]}"; do
    has_pkg "$p" || to_install+=("$p")
done
if [ "${#to_install[@]}" -gt 0 ]; then
    log "Installing: ${to_install[*]}"
    sudo pacman -S --needed --noconfirm "${to_install[@]}"
else
    log "Podman packages already present."
fi

# ---------------------------------------------------------------------------
# 6. Rootless setup: subuid/subgid, user socket, lingering.
# ---------------------------------------------------------------------------
needs_relogin=0
if ! grep -q "^$USER:" /etc/subuid 2>/dev/null; then
    log "Assigning subuid/subgid range to $USER."
    sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$USER"
    needs_relogin=1
fi

if ! systemctl --user is-enabled --quiet podman.socket 2>/dev/null; then
    log "Enabling user-level podman.socket."
    systemctl --user enable --now podman.socket \
        || warn "Could not enable podman.socket -- run after next login: systemctl --user enable --now podman.socket"
fi

if ! loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
    log "Enabling lingering for $USER."
    sudo loginctl enable-linger "$USER"
fi

# ---------------------------------------------------------------------------
# 7. Load saved images into rootless podman.
# ---------------------------------------------------------------------------
if [ -n "$migrate_dir" ] && [ -d "$migrate_dir" ]; then
    shopt -s nullglob
    tarfiles=( "$migrate_dir"/*.tar )
    if [ "${#tarfiles[@]}" -gt 0 ]; then
        log "Loading ${#tarfiles[@]} image(s) into podman."
        for t in "${tarfiles[@]}"; do
            echo "  loading $(basename "$t")"
            podman load -i "$t" >/dev/null && rm -f "$t"
        done
    fi
    rmdir "$migrate_dir" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 8. Volume migration instructions (manual -- auto-copying risks data loss).
# ---------------------------------------------------------------------------
if sudo test -d /var/lib/docker/volumes; then
    cat <<'EOF'

==> Named-volume data was left under /var/lib/docker/volumes/. For each
    named volume you want to keep:

      podman volume create <name>
      sudo cp -a /var/lib/docker/volumes/<name>/_data/. \
          ~/.local/share/containers/storage/volumes/<name>/_data/
      sudo chown -R "$USER:" ~/.local/share/containers/storage/volumes/<name>/

    Bind mounts (host paths) need no migration -- they keep working.
EOF
fi

# ---------------------------------------------------------------------------
# 9. Final notes.
# ---------------------------------------------------------------------------
log "Migration complete."
echo
echo "Next steps:"
echo "  * Run 'stow .' in your dotfiles dir (or re-run install.sh) to symlink"
echo "    the new ~/.config/fish/conf.d/podman.fish (sets DOCKER_HOST so"
echo "    docker-compose / DOCKER_HOST-aware tools talk to rootless podman)."
echo

if [ "$needs_relogin" = "1" ]; then
    echo "  * Log out and back in for subuid/subgid mapping to take effect."
    echo
fi

if sudo test -d /var/lib/docker; then
    size="$(sudo du -sh /var/lib/docker 2>/dev/null | cut -f1)"
    echo "  * /var/lib/docker still holds ${size:-old data}. Once you've"
    echo "    verified the migration, remove it:    sudo rm -rf /var/lib/docker"
fi
