#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
# KALI PRO GHOST EDITION – HỖ TRỢ WIFI ĐẦY ĐỦ & DẤU TIẾNG VIỆT
# ============================================================

VPN_CONFIG="$HOME/vpn.ovpn"
TOR_CONFIG="$HOME/.tor/torrc"
NH_CMD="nethunter"
NH_ROOT="$NH_CMD -r"
CONFIG_DIR="$HOME/.kali-pro"
LOCK_VPN="$CONFIG_DIR/vpn.lock"
LOCK_TOR="$CONFIG_DIR/tor.lock"
LOG_FILE="$CONFIG_DIR/setup.log"
WIFI_CONFIG_DIR="$CONFIG_DIR/wifi"
mkdir -p "$CONFIG_DIR" "$WIFI_CONFIG_DIR"
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
    info "Đang tối ưu hệ thống..."
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
    info "Tối ưu hoàn tất"
}

# -------------------- VPN --------------------
setup_vpn() {
    if [ ! -f "$VPN_CONFIG" ]; then
        warn "Không tìm thấy file VPN config tại $VPN_CONFIG"
        return 1
    fi
    ensure_pkg "openvpn" true
    if ! pgrep -f "openvpn.*$VPN_CONFIG" >/dev/null; then
        $NH_ROOT openvpn --config "$VPN_CONFIG" --daemon --writepid "$LOCK_VPN" \
            --redirect-gateway def1 --dhcp-option DNS 1.1.1.1 &>/dev/null
        info "VPN đã kết nối"
    else
        warn "VPN đang chạy"
    fi
}

stop_vpn() {
    $NH_ROOT pkill -f openvpn 2>/dev/null
    rm -f "$LOCK_VPN"
    info "VPN đã dừng"
}

# -------------------- TOR --------------------
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
        info "Tor daemon đã khởi động"
    else
        warn "Tor đang chạy"
    fi
}

stop_tor() {
    $NH_ROOT pkill -f "tor.*-f $TOR_CONFIG" 2>/dev/null
    rm -f "$LOCK_TOR"
    info "Tor đã dừng"
}

# -------------------- MAC SPOOF --------------------
spoof_mac() {
    info "Đang làm mới địa chỉ MAC..."
    ensure_pkg "macchanger" true
    $NH_ROOT bash -c '
        for iface in $(ls /sys/class/net | grep -v lo); do
            ip link set "$iface" down
            macchanger -r "$iface" 2>/dev/null || \
            ip link set dev "$iface" address $(tr -dc a-f0-9 < /dev/urandom | head -c 12 | sed "s/\(..\)/\1:/g;s/:$//")
            ip link set "$iface" up
        done
    ' &>/dev/null &
    info "Địa chỉ MAC đã thay đổi ngẫu nhiên"
}

# -------------------- KILL SWITCH --------------------
enable_kill_switch() {
    info "Kích hoạt Kill Switch..."
    $NH_ROOT bash -c '
        iptables -P INPUT DROP
        iptables -P OUTPUT DROP
        iptables -P FORWARD DROP
        iptables -A OUTPUT -o tun+ -j ACCEPT
        iptables -A INPUT -i tun+ -j ACCEPT
        iptables -A OUTPUT -o lo -j ACCEPT
        iptables -A INPUT -i lo -j ACCEPT
    ' 2>/dev/null && info "Kill Switch đã bật" || error "Không thể thiết lập iptables"
}

disable_kill_switch() {
    $NH_ROOT bash -c '
        iptables -P INPUT ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -F
    ' 2>/dev/null && info "Kill Switch đã tắt" || error "Không thể reset iptables"
}

# -------------------- STEALTH --------------------
activate_stealth() {
    info "Kích hoạt chế độ tàng hình..."
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
    info "Stealth mode: hostname ngẫu nhiên, log trống, panel ẩn"
}

# -------------------- DESKTOP --------------------
setup_desktop() {
    info "Cài đặt môi trường desktop XFCE + Kali Desktop Experience..."
    ensure_pkg "kali-desktop-xfce" true
    ensure_pkg "xfce4" true
    ensure_pkg "xfce4-goodies" true
    ensure_pkg "kex" true
    $NH_CMD kex stop 2>/dev/null
    $NH_CMD kex --set-shared -y 2>/dev/null
    info "Desktop đã sẵn sàng. Dùng lệnh 'kex' để khởi động VNC."
}

start_desktop() {
    info "Khởi động Kali Desktop & VPN + Tor + Stealth..."
    $NH_ROOT xfwm4 --replace --compositor=off --daemon 2>/dev/null &
    setup_vpn
    setup_tor
    spoof_mac
    activate_stealth
    $NH_CMD kex --slim &>/dev/null &
    sleep 2
    info "Desktop đang chạy. Truy cập VNC tại localhost:5901 (mật khẩu: kali)"
}

stop_desktop() {
    info "Dừng toàn bộ dịch vụ..."
    $NH_CMD kex stop 2>/dev/null
    stop_vpn
    stop_tor
    disable_kill_switch
    info "Đã dừng desktop và các dịch vụ ẩn danh"
}

# -------------------- WIFI --------------------
check_wifi_tools() {
    ensure_pkg "aircrack-ng" true
    ensure_pkg "wireless-tools" true
    ensure_pkg "wpasupplicant" true
    ensure_pkg "network-manager" true
    ensure_pkg "iw" true
}

wifi_list_interfaces() {
    $NH_ROOT bash -c "iwconfig 2>/dev/null | grep -o '^[a-zA-Z0-9]*' | grep -v '^$'"
}

wifi_enable_monitor() {
    check_wifi_tools
    local iface
    iface=$(wifi_list_interfaces | head -1)
    if [ -z "$iface" ]; then
        error "Không tìm thấy card mạng wifi."
        return 1
    fi
    info "Đang bật chế độ monitor trên $iface..."
    $NH_ROOT bash -c "
        airmon-ng check kill
        ip link set $iface down
        iw dev $iface set type monitor 2>/dev/null || airmon-ng start $iface
        ip link set $iface up
    " &>/dev/null
    if $NH_ROOT iw dev $iface info 2>/dev/null | grep -q "type monitor"; then
        info "Chế độ monitor đã bật trên $iface"
    else
        error "Không thể bật monitor mode"
    fi
}

wifi_disable_monitor() {
    local iface
    iface=$(wifi_list_interfaces | head -1)
    [ -z "$iface" ] && iface="wlan0"
    info "Đang tắt chế độ monitor trên $iface..."
    $NH_ROOT bash -c "
        ip link set $iface down
        iw dev $iface set type managed 2>/dev/null || airmon-ng stop ${iface}mon 2>/dev/null
        ip link set $iface up
        systemctl restart NetworkManager 2>/dev/null
    " &>/dev/null
    info "Đã tắt monitor mode (nếu có)."
}

wifi_scan() {
    check_wifi_tools
    local iface
    iface=$(wifi_list_interfaces | head -1)
    if [ -z "$iface" ]; then
        error "Không tìm thấy card wifi."
        return 1
    fi
    info "Đang quét mạng wifi trên $iface (5 giây)..."
    $NH_ROOT bash -c "iw dev $iface scan | grep -E 'SSID:|signal:' | paste -d ' ' - - | sed 's/SSID: //g; s/signal: //g'" || \
    $NH_ROOT bash -c "nmcli dev wifi list ifname $iface" 2>/dev/null
    read -p "Nhấn Enter để tiếp tục..."
}

wifi_connect() {
    check_wifi_tools
    local iface ssid psk
    iface=$(wifi_list_interfaces | head -1)
    if [ -z "$iface" ]; then
        error "Không tìm thấy card wifi."
        return 1
    fi
    read -p "Nhập tên mạng (SSID): " ssid
    read -p "Nhập mật khẩu (để trống nếu không có): " psk
    if [ -z "$psk" ]; then
        # mạng mở
        $NH_ROOT bash -c "
            ip link set $iface up
            iw dev $iface connect \"$ssid\"
        " 2>/dev/null
    else
        # mạng có mật khẩu
        local conf_file="$WIFI_CONFIG_DIR/wpa_$ssid.conf"
        $NH_ROOT bash -c "wpa_passphrase \"$ssid\" \"$psk\" > $conf_file"
        $NH_ROOT bash -c "
            ip link set $iface up
            wpa_supplicant -B -i $iface -c $conf_file
            dhclient $iface 2>/dev/null || dhcpcd $iface 2>/dev/null
        " &>/dev/null
    fi
    info "Đã kết nối $ssid (kiểm tra bằng ping)."
}

wifi_show_status() {
    local iface
    iface=$(wifi_list_interfaces | head -1)
    echo "===== Trạng thái WIFI ====="
    $NH_ROOT iw dev $iface link 2>/dev/null || echo "Chưa kết nối"
    echo "----------------------------"
    $NH_ROOT ifconfig $iface 2>/dev/null | grep -E 'inet|ether' || echo "Không có IP"
    echo "============================"
}

wifi_menu() {
    while true; do
        clear
        echo "========================================"
        echo "        QUẢN LÝ WIFI – GHOST EDITION   "
        echo "========================================"
        echo " 1) Bật chế độ Monitor"
        echo " 2) Tắt chế độ Monitor"
        echo " 3) Quét mạng wifi xung quanh"
        echo " 4) Kết nối wifi (thủ công)"
        echo " 5) Hiển thị trạng thái kết nối"
        echo " 6) Quay lại menu chính"
        echo "========================================"
        read -p "Lựa chọn của bạn (1-6): " wchoice
        case $wchoice in
            1) wifi_enable_monitor; read -p "Nhấn Enter..." ;;
            2) wifi_disable_monitor; read -p "Nhấn Enter..." ;;
            3) wifi_scan ;;
            4) wifi_connect; read -p "Nhấn Enter..." ;;
            5) wifi_show_status; read -p "Nhấn Enter..." ;;
            6) break ;;
            *) error "Lựa chọn không hợp lệ"; sleep 1 ;;
        esac
    done
}

# -------------------- DẤU VẾT --------------------
wipe_traces() {
    warn "XÓA HOÀN TOÀN MỌI DẤU VẾT? (y/N): "
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || return
    info "Đang tẩy sạch dấu vết..."
    $NH_ROOT bash -c '
        find /home /root -name ".bash_history" -exec truncate -s 0 {} \;
        find /home /root -name ".zsh_history" -exec truncate -s 0 {} \;
        find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
        rm -rf /tmp/* /var/tmp/* 2>/dev/null
        > /var/log/lastlog 2>/dev/null
        history -c
    ' 2>/dev/null
    history -c
    info "Đã xóa sạch"
}

# -------------------- PANIC --------------------
panic_mode() {
    warn "KÍCH HOẠT PANIC – HỦY MỌI TIẾN TRÌNH"
    $NH_ROOT bash -c '
        pkill -9 -f kex 2>/dev/null
        pkill -9 -f openvpn 2>/dev/null
        pkill -9 -f tor 2>/dev/null
        pkill -9 -f msfconsole 2>/dev/null
        pkill -9 -f wireshark 2>/dev/null
        pkill -9 -f xfce4 2>/dev/null
        pkill -9 -f wpa_supplicant 2>/dev/null
        pkill -9 -f dhclient 2>/dev/null
        pkill -9 -f dhcpcd 2>/dev/null
        airmon-ng stop wlan0mon 2>/dev/null
        iptables -P INPUT ACCEPT 2>/dev/null
        iptables -P OUTPUT ACCEPT 2>/dev/null
        iptables -P FORWARD ACCEPT 2>/dev/null
        iptables -F 2>/dev/null
    ' 2>/dev/null
    rm -f "$LOCK_VPN" "$LOCK_TOR"
    clear
    echo "========================================"
    echo "      PANIC MODE ACTIVATED              "
    echo "   MỌI THỨ ĐÃ DỪNG & FIREWALL RESET    "
    echo "========================================"
    sleep 2
}

# -------------------- MONITOR --------------------
network_monitor() {
    ensure_pkg "bmon" true
    ensure_pkg "iftop" true
    ensure_pkg "nethogs" true
    echo "1) bmon   – Băng thông tổng"
    echo "2) iftop  – Kết nối theo IP"
    echo "3) nethogs – Tiến trình sử dụng mạng"
    read -p "Chọn: " mon
    case $mon in
        1) $NH_ROOT bmon ;;
        2) $NH_ROOT iftop ;;
        3) $NH_ROOT nethogs ;;
        *) warn "Không hợp lệ" ;;
    esac
}

# -------------------- AUTO START --------------------
enable_autostart() {
    if ! grep -q "kali-pro.sh" ~/.bashrc 2>/dev/null; then
        echo "bash ~/kali-pro.sh" >> ~/.bashrc
        info "AutoStart đã thêm vào .bashrc"
    else
        warn "AutoStart đã tồn tại"
    fi
}

# -------------------- MENU CHÍNH --------------------
show_menu() {
    clear
    echo "================================================"
    echo "  KALI PRO GHOST EDITION – HỖ TRỢ WIFI ĐẦY ĐỦ "
    echo "================================================"
    echo ""
    echo " 1) KHỞI ĐỘNG HOÀN CHỈNH (Desktop + VPN + Tor + MAC + Stealth)"
    echo " 2) DỪNG TẤT CẢ DỊCH VỤ"
    echo " 3) Kích hoạt Kill Switch (chỉ VPN)"
    echo " 4) Tắt Kill Switch"
    echo " 5) Live Network Monitor"
    echo " 6) Xóa sạch dấu vết (wipe traces)"
    echo " 7) Tối ưu hệ thống"
    echo " 8) Bật AutoStart"
    echo " 9) WIFI TOOLS (Monitor, scan, connect...)"
    echo "10) PANIC BUTTON – Dừng khẩn cấp"
    echo "11) Thoát"
    echo ""
    echo "TRẠNG THÁI:"
    echo "  VPN : $(pgrep -f openvpn >/dev/null && echo "[BẬT]" || echo "[TẮT]")"
    echo "  Tor : $(pgrep -f tor >/dev/null && echo "[BẬT]" || echo "[TẮT]")"
    echo "  Desktop : $(pgrep -f kex >/dev/null && echo "[BẬT]" || echo "[TẮT]")"
    echo "  Kill Switch : $($NH_ROOT iptables -L OUTPUT 2>/dev/null | grep -q DROP && echo "[BẬT]" || echo "[TẮT]")"
    echo ""
    read -p "Lựa chọn của bạn (1-11): " choice
}

first_time_setup() {
    info "Kiểm tra kết nối internet..."
    if ! check_internet; then
        error "Không có kết nối mạng. Vui lòng kiểm tra lại."
        exit 1
    fi
    info "Bắt đầu cài đặt toàn diện Kali Ghost Edition..."
    system_optimize
    ensure_pkg "xfce4" true
    ensure_pkg "kali-desktop-xfce" true
    ensure_pkg "kex" true
    ensure_pkg "openvpn" true
    ensure_pkg "tor" true
    ensure_pkg "macchanger" true
    ensure_pkg "iptables" true
    ensure_pkg "bmon iftop nethogs" true
    ensure_pkg "aircrack-ng wireless-tools wpasupplicant network-manager iw" true
    $NH_ROOT mkdir -p /root/.config/xfce4/panel 2>/dev/null
    $NH_CMD kex --set-shared -y 2>/dev/null
    info "Cài đặt hoàn tất! Bạn có thể khởi động desktop bằng option 1."
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
            1) start_desktop; read -p "Nhấn Enter để tiếp tục..." ;;
            2) stop_desktop; read -p "Nhấn Enter..." ;;
            3) enable_kill_switch; read -p "Nhấn Enter..." ;;
            4) disable_kill_switch; read -p "Nhấn Enter..." ;;
            5) network_monitor; read -p "Nhấn Enter..." ;;
            6) wipe_traces; read -p "Nhấn Enter..." ;;
            7) system_optimize; read -p "Nhấn Enter..." ;;
            8) enable_autostart; read -p "Nhấn Enter..." ;;
            9) wifi_menu ;;
            10) panic_mode; read -p "Nhấn Enter..." ;;
            11) info "Tạm biệt!"; exit 0 ;;
            *) error "Lựa chọn không hợp lệ"; sleep 1 ;;
        esac
    done
}

trap 'echo -e "\nThoát khẩn cấp..."; exit 0' INT

m
