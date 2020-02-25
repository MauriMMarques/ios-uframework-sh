#!/bin/bash

####################### Setup variables #############################

# Search for path parameters
PROJECT_PATH=
while [ "$1" != "" ]; do
    case $1 in
        -p | --path )
        PROJECT_PATH=$2
        ;;
    esac
    shift
done

# If project path is null, exit script
if [ -z $PROJECT_PATH ]
then
  echo "No project path especified"
  exit
fi

XCODE_PROJECT_PATH=${PROJECT_PATH}

# Get project basename from path, Ex: MyFramework.xcodeproj
PROJECT_NAME=$(basename "$PROJECT_PATH")

# Get project path, extracting the basename
BASE_PROJECT_PATH=${PROJECT_PATH%"${PROJECT_NAME}"}

# Get framework name and extension (xcodeproj or xcworkspace)
IFS="."
read -ra ADDR <<< "$PROJECT_NAME"
IFS=' '
FRAMEWORK_NAME=${ADDR[0]}
PROJECT_EXTENSION=${ADDR[1]}

if [ -z $PROJECT_EXTENSION ]
then
  echo "Invalid project especified, it should be an .xcodeproj or .xcworkspace"
  exit
fi

PROJECT_PARAM_TYPE=
if [ $PROJECT_EXTENSION = "xcworkspace" ]
then
  PROJECT_PARAM_TYPE=-workspace
elif [ $PROJECT_EXTENSION = "xcodeproj" ]
then
  PROJECT_PARAM_TYPE=-project
else
  echo "Invalid project especified, it should be an .xcodeproj or .xcworkspace"
  exit
fi 

# Create main framework build folder
BUILD_DIR=${FRAMEWORK_NAME}_build
mkdir ${BUILD_DIR}

####################### Build framework for simulators #############################

xcodebuild clean build \
  ${PROJECT_PARAM_TYPE} ${XCODE_PROJECT_PATH} \
  -scheme ${FRAMEWORK_NAME} \
  -configuration Release \
  -sdk iphonesimulator \
  -derivedDataPath derived_data

# create folder to store compiled framework for simulator
mkdir ${BUILD_DIR}/simulator
# copy compiled framework for simulator into our build folder
cp -r derived_data/Build/Products/Release-iphonesimulator/${FRAMEWORK_NAME}.framework ${BUILD_DIR}/simulator

####################### Build framework for devices #############################

xcodebuild clean build \
  ${PROJECT_PARAM_TYPE}  ${XCODE_PROJECT_PATH} \
  -scheme ${FRAMEWORK_NAME} \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath derived_data

# create folder to store compiled framework for simulator
mkdir ${BUILD_DIR}/devices
# copy compiled framework for simulator into our build folder
cp -r derived_data/Build/Products/Release-iphoneos/${FRAMEWORK_NAME}.framework ${BUILD_DIR}/devices

# Copy each headers to temporary space
mkdir -p "${BUILD_DIR}/tmp/Headers/simulator"
mkdir -p "${BUILD_DIR}/tmp/Headers/device"
cp -R "${BUILD_DIR}/simulator/${FRAMEWORK_NAME}.framework/Headers/${FRAMEWORK_NAME}-Swift.h" "${BUILD_DIR}/tmp/Headers/simulator/${FRAMEWORK_NAME}-Swift.h"
cp -r "${BUILD_DIR}/devices/${FRAMEWORK_NAME}.framework/Headers/${FRAMEWORK_NAME}-Swift.h" "${BUILD_DIR}/tmp/Headers/device/${FRAMEWORK_NAME}-Swift.h"
# Merge
touch "${BUILD_DIR}/tmp/${FRAMEWORK_NAME}-Swift.h"
echo "#if TARGET_OS_SIMULATOR" >> "${BUILD_DIR}/tmp/${FRAMEWORK_NAME}-Swift.h"
cat "${BUILD_DIR}/tmp/Headers/simulator/${FRAMEWORK_NAME}-Swift.h" >> "${BUILD_DIR}/tmp/${FRAMEWORK_NAME}-Swift.h"
echo "#else" >> "${BUILD_DIR}/tmp/${FRAMEWORK_NAME}-Swift.h"
cat "${BUILD_DIR}/tmp/Headers/device/${FRAMEWORK_NAME}-Swift.h" >> "${BUILD_DIR}/tmp/${FRAMEWORK_NAME}-Swift.h"
echo "#endif" >> "${BUILD_DIR}/tmp/${FRAMEWORK_NAME}-Swift.h"

####################### Create universal framework #############################

# create folder to store compiled universal framework
mkdir ${BUILD_DIR}/universal

# copy device framework into universal folder
cp -r ${BUILD_DIR}/devices/${FRAMEWORK_NAME}.framework ${BUILD_DIR}/universal/
# create framework binary compatible with simulators and devices, and replace binary in unviersal framework
lipo -create \
  ${BUILD_DIR}/simulator/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME} \
  ${BUILD_DIR}/devices/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME} \
  -output ${BUILD_DIR}/universal/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}

# This is Apple lipo bug
cp -R "${BUILD_DIR}/tmp/${FRAMEWORK_NAME}-Swift.h" "${BUILD_DIR}/universal/${FRAMEWORK_NAME}.framework/Headers/${FRAMEWORK_NAME}-Swift.h"
# Delete temporary files
rm -rf "${BUILD_DIR}/tmp"

# copy simulator Swift public interface to universal framework
cp ${BUILD_DIR}/simulator/${FRAMEWORK_NAME}.framework/Modules/${FRAMEWORK_NAME}.swiftmodule/* ${BUILD_DIR}/universal/${FRAMEWORK_NAME}.framework/Modules/${FRAMEWORK_NAME}.swiftmodule

cp -r ${BUILD_DIR}/universal/${FRAMEWORK_NAME}.framework ${BASE_PROJECT_PATH}/

echo "${FRAMEWORK_NAME}.framework placed in ${BASE_PROJECT_PATH}/"

# Delete build and derived_data folders 
rm -r ${BUILD_DIR}
rm -r derived_data