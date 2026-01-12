EXTENSIONS_DIR = $(shell pwd)
UROS_DIR = $(EXTENSIONS_DIR)/micro_ros_src
BUILD_DIR ?= $(EXTENSIONS_DIR)/build

DEBUG ?= 0
# 每次构建前清理构建产物（避免只因 log 存在而要求 clean）
CLEAN_BEFORE_BUILD ?= 1
PRE_CLEAN :=
ifeq ($(CLEAN_BEFORE_BUILD),1)
PRE_CLEAN := $(EXTENSIONS_DIR)/.microros_preclean
endif

# 默认 C 标准（避免 -DUCLIENT_C_STANDARD= 为空导致 CMake set_target_properties 参数错位）
# rcutils 使用 static_assert，需要 C11 及以上
C_STANDARD ?= 11
# sdkconfig.h 目录（从 esp-idf-sys 构建产物中自动发现）
SDKCONFIG_DIR ?= $(shell if [ -n "$(CARGO_TARGET_DIR)" ]; then ls -d "$(CARGO_TARGET_DIR)"/xtensa-esp32s3-espidf/*/build/esp-idf-sys-*/out/build/config 2>/dev/null | head -n 1; fi)
SDKCONFIG_BUILD_DIR ?= $(shell if [ -n "$(SDKCONFIG_DIR)" ]; then dirname "$(SDKCONFIG_DIR)"; fi)
IDF_SDKCONFIG_INCLUDES := $(if $(strip $(SDKCONFIG_DIR)),-I$(SDKCONFIG_DIR) -I$(SDKCONFIG_BUILD_DIR) -I$(SDKCONFIG_BUILD_DIR)/include,)
IDF_CORE_INCLUDES :=
ifneq ($(strip $(IDF_PATH)),)
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/esp_system/include
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/freertos/FreeRTOS-Kernel/include
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/freertos/FreeRTOS-Kernel/portable/xtensa/include
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/freertos/FreeRTOS-Kernel/portable/xtensa/include/freertos
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/freertos/esp_additions/include
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/freertos/config/include/freertos
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/freertos/config/include
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/freertos/config/xtensa/include
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/xtensa/include
	ifneq ($(strip $(IDF_TARGET)),)
		IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/xtensa/$(IDF_TARGET)/include
	endif
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/esp_hw_support/include
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/esp_common/include
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/heap/include
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/esp_rom/include
	ifneq ($(strip $(IDF_TARGET)),)
		IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/soc/$(IDF_TARGET)/include
		IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/soc/$(IDF_TARGET)/register
	endif
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/newlib/platform_include
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/lwip/port/include
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/lwip/port/freertos/include
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/lwip/port/esp32xx/include
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/lwip/lwip/src/include
	IDF_CORE_INCLUDES += -I$(IDF_PATH)/components/lwip/lwip/src/include/compat/posix
endif
IDF_INCLUDES := -I$(EXTENSIONS_DIR)/include_override $(IDF_INCLUDES) $(IDF_CORE_INCLUDES)

INSTALL_STAMP := $(UROS_DIR)/.install.stamp

ifeq ($(DEBUG), 1)
	BUILD_TYPE = Debug
else
	BUILD_TYPE = Release
endif

CFLAGS_INTERNAL := $(X_CFLAGS) -ffunction-sections -fdata-sections
CXXFLAGS_INTERNAL := $(X_CXXFLAGS) -ffunction-sections -fdata-sections

ifeq ($(strip $(X_CC)),)
$(error X_CC 未设置，请导出 X_CC/X_CXX/X_AR/X_STRIP 指向 xtensa-esp32s3-elf 工具链)
endif

all: $(EXTENSIONS_DIR)/libmicroros.a

clean:
	rm -rf $(EXTENSIONS_DIR)/libmicroros.a; \
	rm -rf $(EXTENSIONS_DIR)/include; \
	rm -rf $(EXTENSIONS_DIR)/esp32_toolchain.cmake; \
	rm -rf $(EXTENSIONS_DIR)/micro_ros_dev; \
	rm -rf $(EXTENSIONS_DIR)/micro_ros_src;

$(EXTENSIONS_DIR)/esp32_toolchain.cmake: $(EXTENSIONS_DIR)/esp32_toolchain.cmake.in
	rm -f $(EXTENSIONS_DIR)/esp32_toolchain.cmake; \
	cat $(EXTENSIONS_DIR)/esp32_toolchain.cmake.in | \
		sed "s/@CMAKE_C_COMPILER@/$(subst /,\/,$(X_CC))/g" | \
		sed "s/@CMAKE_CXX_COMPILER@/$(subst /,\/,$(X_CXX))/g" | \
		sed "s/@CFLAGS@/$(subst /,\/,$(CFLAGS_INTERNAL))/g" | \
		sed "s/@CXXFLAGS@/$(subst /,\/,$(CXXFLAGS_INTERNAL))/g" | \
		sed "s/@IDF_TARGET@/$(subst /,\/,$(IDF_TARGET))/g" | \
		sed "s/@IDF_PATH@/$(subst /,\/,$(IDF_PATH))/g" | \
		sed "s/@BUILD_CONFIG_DIR@/$(subst /,\/,$(BUILD_DIR)/config)/g" \
		> $(EXTENSIONS_DIR)/esp32_toolchain.cmake

$(EXTENSIONS_DIR)/micro_ros_dev/install:
	rm -rf micro_ros_dev; \
	mkdir micro_ros_dev; cd micro_ros_dev; \
	export GIT_HTTP_VERSION=HTTP/1.1; \
	git clone -b jazzy https://github.com/ament/ament_cmake src/ament_cmake; \
	git clone -b jazzy https://github.com/ament/ament_lint src/ament_lint; \
	git clone -b jazzy https://github.com/ament/ament_package src/ament_package; \
	git clone -b jazzy https://github.com/ament/googletest src/googletest; \
	git clone -b jazzy https://github.com/ros2/ament_cmake_ros src/ament_cmake_ros; \
	git clone -b jazzy https://github.com/ament/ament_index src/ament_index; \
	colcon build --cmake-args -DBUILD_TESTING=OFF -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=gcc;

$(EXTENSIONS_DIR)/micro_ros_src/src:
	rm -rf micro_ros_src; \
	mkdir micro_ros_src; cd micro_ros_src; \
	set -e; \
	if [ "$(MIDDLEWARE)" = "embeddedrtps" ]; then \
		$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/micro-ROS/embeddedRTPS main src/embeddedRTPS; \
		$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/micro-ROS/rmw_embeddedrtps main src/rmw_embeddedrtps; \
	else \
		$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/eProsima/Micro-XRCE-DDS-Client ros2 src/Micro-XRCE-DDS-Client; \
		$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/micro-ROS/rmw_microxrcedds jazzy src/rmw_microxrcedds; \
	fi; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/eProsima/micro-CDR ros2 src/micro-CDR; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/micro-ROS/rcl jazzy src/rcl; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/ros2/rclc jazzy src/rclc; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/micro-ROS/rcutils jazzy src/rcutils; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/micro-ROS/micro_ros_msgs jazzy src/micro_ros_msgs; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/micro-ROS/rosidl_typesupport jazzy src/rosidl_typesupport; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/micro-ROS/rosidl_typesupport_microxrcedds jazzy src/rosidl_typesupport_microxrcedds; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/ros2/rosidl jazzy src/rosidl; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/ros2/rosidl_dynamic_typesupport jazzy src/rosidl_dynamic_typesupport; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/ros2/rmw jazzy src/rmw; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/ros2/rcl_interfaces jazzy src/rcl_interfaces; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/ros2/rosidl_defaults jazzy src/rosidl_defaults; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/ros2/unique_identifier_msgs jazzy src/unique_identifier_msgs; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/ros2/common_interfaces jazzy src/common_interfaces; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/ros2/example_interfaces jazzy src/example_interfaces; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/ros2/test_interface_files jazzy src/test_interface_files; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/ros2/rmw_implementation jazzy src/rmw_implementation; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/ros2/rcl_logging jazzy src/rcl_logging; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/ros2/ros2_tracing jazzy src/ros2_tracing; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/micro-ROS/micro_ros_utilities jazzy src/micro_ros_utilities; \
	$(EXTENSIONS_DIR)/scripts/git_clone_retry.sh https://github.com/ros2/rosidl_core jazzy src/rosidl_core; \
	python3 "$(EXTENSIONS_DIR)/scripts/patch_rosidl_runtime_c.py" "src"; \
	: # disable expected-hash asserts (embedded build); \
	test -f src/rosidl/rosidl_runtime_c/src/type_description/field__description.c && \
		sed -i '/__EXPECTED_HASH/d' src/rosidl/rosidl_runtime_c/src/type_description/field__description.c || true; \
	test -f src/rosidl/rosidl_runtime_c/src/type_description/individual_type_description__description.c && \
		sed -i '/__EXPECTED_HASH/d' src/rosidl/rosidl_runtime_c/src/type_description/individual_type_description__description.c || true; \
	test -f src/rosidl/rosidl_runtime_c/src/type_description/type_description__description.c && \
		sed -i '/__EXPECTED_HASH/d' src/rosidl/rosidl_runtime_c/src/type_description/type_description__description.c || true; \
	: # remove remaining assert(memcmp...) lines that still reference EXPECTED_HASH; \
	test -f src/rosidl/rosidl_runtime_c/src/type_description/field__description.c && \
		sed -i '/assert(0 == memcmp.*EXPECTED_HASH/d' src/rosidl/rosidl_runtime_c/src/type_description/field__description.c || true; \
	test -f src/rosidl/rosidl_runtime_c/src/type_description/individual_type_description__description.c && \
		sed -i '/assert(0 == memcmp.*EXPECTED_HASH/d' src/rosidl/rosidl_runtime_c/src/type_description/individual_type_description__description.c || true; \
	test -f src/rosidl/rosidl_runtime_c/src/type_description/type_description__description.c && \
		sed -i '/assert(0 == memcmp.*EXPECTED_HASH/d' src/rosidl/rosidl_runtime_c/src/type_description/type_description__description.c || true; \
    mkdir -p src/rosidl/rosidl_typesupport_introspection_cpp; \
    mkdir -p src/rcl_logging/rcl_logging_log4cxx; \
    mkdir -p src/rcl_logging/rcl_logging_spdlog; \
    mkdir -p src/rclc/rclc_examples; \
	mkdir -p src/rcl/rcl_yaml_param_parser; \
	mkdir -p src/ros2_tracing/test_tracetools; \
	mkdir -p src/ros2_tracing/lttngpy; \
    touch src/rosidl/rosidl_typesupport_introspection_cpp/COLCON_IGNORE; \
    touch src/rcl_logging/rcl_logging_log4cxx/COLCON_IGNORE; \
    touch src/rcl_logging/rcl_logging_spdlog/COLCON_IGNORE; \
    touch src/rclc/rclc_examples/COLCON_IGNORE; \
	touch src/rcl/rcl_yaml_param_parser/COLCON_IGNORE; \
	touch src/ros2_tracing/test_tracetools/COLCON_IGNORE; \
	touch src/ros2_tracing/lttngpy/COLCON_IGNORE; \
	test -n "$(EXTRA_ROS_PACKAGES)" && cp -rf $(EXTRA_ROS_PACKAGES) src/extra_packages || :; \
	test -f src/extra_packages/extra_packages.repos && cd src/extra_packages && vcs import --input extra_packages.repos || :;


$(INSTALL_STAMP): $(EXTENSIONS_DIR)/esp32_toolchain.cmake $(EXTENSIONS_DIR)/micro_ros_dev/install $(EXTENSIONS_DIR)/micro_ros_src/src | $(PRE_CLEAN)
	cd $(UROS_DIR); \
	unset AMENT_PREFIX_PATH; \
	PATH="$(subst /opt/ros/$(ROS_DISTRO)/bin,,$(PATH))"; \
	. ../micro_ros_dev/install/local_setup.sh; \
	colcon build \
		--merge-install \
		--packages-ignore lttngpy \
		--packages-ignore-regex=.*_cpp \
		--metas $(EXTENSIONS_DIR)/colcon.meta $(APP_COLCON_META) \
		--cmake-args \
		"--no-warn-unused-cli" \
		-DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=OFF \
		-DTHIRDPARTY=ON \
		-DBUILD_SHARED_LIBS=OFF \
		-DBUILD_TESTING=OFF \
		-DCMAKE_BUILD_TYPE=$(BUILD_TYPE) \
		-DCMAKE_TOOLCHAIN_FILE=$(EXTENSIONS_DIR)/esp32_toolchain.cmake \
		-DCMAKE_VERBOSE_MAKEFILE=OFF \
		-DIDF_INCLUDES='${IDF_INCLUDES} ${IDF_SDKCONFIG_INCLUDES}' \
		-DCMAKE_C_STANDARD=$(C_STANDARD) \
		-DUCLIENT_C_STANDARD=$(C_STANDARD);
	test -d "$(UROS_DIR)/install/lib" || (echo "micro-ROS install/lib 不存在，colcon 可能失败"; exit 1)
	touch $(INSTALL_STAMP)

$(EXTENSIONS_DIR)/.microros_preclean:
	rm -rf $(UROS_DIR)/build $(UROS_DIR)/install $(UROS_DIR)/log $(INSTALL_STAMP)
	touch $(EXTENSIONS_DIR)/.microros_preclean

patch_atomic:$(INSTALL_STAMP)
# Workaround https://github.com/micro-ROS/micro_ros_espidf_component/issues/18
ifeq ($(IDF_TARGET),$(filter $(IDF_TARGET),esp32s2 esp32c3 esp32c6))
		echo $(UROS_DIR)/atomic_workaround; \
		mkdir $(UROS_DIR)/atomic_workaround; cd $(UROS_DIR)/atomic_workaround; \
		$(X_AR) x $(UROS_DIR)/install/lib/librcutils.a; \
		$(X_STRIP) atomic_64bits.c.obj --strip-symbol=__atomic_fetch_add_8; \
		if [ $(IDF_VERSION_MAJOR) -ge 4 ] && [ $(IDF_VERSION_MINOR) -ge 3 ]; then \
			$(X_STRIP) atomic_64bits.c.obj --strip-symbol=__atomic_load_8; \
			$(X_STRIP) atomic_64bits.c.obj --strip-symbol=__atomic_store_8; \
			$(X_STRIP) atomic_64bits.c.obj --strip-symbol=__atomic_exchange_8; \
		fi; \
		if [ $(IDF_VERSION_MAJOR) -ge 4 ] && [ $(IDF_VERSION_MINOR) -ge 4 ]; then \
			$(X_STRIP) atomic_64bits.c.obj --strip-symbol=__atomic_load_8; \
			$(X_STRIP) atomic_64bits.c.obj --strip-symbol=__atomic_store_8; \
		fi; \
		if [ $(IDF_VERSION_MAJOR) -ge 5 ] && [ $(IDF_VERSION_MINOR) -ge 0 ]; then \
			$(X_STRIP) atomic_64bits.c.obj --strip-symbol=__atomic_load_8; \
			$(X_STRIP) atomic_64bits.c.obj --strip-symbol=__atomic_store_8; \
			$(X_STRIP) atomic_64bits.c.obj --strip-symbol=__atomic_exchange_8; \
		fi; \
		$(X_AR) rc -s librcutils.a *.obj; \
		cp -rf librcutils.a  $(UROS_DIR)/install/lib/librcutils.a; \
		cd ..; \
		rm -rf $(UROS_DIR)/atomic_workaround;
endif
ifeq ($(IDF_TARGET),$(filter $(IDF_TARGET),esp32))
		echo $(UROS_DIR)/atomic_workaround; \
		mkdir $(UROS_DIR)/atomic_workaround; cd $(UROS_DIR)/atomic_workaround; \
		$(X_AR) x $(UROS_DIR)/install/lib/librcutils.a; \
		$(X_STRIP) atomic_64bits.c.obj --strip-symbol=__atomic_fetch_add_8; \
		if [ $(IDF_VERSION_MAJOR) -ge 5 ] && [ $(IDF_VERSION_MINOR) -ge 3 ]; then \
			$(X_STRIP) atomic_64bits.c.obj --strip-symbol=__atomic_load_8; \
			$(X_STRIP) atomic_64bits.c.obj --strip-symbol=__atomic_store_8; \
			$(X_STRIP) atomic_64bits.c.obj --strip-symbol=__atomic_exchange_8; \
		fi; \
		$(X_AR) rc -s librcutils.a *.obj; \
		cp -rf librcutils.a  $(UROS_DIR)/install/lib/librcutils.a; \
		cd ..; \
		rm -rf $(UROS_DIR)/atomic_workaround;
endif

$(EXTENSIONS_DIR)/libmicroros.a: $(INSTALL_STAMP) patch_atomic
	test -d "$(UROS_DIR)/install/lib" || (echo "micro-ROS install/lib 不存在，无法打包 libmicroros.a"; exit 1)
	mkdir -p $(UROS_DIR)/libmicroros; cd $(UROS_DIR)/libmicroros; \
	for file in $$(find $(UROS_DIR)/install/lib/ -name '*.a'); do \
		folder=$$(echo $$file | sed -E "s/(.+)\/(.+).a/\2/"); \
		mkdir -p $$folder; cd $$folder; $(X_AR) x $$file; \
		for f in *; do \
			mv $$f ../$$folder-$$f; \
		done; \
		cd ..; rm -rf $$folder; \
	done ; \
	$(X_AR) rc -s libmicroros.a *.obj; cp libmicroros.a $(EXTENSIONS_DIR); \
	cd ..; rm -rf libmicroros; \
	cp -R $(UROS_DIR)/install/include $(EXTENSIONS_DIR)/include;
