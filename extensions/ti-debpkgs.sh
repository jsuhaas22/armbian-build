function extension_finish_config__install_kernel_headers_for_ti() {
	if [[ "${KERNEL_HAS_WORKING_HEADERS}" != "yes" ]]; then
		display_alert "Kernel version has no working headers package" "skipping TI for kernel v${KERNEL_MAJOR_MINOR}" "warn"
		return 0
	fi
	declare -g INSTALL_HEADERS="yes"
	display_alert "Forcing INSTALL_HEADERS=yes; for use with TI " "${EXTENSION}" "debug"
}

function extension_prepare_config__specify_packages() {
	add_packages_to_rootfs ${BOARD_PACKAGES[@]}
}

#function pre_install_distribution_specific__install_ti_packages() {
function custom_apt_repo__install_ti_packages() {
	# Fetch valid suites from TI repo
	valid_suites=($(curl -s "https://api.github.com/repos/TexasInstruments/ti-debpkgs/contents/dists" | jq -r '.[].name'))
	display_alert "TI Repo has the following valid suites - ${valid_suites[@]}..."

	if [[ " ${valid_suites[@]} " =~ " ${RELEASE} " ]]; then
		display_alert "$RELEASE is valid"

		# Get the sources file
		run_host_command_logged "wget -qO $SDCARD/tmp/ti-debpkgs.sources https://raw.githubusercontent.com/TexasInstruments/ti-debpkgs/main/ti-debpkgs.sources"
		display_alert "Got ti-debpkgs.sources..."

		# Update suite in sources file
		chroot_sdcard "sed -i 's/bookworm/${RELEASE}/g' /tmp/ti-debpkgs.sources"
		display_alert "Updated Suite to ${RELEASE}..."

		# Copy updated sources file into chroot
		chroot_sdcard "cp /tmp/ti-debpkgs.sources /etc/apt/sources.list.d/ti-debpkgs.sources"
		display_alert "Added ti-debpkgs.sources"

		# Clean up inside the chroot
		chroot_sdcard "rm -f /tmp/ti-debpkgs.sources"

		run_host_command_logged "mkdir -p $destination/etc/apt/preferences.d/"
		run_host_command_logged "cp $SRC/packages/bsp/ti-k3/ti-debpkgs/ti-debpkgs $destination/etc/apt/preferences.d/"

	#	chroot_sdcard_apt_get_update || true
	#	chroot_sdcard_apt_get_install "vim" "weston" "seatd" "cc33xx-fw" "cc33xx-target-scripts" "ti-lvgl-demo"

	else
		# Error if suite is not valid but continue building image anyway
		display_alert "Error: Detected OS suite '$RELEASE' is not valid based on TI package repository. Skipping!"
		display_alert "Valid Options Would Have Been: ${valid_suites[@]}"
	fi
}

function pre_customize_image__enable_services() {
	if [[ ${BOARD_NAME} != "SK-AM62L" ]] ; then
		return
	fi

	run_host_command_logged "mkdir -p $DEST/lib/systemd/system/"
	run_host_command_logged "cp -v $SRC/packages/bsp/ti-k3/weston/weston.socket $SDCARD/lib/systemd/system/weston.socket"
	run_host_command_logged "cp -v $SRC/packages/bsp/ti-k3/weston/weston.service $SDCARD/lib/systemd/system/weston.service"
	run_host_command_logged "cp -v $SRC/packages/bsp/ti-k3/weston/weston $SDCARD/etc/default/weston"

	chroot_sdcard "systemctl enable weston" || display_alert "systemctl enable failed"
}
