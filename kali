#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
# KALI PRO GHOST EDITION – MINIMAL (KHÔNG ICON, KHÔNG GHI CHÚ)
# ============================================================

VPN_CONFIG="$HOME/vpn.ovpn"
TOR_CONFIG="$HOME/.tor/torrc"
NH_CMD="nethunter"
NH_ROOT="$NH_CMD -r"
CONFIG_DIR="$HOME/.kali-pro"
LOCK_VPN="$CONFIG_DIR/vpn.lock"
LOCK_TOR="$CONFIG_DIR/tor.lock"
LOG_FILE="$CONFIG_DIR/setup.log"

mkdir -p "$CONFIG_DIR"
touch "$LOG_FILE"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
info() { echo "[✓] $1"; }
warn() { echo "[!] $1"; }
error() { echo "[✗] $1"; }

check_internet() {
    $NH_ROOT ping -c 1 1.1.1.1 >/dev/null 2>&1 || $NH_ROOT ping -c 1 8.8.8.8 >/dev/null 2>&1
}

ensure_pkg() {
    local pkg=$1
    local root=$2
    local cmd="dpkg -s $pkg 2>/dev/null | grep -q 'Status.*installed'"
    local install="DEBIAN_FRONTEND=noninteractive apt update -qq 2>/dev/null && apt install -y -qq $pkg 2>/dev/null"
    if [ "$root" = true ]; then
        $NH_ROOT bash -c "$cmd" || $NH_ROOT bash -c "$install"
    else
        $NH_CMD bash -c "$cmd" || $NH_CMD bash -c "$install"
    fi
}

system_optimize() {
    info "Dang toi uu he thong..."
    $NH_ROOT bash -c '
        echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null
        echo 10 > /proc/sys/vm/swappiness
        echo 50 > /proc/sys/vm/vfs_cache_pressure
        echo deadline | tee /sys/block/*/queue/scheduler 2>/dev/null
        echo 262144 > /proc/sys/net/core/rmem_max
        echo 262144 > /proc/sys/net/core/wmem_max
        echo 1 > /proc/sys/net/ipv4/tcp_low_latency
        sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
        sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
        systemctl stop bluetooth cups avahi-daemon 2>/dev/null
        systemctl disable bluetooth cups avahi-daemon 2>/dev/null
        apt clean -qq 2>/dev/null
        apt autoremove -y -qq 2>/dev/null
    ' &>/dev/null &
    info "Toi uu hoan tat"
}

setup_vpn() {
    if [ ! -f "$VPN_CONFIG" ]; then
        warn "Khong tim thay file VPN config tai $VPN_CONFIG"
        return 1
    fi
    ensure_pkg "openvpn" true
    if ! pgrep -f "openvpn.*$VPN_CONFIG" >/dev/null; then
        $NH_ROOT openvpn --config "$VPN_CONFIG" --daemon --writepid "$LOCK_VPN" \
            --redirect-gateway def1 --dhcp-option DNS 1.1.1.1 &>/dev/null
        info "VPN da ket noi"
    else
        warn "VPN dang chay"
    fi
}

stop_vpn() {
    $NH_ROOT pkill -f openvpn 2>/dev/null
    rm -f "$LOCK_VPN"
    info "VPN da dung"
}

setup_tor() {
    ensure_pkg "tor" true
    if [ ! -f "$TOR_CONFIG" ]; then
        $NH_ROOT mkdir -p "$(dirname "$TOR_CONFIG")"
        $NH_ROOT bash -c "cat > $TOR_CONFIG" <<EOF
SOCKSPort 9050
DNSPort 5353
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsOnResolve 1
EOF
    fi
    if ! pgrep -f "tor.*-f $TOR_CONFIG" >/dev/null; then
        $NH_ROOT tor -f "$TOR_CONFIG" --runasdaemon 1 &>/dev/null
        touch "$LOCK_TOR"
        info "Tor daemon da khoi dong"
    else
        warn "Tor dang chay"
    fi
}

stop_tor() {
    $NH_ROOT pkill -f "tor.*-f $TOR_CONFIG" 2>/dev/null
    rm -f "$LOCK_TOR"
    info "Tor da dung"
}

spoof_mac() {
    info "Dang lam moi dia chi MAC..."
    ensure_pkg "macchanger" true
    $NH_ROOT bash -c '
        for iface in $(ls /sys/class/net | grep -v lo); do
            ip link set "$iface" down
            macchanger -r "$iface" 2>/dev/null || \
            ip link set dev "$iface" address $(tr -dc a-f0-9 < /dev/urandom | head -c 12 | sed "s/\(..\)/\1:/g;s/:$//")
            ip link set "$iface" up
        done
    ' &>/dev/null &
    info "MAC address da thay doi ngau nhien"
}

enable_kill_switch() {
    info "Kich hoat Kill Switch..."
    $NH_ROOT bash -c '
        iptables -P INPUT DROP
        iptables -P OUTPUT DROP
        iptables -P FORWARD DROP
        iptables -A OUTPUT -o tun+ -j ACCEPT
        iptables -A INPUT -i tun+ -j ACCEPT
        iptables -A OUTPUT -o lo -j ACCEPT
        iptables -A INPUT -i lo -j ACCEPT
    ' 2>/dev/null && info "Kill Switch da bat" || error "Khong the thiet lap iptables"
}

disable_kill_switch() {
    $NH_ROOT bash -c '
        iptables -P INPUT ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -F
    ' 2>/dev/null && info "Kill Switch da tat" || error "Khong the reset iptables"
}

activate_stealth() {
    info "Kich hoat che do tang hinh..."
    $NH_ROOT bash -c '
        RAND_NAME="ghost-$(tr -dc a-f0-9 < /dev/urandom | head -c 6)"
        echo "$RAND_NAME" > /etc/hostname
        hostname "$RAND_NAME"
        history -c
        > ~/.bash_history 2>/dev/null
        > ~/.zsh_history 2>/dev/null
        > ~/.fish_history 2>/dev/null
        journalctl --rotate 2>/dev/null
        journalctl --vacuum-time 1s 2>/dev/null
        find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null
        > /var/log/wtmp 2>/dev/null
        > /var/log/btmp 2>/dev/null
        xfconf-query -c xfce4-panel -p /panels/panel-1/autohide -s true 2>/dev/null
        xfconf-query -c xfce4-notifyd -p /do-not-disturb -s true 2>/dev/null
    ' &>/dev/null &
    info "Stealth mode: hostname ngau nhien, log trong, panel an"
}

setup_desktop() {
    info "Cai dat moi truong desktop XFCE + Kali Desktop Experience..."
    ensure_pkg "kali-desktop-xfce" true
    ensure_pkg "xfce4" true
    ensure_pkg "xfce4-goodies" true
    ensure_pkg "kex" true
    $NH_CMD kex stop 2>/dev/null
    $NH_CMD kex --set-shared -y 2>/dev/null
    info "Desktop da san sang. Dung lenh 'kex' de khoi dong VNC."
}

start_desktop() {
    info "Khoi dong Kali Desktop & VPN + Tor + Stealth..."
    $NH_ROOT xfwm4 --replace --compositor=off --daemon 2>/dev/null &
    setup_vpn
    setup_tor
    spoof_mac
    activate_stealth
    $NH_CMD kex --slim &>/dev/null &
    sleep 2
    info "Desktop dang chay. Truy cap VNC tai localhost:5901 (mat khau: kali)"
}

stop_desktop() {
    info "Dung toan bo dich vu..."
    $NH_CMD kex stop 2>/dev/null
    stop_vpn
    stop_tor
    disable_kill_switch
    info "Da dung desktop va cac dich vu nac danh"
}

wipe_traces() {
    warn "XOA HOAN TOAN MOI DAU VET? (y/N): "
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || return
    info "Dang tay sach dau vet..."
    $NH_ROOT bash -c '
        find /home /root -name ".bash_history" -exec truncate -s 0 {} \;
        find /home /root -name ".zsh_history" -exec truncate -s 0 {} \;
        find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
        rm -rf /tmp/* /var/tmp/* 2>/dev/null
        > /var/log/lastlog 2>/dev/null
        history -c
    ' 2>/dev/null
    history -c
    info "Da xoa sach"
}

panic_mode() {
    warn "KICH HOAT PANIC – HUY MOI TIEN TRINH"
    $NH_ROOT bash -c '
        pkill -9 -f kex 2>/dev/null
        pkill -9 -f openvpn 2>/dev/null
        pkill -9 -f tor 2>/dev/null
        pkill -9 -f msfconsole 2>/dev/null
        pkill -9 -f wireshark 2>/dev/null
        pkill -9 -f xfce4 2>/dev/null
        iptables -P INPUT ACCEPT 2>/dev/null
        iptables -P OUTPUT ACCEPT 2>/dev/null
        iptables -P FORWARD ACCEPT 2>/dev/null
        iptables -F 2>/dev/null
    ' 2>/dev/null
    rm -f "$LOCK_VPN" "$LOCK_TOR"
    clear
    echo "========================================"
    echo "      PANIC MODE ACTIVATED              "
    echo "   MOI THU DA DUNG & FIREWALL RESET     "
    echo "========================================"
    sleep 2
}

network_monitor() {
    ensure_pkg "bmon" true
    ensure_pkg "iftop" true
    ensure_pkg "nethogs" true
    echo "1) bmon   – bang thong tong"
    echo "2) iftop  – ket noi theo IP"
    echo "3) nethogs – tien trinh su dung mang"
    read -p "Chon: " mon
    case $mon in
        1) $NH_ROOT bmon ;;
        2) $NH_ROOT iftop ;;
        3) $NH_ROOT nethogs ;;
        *) warn "Khong hop le" ;;
    esac
}

enable_autostart() {
    if ! grep -q "kali-pro.sh" ~/.bashrc 2>/dev/null; then
        echo "bash ~/kali-pro.sh" >> ~/.bashrc
        info "AutoStart da them vao .bashrc"
    else
        warn "AutoStart da ton tai"
    fi
}

show_menu() {
    clear
    echo "================================================"
    echo "  KALI PRO GHOST EDITION – MINIMAL             "
    echo "================================================"
    echo ""
    echo " 1) KHOI DONG HOAN CHINH (Desktop + VPN + Tor + MAC + Stealth)"
    echo " 2) DUNG TAT CA DICH VU"
    echo " 3) Kich hoat Kill Switch (chi VPN)"
    echo " 4) Tat Kill Switch"
    echo " 5) Live Network Monitor"
    echo " 6) Xoa sach dau vet (wipe traces)"
    echo " 7) Toi uu he thong"
    echo " 8) Bat AutoStart"
    echo " 9) PANIC BUTTON – Dung khan cap"
    echo "10) Thoat"
    echo ""
    echo "TRANG THAI:"
    echo "  VPN : $(pgrep -f openvpn >/dev/null && echo "[ON]" || echo "[OFF]")"
    echo "  Tor : $(pgrep -f tor >/dev/null && echo "[ON]" || echo "[OFF]")"
    echo "  Desktop : $(pgrep -f kex >/dev/null && echo "[ON]" || echo "[OFF]")"
    echo "  Kill Switch : $($NH_ROOT iptables -L OUTPUT 2>/dev/null | grep -q DROP && echo "[ON]" || echo "[OFF]")"
    echo ""
    read -p "Lua chon cua ban (1-10): " choice
}

first_time_setup() {
    info "Kiem tra ket noi internet..."
    if ! check_internet; then
        error "Khong co ket noi mang. Vui long kiem tra lai."
        exit 1
    fi
    info "Bat dau cai dat toan dien Kali Ghost Edition..."
    system_optimize
    ensure_pkg "xfce4" true
    ensure_pkg "kali-desktop-xfce" true
    ensure_pkg "kex" true
    ensure_pkg "openvpn" true
    ensure_pkg "tor" true
    ensure_pkg "macchanger" true
    ensure_pkg "iptables" true
    ensure_pkg "bmon iftop nethogs" true
    $NH_ROOT mkdir -p /root/.config/xfce4/panel 2>/dev/null
    $NH_CMD kex --set-shared -y 2>/dev/null
    info "Cai dat hoan tat! Ban co the khoi dong desktop bang option 1."
    sleep 2
}

main() {
    if [ ! -f "$CONFIG_DIR/.installed" ]; then
        first_time_setup
        touch "$CONFIG_DIR/.installed"
    fi
    while true; do
        show_menu
        case $choice in
            1) start_desktop; read -p "Nhan Enter de tiep tuc..." ;;
            2) stop_desktop; read -p "Nhan Enter..." ;;
            3) enable_kill_switch; read -p "Nhan Enter..." ;;
            4) disable_kill_switch; read -p "Nhan Enter..." ;;
            5) network_monitor; read -p "Nhan Enter..." ;;
            6) wipe_traces; read -p "Nhan Enter..." ;;
            7) system_optimize; read -p "Nhan Enter..." ;;
            8) enable_autostart; read -p "Nhan Enter..." ;;
            9) panic_mode; read -p "Nhan Enter..." ;;
            10) info "Tam biet!"; exit 0 ;;
            *) error "Lua chon khong hop le"; sleep 1 ;;
        esac
    done
}

trap 'echo -e "\nThoat khan cap..."; exit 0' INT

main
