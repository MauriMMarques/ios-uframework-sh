FRAMEWORK_NAME="MyFramework"

####################### Build framework for simulators #############################
TMP_BUILD_DIR=${FRAMEWORK_NAME}_build
mkdir ${TMP_BUILD_DIR}

xcodebuild clean build -project ${FRAMEWORK_NAME}.xcodeproj -scheme ${FRAMEWORK_NAME} -configuration ${CONFIGURATION} -sdk iphonesimulator -derivedDataPath derived_data

# create folder to store compiled framework for simulator
mkdir ${TMP_BUILD_DIR}/simulator
# copy compiled framework for simulator into our build folder
cp -r derived_data/Build/Products/${CONFIGURATION}-iphonesimulator/${FRAMEWORK_NAME}.framework ${TMP_BUILD_DIR}/simulator

####################### Build framework for devices #############################

xcodebuild clean build -project ${FRAMEWORK_NAME}.xcodeproj -scheme ${FRAMEWORK_NAME} -configuration ${CONFIGURATION} -sdk iphoneos -derivedDataPath derived_data

# create folder to store compiled framework for simulator
mkdir ${TMP_BUILD_DIR}/devices
# copy compiled framework for simulator into our build folder
cp -r derived_data/Build/Products/${CONFIGURATION}-iphoneos/${FRAMEWORK_NAME}.framework ${TMP_BUILD_DIR}/devices

# Copy each headers to temporary space
mkdir -p "${TMP_BUILD_DIR}/tmp/Headers/simulator"
mkdir -p "${TMP_BUILD_DIR}/tmp/Headers/device"
cp -R "${TMP_BUILD_DIR}/simulator/${FRAMEWORK_NAME}.framework/Headers/${FRAMEWORK_NAME}-Swift.h" "${TMP_BUILD_DIR}/tmp/Headers/simulator/${FRAMEWORK_NAME}-Swift.h"
cp -r "${TMP_BUILD_DIR}/devices/${FRAMEWORK_NAME}.framework/Headers/${FRAMEWORK_NAME}-Swift.h" "${TMP_BUILD_DIR}/tmp/Headers/device/${FRAMEWORK_NAME}-Swift.h"
# Merge
touch "${TMP_BUILD_DIR}/tmp/${FRAMEWORK_NAME}-Swift.h"
echo "#if TARGET_OS_SIMULATOR" >> "${TMP_BUILD_DIR}/tmp/${FRAMEWORK_NAME}-Swift.h"
cat "${TMP_BUILD_DIR}/tmp/Headers/simulator/${FRAMEWORK_NAME}-Swift.h" >> "${TMP_BUILD_DIR}/tmp/${FRAMEWORK_NAME}-Swift.h"
echo "#else" >> "${TMP_BUILD_DIR}/tmp/${FRAMEWORK_NAME}-Swift.h"
cat "${TMP_BUILD_DIR}/tmp/Headers/device/${FRAMEWORK_NAME}-Swift.h" >> "${TMP_BUILD_DIR}/tmp/${FRAMEWORK_NAME}-Swift.h"
echo "#endif" >> "${TMP_BUILD_DIR}/tmp/${FRAMEWORK_NAME}-Swift.h"

####################### Create universal framework #############################

# create folder to store compiled universal framework
mkdir ${TMP_BUILD_DIR}/universal

# copy device framework into universal folder
cp -r ${TMP_BUILD_DIR}/devices/${FRAMEWORK_NAME}.framework ${TMP_BUILD_DIR}/universal/
# create framework binary compatible with simulators and devices, and replace binary in unviersal framework
lipo -create \
  ${TMP_BUILD_DIR}/simulator/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME} \
  ${TMP_BUILD_DIR}/devices/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME} \
  -output ${TMP_BUILD_DIR}/universal/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}

# This is Apple lipo bug
cp -R "${TMP_BUILD_DIR}/tmp/${FRAMEWORK_NAME}-Swift.h" "${TMP_BUILD_DIR}/universal/${FRAMEWORK_NAME}.framework/Headers/${FRAMEWORK_NAME}-Swift.h"

# copy simulator Swift public interface to universal framework
cp ${TMP_BUILD_DIR}/simulator/${FRAMEWORK_NAME}.framework/Modules/${FRAMEWORK_NAME}.swiftmodule/* ${TMP_BUILD_DIR}/universal/${FRAMEWORK_NAME}.framework/Modules/${FRAMEWORK_NAME}.swiftmodule

cp -r ${TMP_BUILD_DIR}/universal/${FRAMEWORK_NAME}.framework ./

# Delete build folders 
rm -r ${TMP_BUILD_DIR}
rm -r derived_data