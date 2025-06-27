cmake_minimum_required(VERSION 3.24)

project(${APP_NAME})

set(APP HelloWorldWxWidgets)

file( GLOB SOURCE RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    sources/Application.*
)

add_executable(${APP} WIN32 ${SOURCE})

target_link_options(${APP} PRIVATE "/MAP:${CMAKE_BINARY_DIR}/HelloWorld.map" "/MAPINFO:ALL")

set(wxBUILD_SHARED OFF)
set(wxUSE_LIBTIFF OFF)
set(wxUSE_UNICODE ON)
set(wxUSE_XRC ON)
set(wxUSE_GUI ON)
add_subdirectory(libs/wxWidgets)

target_link_libraries(${APP} PRIVATE wx::base wx::core wx::adv wx::xrc wx::xml wx::html wx::aui wx::gl)