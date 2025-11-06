#!/bin/sh

# Setup logging
LOG_FILE="/root/setup-xidzswrt.log"
exec > "$LOG_FILE" 2>&1

# All variables declaration
declare_variables() {
    SYSTEM_JS="/www/luci-static/resources/view/status/include/10_system.js"
    PORTS_JS="/www/luci-static/resources/view/status/include/29_ports.js"
    NEW_PORTS_JS="/www/luci-static/resources/view/status/include/11_ports.js"
    RELEASE_FILE="/etc/openwrt_release"
    TTYD_JSON="/usr/share/luci/menu.d/luci-app-ttyd.json"
    TEMP_JS="/www/luci-static/resources/view/status/include/27_temperature.js"
    NEW_TEMP_JS="/www/luci-static/resources/view/status/include/15_temperature.js"
    RC_LOCAL="/etc/rc.local"
    CRONTAB_ROOT="/etc/crontabs/root"
    USB_MODE="/etc/usb-mode.json"
    OPKG_CONF="/etc/opkg.conf"
    SYSINFO_SH="/etc/profile.d/30-sysinfo.sh"
    PROFILE="/etc/profile"
    INSTALL2_SH="/root/install2.sh"
    RULES_SH="/root/rules.sh"
    INDOWRT_SH="/root/indowrt.sh"
    CLASH_META="/etc/openclash/core/clash_meta"
    COUNTRY_MMDB="/etc/openclash/Country.mmdb"
    PHP_INI="/etc/php.ini"
    PHP_INI_BAK="/etc/php.ini.bak"
    VNSTAT_CONF="/etc/vnstat.conf"
    HAT_WWAN="/etc/hotplug.d/usb/23-wwan_hat"
    HAT_WIFI="/etc/hotplug.d/usb/99-wifi_hat"
    MM_TTY="/etc/hotplug.d/tty/25-modemmanager-tty"
    ARGON_CONF="/usr/share/ucode/luci/template/themes/argon/header.ut"
    RTA_CONF="/usr/lib/lua/luci/view/themes/rtawrt/header.htm"
    ALPHA_CONF="/etc/config/alpha"
    K5_GPIO="/usr/bin/k5hgled"
    K6_GPIO="/usr/bin/k6hgled"
    X_GPIO="/usr/bin/x-gpioled"
    K5_GPIO_ON="/usr/bin/k5hgledon"
    K6_GPIO_ON="/usr/bin/k6hgledon"
    X_GPIO_ON="/usr/bin/x-gpioledon"
    
    # Export variables to make them accessible across all functions
    export SYSTEM_JS PORTS_JS NEW_PORTS_JS RELEASE_FILE TTYD_JSON TEMP_JS NEW_TEMP_JS
    export RC_LOCAL CRONTAB_ROOT USB_MODE OPKG_CONF SYSINFO_SH PROFILE
    export INSTALL2_SH RULES_SH INDOWRT_SH CLASH_META COUNTRY_MMDB
    export PHP_INI PHP_INI_BAK VNSTAT_CONF HAT_WWAN HAT_WIFI MM_TTY
    export ARGON_CONF RTA_CONF ALPHA_CONF K5_GPIO
    export K6_GPIO X_GPIO K5_GPIO_ON K6_GPIO_ON X_GPIO_ON 
}

# Logging function with status
log_status() {
    local status="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$status] $message"
}

# Print header log
print_header() {
    log_status "INFO" "========================================="
    log_status "INFO" "XIDZs-WRT Setup Script Started"
    log_status "INFO" "Script Setup By Fidz"
    log_status "INFO" "Installed Time: $(date '+%A, %d %B %Y %T')"
    log_status "INFO" "========================================="
}

# Modify firmware display information
modify_firmware_display() {
    log_status "INFO" "Modifying firmware display..."
    sed -i "s#_('Firmware Version'),(L.isObject(boardinfo.release)?boardinfo.release.description+' / ':'')+(luciversion||''),#_('Firmware Version'),(L.isObject(boardinfo.release)?boardinfo.release.description+' | Fidz':''),#g" "$SYSTEM_JS"
    sed -i -E 's/icons\/port_%s\.(svg|png)/icons\/port_%s.gif/g' "$PORTS_JS"
    mv "$PORTS_JS" "$NEW_PORTS_JS"
}

# Set permissions for directories and scripts
set_permissions() {
    log_status "INFO" "Setting permissions for directories and scripts..."
    chmod -R +x /sbin /usr/bin /etc/init.d
    chmod +x "$INSTALL2_SH" "$INDOWRT_SH" "$RULES_SH"
}

# Check for specific device models
check_device_model() {
    log_status "INFO" "Checking device model..."
    if grep -q "OrangePi Zero3" /proc/device-tree/model 2>/dev/null; then
        log_status "INFO" "OrangePi Zero3 detected..."
        chmod +x "$HAT_WWAN" "$HAT_WIFI"
    else
        log_status "INFO" "Generic devices detected.."
        rm -f "$HAT_WIFI" "$HAT_WWAN"
        rm -f "$MM_TTY"
    fi
}

# Check system release version
check_system_release() {
    log_status "INFO" "Checking system release..."
    if grep -q "ImmortalWrt" /etc/openwrt_release; then
        sed -i 's/\(DISTRIB_DESCRIPTION='\''ImmortalWrt [0-9]*\.[0-9]*\.[0-9]*\).*'\''/\1'\''/g' "$RELEASE_FILE"
        sed -i 's|system/ttyd|services/ttyd|g' "$TTYD_JSON"
        BRANCH_VERSION=$(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')
        log_status "INFO" "ImmortalWrt detected - $BRANCH_VERSION"
    elif grep -q "OpenWrt" /etc/openwrt_release; then
        sed -i 's/\(DISTRIB_DESCRIPTION='\''OpenWrt [0-9]*\.[0-9]*\.[0-9]*\).*'\''/\1'\''/g' "$RELEASE_FILE"
        mv "$TEMP_JS" "$NEW_TEMP_JS"
        BRANCH_VERSION=$(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')
        log_status "INFO" "OpenWrt detected - $BRANCH_VERSION"
    else
        log_status "WARNING" "Unknown system release"
    fi
}

# Setup root password
setup_root_password() {
    log_status "INFO" "Setting up root password..."
    (echo "quenx"; sleep 2; echo "quenx") | passwd > /dev/null
}

# Configure hostname and timezone settings
configure_hostname_timezone() {
    log_status "INFO" "Configuring hostname and timezone..."
    uci set system.@system[0].hostname='XIDZs-WRT'
    uci set system.@system[0].timezone='WIB-7'
    uci set system.@system[0].zonename='Asia/Jakarta'
    uci delete system.ntp.server
    uci add_list system.ntp.server='pool.ntp.org'
    uci add_list system.ntp.server='id.pool.ntp.org'
    uci add_list system.ntp.server='time.google.com'
    uci commit system
}

# Set default language to English
set_default_language() {
    log_status "INFO" "Setting default language to English..."
    uci set luci.@core[0].lang='en'
    uci commit luci
}

# Configure network interfaces (WAN, LAN)
configure_network() {
    log_status "INFO" "Configuring network interfaces..."
    uci set network.tethering=interface
    uci set network.tethering.proto='dhcp'
    uci set network.tethering.device='usb0'
    uci set network.wan=interface
    uci set network.wan.proto='dhcp'
    uci set network.wan.device='eth1'
    uci set network.mm=interface
    uci set network.mm.proto='modemmanager'
    uci set network.mm.device='/sys/devices/platform/scb/fd500000.pcie/pci0000:00/0000:00:00.0/0000:01:00.0/usb2/2-1'
    uci set network.mm.apn='internet'
    uci set network.mm.auth='none'
    uci set network.mm.iptype='ipv4'
    uci set network.mm.force_connection='1'
    uci delete network.wan6
    uci commit network

    log_status "INFO" "Configuring firewall..."
    uci set firewall.@zone[1].network='tethering wan mm'
    uci commit firewall
}

# Configure wireless settings
configure_wireless() {
    log_status "INFO" "Configuring wireless..."
    uci set wireless.@wifi-device[0].disabled='0'
    uci set wireless.@wifi-iface[0].disabled='0'
    uci set wireless.@wifi-iface[0].mode='ap'
    uci set wireless.@wifi-iface[0].encryption='psk2'
    uci set wireless.@wifi-iface[0].key='XIDZs2025'
    uci set wireless.@wifi-device[0].country='ID'

    # Check for Raspberry Pi devices and configure accordingly
    if grep -q "Raspberry Pi 4\|Raspberry Pi 3" /proc/cpuinfo; then
        log_status "INFO" "Raspberry Pi detected - configuring 5GHz WiFi..."
        uci set wireless.@wifi-iface[0].ssid='XIDZs-WRT_5G'
        uci set wireless.@wifi-device[0].channel='149'
        uci set wireless.@wifi-device[0].htmode='VHT80'
    else
        log_status "INFO" "Generic device detected - configuring 2.4GHz WiFi..."
        uci set wireless.@wifi-iface[0].ssid='XIDZs-WRT'
        uci set wireless.@wifi-device[0].channel='1'
        uci set wireless.@wifi-device[0].htmode='HT20'
    fi

    uci commit wireless
    wifi reload && wifi up > /dev/null
}

# Check wireless interface and add startup scripts for Raspberry Pi
check_wireless_interface() {
    if iw dev | grep -q Interface; then
        if grep -q "Raspberry Pi 4\|Raspberry Pi 3" /proc/cpuinfo; then
            log_status "INFO" "Adding wireless startup scripts for Raspberry Pi..."
            if ! grep -q "wifi up" /etc/rc.local; then
                sed -i '/exit 0/i # remove if you dont use wireless' "$RC_LOCAL"
                sed -i '/exit 0/i sleep 10 && wifi up' "$RC_LOCAL"
            fi
            if ! grep -q "wifi up" /etc/crontabs/root; then
                echo "# remove if you dont use wireless" >> /etc/crontabs/root
                echo "0 */12 * * * wifi down && sleep 5 && wifi up" >> /etc/crontabs/root
                /etc/init.d/cron restart > /dev/null
            fi
        fi
    fi
}

# Remove specific USB modeswitch entries (Huawei ME909S and DW5821E)
remove_usb_modeswitch() {
    log_status "INFO" "Removing USB modeswitch entries..."
    sed -i -e '/12d1:15c1/,+5d' -e '/413c:81d7/,+5d' "$USB_MODE"
}

# Disable XMM-Modem service
disable_xmm_modem() {
    log_status "INFO" "Disabling XMM-Modem..."
    uci set xmm-modem.@xmm-modem[0].enable='0'
    uci commit xmm-modem
}

# Disable OPKG signature verification
disable_opkg_signature() {
    log_status "INFO" "Disabling OPKG signature check..."
    sed -i 's/option check_signature/# option check_signature/g' "$OPKG_CONF"
}

# Add custom package repository
add_custom_repository() {
    log_status "INFO" "Adding custom repository..."
    ARCH=$(grep "OPENWRT_ARCH" /etc/os-release | awk -F '"' '{print $2}')
    echo "src/gz custom_packages https://dl.openwrt.ai/latest/packages/$ARCH/kiddin9" >> /etc/opkg/customfeeds.conf
}

# Set Argon as default theme
setup_default_theme() {
    log_status "INFO" "Setting Argon theme as default..."
    uci set luci.main.mediaurlbase='/luci-static/argon'
    uci commit luci
}

# Configure TTYD terminal settings
configure_ttyd() {
    log_status "INFO" "Configuring TTYD..."
    uci set ttyd.@ttyd[0].command='/bin/bash --login'
    uci commit ttyd
}

# Create symbolic link for TinyFM file manager
create_tinyfm_symlink() {
    log_status "INFO" "Creating TinyFM symlink..."
    ln -sf / /www/tinyfm/rootfs
}

# Add various startup scripts for time sync and cache cleanup
add_startup_scripts() {
    log_status "INFO" "Adding startup scripts..."
    sed -i '/exit 0/i #/etc/init.d/openclash restart' "$RC_LOCAL"
    sed -i '/exit 0/i #sleep 5 && /sbin/free.sh' "$RC_LOCAL"
    sed -i '/exit 0/i #/sbin/jam bug.com' "$RC_LOCAL"
}

# Setup configuration for Amlogic devices
setup_amlogic_device() {
    log_status "INFO" "Checking for Amlogic device configuration..."
    if opkg list-installed | grep -q luci-app-amlogic; then
        log_status "INFO" "luci-app-amlogic detected"
        rm -f "$SYSINFO_SH"
        sed -i '/exit 0/i #sleep 5 && /usr/bin/x-gpioled -r' "$RC_LOCAL"
    else
        log_status "INFO" "luci-app-amlogic not detected"
        rm -f "$K5_GPIO" "$K6_GPIO"
        rm -f "$X_GPIO" "$X_GPIO_ON"
        rm -f "$K5_GPIO_ON" "$K6_GPIO_ON"
    fi
}

# Setup miscellaneous system configurations
setup_misc_settings() {
    log_status "INFO" "Setting up misc configurations..."
    sed -i -e 's/\[ -f \/etc\/banner \] && cat \/etc\/banner/#&/' -e 's/\[ -n \"\$FAILSAFE\" \] && cat \/etc\/banner.failsafe/& || \/usr\/bin\/quenx/' "$PROFILE"
    /etc/init.d/issue enable > /dev/null
}

# Execute additional configuration scripts
run_additional_scripts() {
    log_status "INFO" "Running install2 script..."
    "$INSTALL2_SH"

    log_status "INFO" "Running rules script..."
    "$RULES_SH"

    log_status "INFO" "Running TTL script..."
    "$INDOWRT_SH"
}

# Check and configure VPN/tunnel
setup_tunnel_applications() {
    log_status "INFO" "Checking tunnel applications..."

    for pkg in luci-app-openclash luci-app-nikki luci-app-passwall; do
        if opkg list-installed | grep -qw "$pkg"; then
            log_status "INFO" "$pkg detected"
            
            case "$pkg" in
                luci-app-openclash)
                    log_status "INFO" "Configuring OpenClash..."
                    chmod +x "$CLASH_META"
                    chmod +x "$COUNTRY_MMDB"
                    chmod +x /etc/openclash/Geo*
                    
                    ln -sf /etc/openclash/history/quenx.db /etc/openclash/cache.db
                    ln -sf /etc/openclash/core/clash_meta /etc/openclash/clash
                    
                    rm -f /etc/config/openclash    
                    mv /etc/config/openclash1 /etc/config/openclash
                    
                    sed -i '103,105s/.*/<\!-- & -->/' "$RTA_CONF"
                    sed -i '144s/.*/<\!-- & -->/' "$ARGON_CONF"
                    sed -i "88s/'Enable'/'Disable'/" "$ALPHA_CONF"
                    ;;
                    
                luci-app-nikki)
                    log_status "INFO" "Configuring Nikki..."                
                    chmod +x /etc/nikki/run/Geo*
                    rm -rf /etc/nikki/run/proxy_provider
                    rm -rf /etc/nikki/run/rule_provider
                    
                    log_status "INFO" "Creating symlinks from OpenClash to Nikki..."
                    ln -sf /etc/openclash/proxy_provider /etc/nikki/run
                    ln -sf /etc/openclash/rule_provider /etc/nikki/run
                    
                    sed -i '115,117s/.*/<\!-- & -->/' "$RTA_CONF"
                    sed -i '146s/.*/<\!-- & -->/' "$ARGON_CONF"
                    sed -i "40s/'Enable'/'Disable'/" "$ALPHA_CONF"
                    ;;
                    
                luci-app-passwall)
                    log_status "INFO" "Configuring Passwall..."
                    sed -i '112,114s/.*/<\!-- & -->/' "$RTA_CONF"
                    sed -i '147s/.*/<\!-- & -->/' "$ARGON_CONF"
                    sed -i "72s/'Enable'/'Disable'/" "$ALPHA_CONF"
                    ;;
            esac
            
        else
            log_status "INFO" "$pkg not detected, cleaning up..."
            
            case "$pkg" in
                luci-app-openclash)
                    rm -f /etc/config/openclash1
                    rm -rf /etc/openclash
                    
                    sed -i '118,120s/.*/<\!-- & -->/' "$RTA_CONF"
                    sed -i '149s/.*/<\!-- & -->/' "$ARGON_CONF"
                    sed -i "104s/'Enable'/'Disable'/" "$ALPHA_CONF"
                    ;;
                    
                luci-app-nikki)
                    rm -rf /etc/nikki
                    
                    sed -i '121,123s/.*/<\!-- & -->/' "$RTA_CONF"
                    sed -i '150s/.*/<\!-- & -->/' "$ARGON_CONF"
                    sed -i "120s/'Enable'/'Disable'/" "$ALPHA_CONF"
                    ;;
                    
                luci-app-passwall)
                    rm -f /etc/config/passwall
                    
                    sed -i '124,126s/.*/<\!-- & -->/' "$RTA_CONF"
                    sed -i '151s/.*/<\!-- & -->/' "$ARGON_CONF"
                    sed -i "136s/'Enable'/'Disable'/" "$ALPHA_CONF"
                    ;;
            esac
        fi
    done
}

# Configure uhttpd web server and PHP8 settings
configure_uhttpd_php() {
    log_status "INFO" "Configuring uhttpd and PHP8..."

    # Configure uhttpd web server
    uci set uhttpd.main.ubus_prefix='/ubus'
    uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
    uci set uhttpd.main.index_page='cgi-bin/luci'
    uci add_list uhttpd.main.index_page='index.html'
    uci add_list uhttpd.main.index_page='index.php'
    uci commit uhttpd

    # Configure PHP settings
    cp /etc/php.ini "$PHP_INI_BAK"
    sed -i 's|^memory_limit = .*|memory_limit = 128M|g' "$PHP_INI"
    sed -i 's|^max_execution_time = .*|max_execution_time = 60|g' "$PHP_INI"
    sed -i 's|^display_errors = .*|display_errors = Off|g' "$PHP_INI"
    sed -i 's|^;*date\.timezone =.*|date.timezone = Asia/Jakarta|g' "$PHP_INI"

    ln -sf /usr/lib/php8
    /etc/init.d/uhttpd restart > /dev/null
}

# Print footer log information
print_footer() {
    log_status "INFO" "========================================="
    log_status "INFO" "XIDZs-WRT Setup Script Finished"
    log_status "INFO" "Check log file: $LOG_FILE"
    log_status "INFO" "========================================="
}

# Clean up and exit
cleanup_and_exit() {
    sync
    rm -rf /etc/uci-defaults/$(basename "$0")
    exit 0
}

# Main execution function
main() {
    declare_variables
    print_header
    modify_firmware_display
    set_permissions
    check_device_model
    check_system_release
    setup_root_password
    configure_hostname_timezone
    set_default_language
    configure_network
    configure_wireless
    check_wireless_interface
    remove_usb_modeswitch
    disable_xmm_modem
    disable_opkg_signature
    add_custom_repository
    setup_default_theme
    configure_ttyd
    create_tinyfm_symlink
    add_startup_scripts
    setup_amlogic_device
    setup_misc_settings
    run_additional_scripts
    setup_tunnel_applications
    configure_uhttpd_php
    print_footer
    cleanup_and_exit
}

# Execute main function
main "$@"
