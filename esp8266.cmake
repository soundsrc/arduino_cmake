set(ARDUINO_PACKAGES_PATH "" CACHE STRING "Path to arduino esp8266 packages")

set(ESP8266_TOOLCHAIN_VERSION 2.5.0-4-b40a506 CACHE STRING "ESP8266 toolchain version")
set(ESP8266_CORE_VERSION 2.7.4 CACHE STRING "ESP8266 Arduino core version")

set(ESP_TOOLCHAIN_PATH ${ARDUINO_PACKAGES_PATH}/esp8266/tools/xtensa-lx106-elf-gcc/${ESP8266_TOOLCHAIN_VERSION}/bin)
set(ESP_ARDUINO_CORE_PATH ${ARDUINO_PACKAGES_PATH}/esp8266/hardware/esp8266/${ESP8266_CORE_VERSION})
set(ESP_PORT /dev/ttyUSB0)
set(ESP_BAUD 115200)

set(PYTHON3 /usr/bin/python3)

set(CMAKE_SYSTEM_NAME esp8266)
set(CMAKE_C_COMPILER ${ESP_TOOLCHAIN_PATH}/xtensa-lx106-elf-gcc)
set(CMAKE_CXX_COMPILER ${ESP_TOOLCHAIN_PATH}/xtensa-lx106-elf-g++)
set(CMAKE_ASM_COMPILER ${ESP_TOOLCHAIN_PATH}/xtensa-lx106-elf-gcc)
set(CMAKE_AR ${ESP_TOOLCHAIN_PATH}/xtensa-lx106-elf-ar)
set(CMAKE_OBJCOPY ${ESP_TOOLCHAIN_PATH}/xtensa-lx106-elf-objcopy)
set(CMAKE_OBJDUMP ${ESP_TOOLCHAIN_PATH}/xtensa-lx106-elf-objdump)
set(CMAKE_SIZE ${ESP_TOOLCHAIN_PATH}/xtensa-lx106-elf-size)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_C_STANDARD 11)

set(CMAKE_C_COMPILER_WORKS 1)
set(CMAKE_CXX_COMPILER_WORKS 1)
set(CMAKE_ASM_COMPILER_WORKS 1)

set(CMAKE_CXX_LINK_EXECUTABLE
    "<CMAKE_C_COMPILER> <CMAKE_CXX_LINK_FLAGS> <LINK_FLAGS> -o <TARGET> -Wl,--start-group <OBJECTS> <LINK_LIBRARIES> -Wl,--end-group")

set(CMAKE_C_LINK_EXECUTABLE
    "<CMAKE_C_COMPILER> <CMAKE_C_LINK_FLAGS> <LINK_FLAGS> -o <TARGET> -Wl,--start-group <OBJECTS> <LINK_LIBRARIES> -Wl,--end-group")

macro(target_link_arduino)
    set(ARGS ${ARGN})
    list(GET ARGS 0 TARGET_NAME)
    get_filename_component(TARGET_NAME_NO_EXT ${TARGET_NAME} NAME_WLE)

    file(GLOB_RECURSE arduino_core_SRCS
        "${ESP_ARDUINO_CORE_PATH}/cores/esp8266/*.S"
        "${ESP_ARDUINO_CORE_PATH}/cores/esp8266/*.c"
        "${ESP_ARDUINO_CORE_PATH}/cores/esp8266/*.cpp")

    set(arduino_core_DEFINES
        __ets__
        ICACHE_FLASH
        NONOSDK22x_190703=1
        F_CPU=80000000L
        LWIP_OPEN_SRC
        TCP_MSS=536
        LWIP_FEATURES=1
        LWIP_IPV6=0
        ARDUINO=10813
        ARDUINO_ESP8266_GENERIC
        ARDUINO_ARCH_ESP8266
        ARDUINO_BOARD="ESP8266_GENERIC"
        LED_BUILTIN=2
        FLASHMODE_DOUT
        ESP8266
        )

    set (arduino_core_INCLUDES
        ${ESP_ARDUINO_CORE_PATH}/cores/esp8266
        ${ESP_ARDUINO_CORE_PATH}/
        ${ESP_ARDUINO_CORE_PATH}/tools/sdk/include
        ${ESP_ARDUINO_CORE_PATH}/tools/sdk/libc/xtensa-lx106-elf/include
        ${ESP_ARDUINO_CORE_PATH}/tools/sdk/lwip2/include
        ${ESP_ARDUINO_CORE_PATH}/variants/generic
        )

    set (arduino_core_CFLAGS
        -U__STRICT_ANSI__
        -mlongcalls
        -mtext-section-literals
        -falign-functions=4
        -MMD
        -ffunction-sections
        -fdata-sections
        )

    set (arduino_core_CXXFLAGS
        -fno-rtti
        -fno-exceptions
        )

    set (arduino_core_LDFLAGS
        -nostdlib
        -Wl,--no-check-sections
        #-u app_entry
        #-u _printf_float
        #-u _scanf_float
        -Wl,-static
        -Teagle.flash.1m64.ld
        -Wl,--gc-sections
        -Wl,-wrap,system_restart_local
        -Wl,-wrap,spi_flash_read
        )

    set(arduino_core_LIBS
        -L${ESP_ARDUINO_CORE_PATH}/tools/sdk/lib
        -L${ESP_ARDUINO_CORE_PATH}/tools/sdk/lib/NONOSDK22x_190703
        -L${ESP_ARDUINO_CORE_PATH}/tools/sdk/ld
        -L${ESP_ARDUINO_CORE_PATH}/tools/sdk/libc/xtensa-lx106-elf/lib
        hal
        phy
        pp
        net80211
        lwip2-536-feat
        wpa
        crypto
        main
        wps
        bearssl
        axtls
        espnow
        smartconfig
        airkiss
        wpa2
        stdc++
        m
        c
        gcc
        )

    # Also include all the libraries that come with core
    file(GLOB ARDUINO_LIBRARIES ${ESP_ARDUINO_CORE_PATH}/libraries/*)
    foreach(LIBRARY_PATH ${ARDUINO_LIBRARIES})
        file(GLOB_RECURSE library_SRCS
            ${LIBRARY_PATH}/*.cpp
            ${LIBRARY_PATH}/*.c
            ${LIBRARY_PATH}/*.S)
        file(GLOB_RECURSE library_HEADERS
            ${LIBRARY_PATH}/*.h
            )
        foreach(H in ${library_HEADERS})
            get_filename_component(INCLUDE_PATH_FOR_LIBRARY ${H} DIRECTORY)
            list(APPEND library_INCLUDES ${INCLUDE_PATH_FOR_LIBRARY})
        endforeach()

        # exclude examples and extra folders
        list(FILTER library_SRCS EXCLUDE REGEX ".*/(examples|extras)/.*")
        list(FILTER library_HEADERS EXCLUDE REGEX ".*/(examples|extras)/.*")

        list(APPEND arduino_core_INCLUDES ${library_INCLUDES})
        list(APPEND arduino_core_SRCS ${library_SRCS} ${library_HEADERS})
    endforeach()

    list(REMOVE_DUPLICATES arduino_core_INCLUDES)

    add_library(arduino_core STATIC ${arduino_core_SRCS})
    target_include_directories(arduino_core PUBLIC ${arduino_core_INCLUDES})
    target_compile_definitions(arduino_core PUBLIC ${arduino_core_DEFINES})
    target_compile_options(arduino_core PUBLIC ${arduino_core_CFLAGS})
    target_compile_options(arduino_core PUBLIC $<$<COMPILE_LANGUAGE:CXX>:${arduino_core_CXXFLAGS}>)
    target_link_options(arduino_core PUBLIC ${arduino_core_LDFLAGS})
    target_link_libraries(arduino_core PUBLIC ${arduino_core_LIBS})

    target_link_libraries(${TARGET_NAME} arduino_core)

    # add command to generate local.eagle.app.v6.common.ld
    add_custom_command(TARGET ${TARGET_NAME} PRE_LINK COMMAND ${CMAKE_C_COMPILER} -CC -E -P -DVTABLES_IN_FLASH "${ESP_ARDUINO_CORE_PATH}/tools/sdk/ld/eagle.app.v6.common.ld.h" -o "${CMAKE_BINARY_DIR}/local.eagle.app.v6.common.ld")

    add_custom_target(${TARGET_NAME_NO_EXT}.bin
        COMMAND ${PYTHON3} ${ESP_ARDUINO_CORE_PATH}/tools/sizes.py --elf $<TARGET_FILE:${TARGET_NAME}> --path ${ESP_TOOLCHAIN_PATH}
        COMMAND ${PYTHON3} ${ESP_ARDUINO_CORE_PATH}/tools/elf2bin.py --eboot ${ESP_ARDUINO_CORE_PATH}/bootloaders/eboot/eboot.elf --app $<TARGET_FILE:${TARGET_NAME}> --flash_mode dout --flash_freq 40 --flash_size 1M --path ${ESP_TOOLCHAIN_PATH} --out $<TARGET_FILE_DIR:${TARGET_NAME}>/${TARGET_NAME_NO_EXT}.bin
        DEPENDS ${TARGET_NAME})

    # install
    add_custom_target(flash_${TARGET_NAME_NO_EXT}
        COMMAND ${PYTHON3} ${ESP_ARDUINO_CORE_PATH}/tools/upload.py --chip auto --port ${ESP_PORT} --baud ${ESP_BAUD} --before default_reset --after hard_reset write_flash 0x0 $<TARGET_FILE_DIR:${TARGET_NAME}>/${TARGET_NAME_NO_EXT}.bin
        DEPENDS ${TARGET_NAME_NO_EXT}.bin
        )
endmacro()
