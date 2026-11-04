#!/bin/zsh
# sync_xcodeproj.sh — Regenerate FinderPlus.xcodeproj/project.pbxproj
# from the Swift files in Sources/FinderPlus/.
#
# Run after adding or removing .swift files so the Xcode project stays in sync.
# Safe to run repeatedly; it fully regenerates the pbxproj each time.

set -euo pipefail
cd "$(dirname "$0")"

SOURCES_DIR="Sources/FinderPlus"
PBXPROJ="FinderPlus.xcodeproj/project.pbxproj"

# Collect all .swift files, sorted alphabetically
SWIFT_FILES=()
for f in "$SOURCES_DIR"/*.swift(N); do
    SWIFT_FILES+=("${f:t}")
done

# Sort
SWIFT_FILES=(${(o)SWIFT_FILES})

if [[ ${#SWIFT_FILES[@]} -eq 0 ]]; then
    echo "ERROR: No .swift files found in $SOURCES_DIR"
    exit 1
fi

echo "Found ${#SWIFT_FILES[@]} Swift files:"
printf "  %s\n" "${SWIFT_FILES[@]}"

# Generate deterministic IDs from filename using md5
generate_id() {
    local prefix="$1"
    local name="$2"
    local hash
    hash=$(echo -n "$name" | md5 -q)
    echo "${prefix}${hash:0:22}"
}

# --- Build sections ---
BUILD_FILE_SECTION=""
FILE_REF_SECTION=""
GROUP_CHILDREN=""
SOURCE_BUILD_FILES=""

for f in "${SWIFT_FILES[@]}"; do
    FILE_REF_ID=$(generate_id "F1" "$f")
    BUILD_FILE_ID=$(generate_id "F2" "$f")

    FILE_REF_SECTION+="\t\t${FILE_REF_ID} /* ${f} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${f}; sourceTree = \"<group>\"; };\n"
    BUILD_FILE_SECTION+="\t\t${BUILD_FILE_ID} /* ${f} in Sources */ = {isa = PBXBuildFile; fileRef = ${FILE_REF_ID} /* ${f} */; };\n"
    GROUP_CHILDREN+="\t\t\t\t${FILE_REF_ID} /* ${f} */,\n"
    SOURCE_BUILD_FILES+="\t\t\t\t${BUILD_FILE_ID} /* ${f} in Sources */,\n"
done

INFO_PLIST_REF="A800000000000000000001"

cat > "$PBXPROJ" << PBXEOF
// !\$*UTF8*\$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
$(echo -e "$BUILD_FILE_SECTION")/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		A300000000000000000001 /* FinderPlus.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = FinderPlus.app; sourceTree = BUILT_PRODUCTS_DIR; };
		${INFO_PLIST_REF} /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
$(echo -e "$FILE_REF_SECTION")/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		A500000000000000000002 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		A400000000000000000001 = {
			isa = PBXGroup;
			children = (
				A400000000000000000002 /* FinderPlus */,
				A400000000000000000003 /* Products */,
			);
			sourceTree = "<group>";
		};
		A400000000000000000002 /* FinderPlus */ = {
			isa = PBXGroup;
			children = (
$(echo -e "$GROUP_CHILDREN")				${INFO_PLIST_REF} /* Info.plist */,
			);
			path = Sources/FinderPlus;
			sourceTree = "<group>";
		};
		A400000000000000000003 /* Products */ = {
			isa = PBXGroup;
			children = (
				A300000000000000000001 /* FinderPlus.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		A200000000000000000001 /* FinderPlus */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = A700000000000000000001 /* Build configuration list for PBXNativeTarget "FinderPlus" */;
			buildPhases = (
				A500000000000000000001 /* Sources */,
				A500000000000000000002 /* Frameworks */,
				A500000000000000000003 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = FinderPlus;
			productName = FinderPlus;
			productReference = A300000000000000000001 /* FinderPlus.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		A100000000000000000001 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastUpgradeCheck = 1500;
				TargetAttributes = {
					A200000000000000000001 = {
						CreatedOnToolsVersion = 15.0;
					};
				};
			};
			buildConfigurationList = A600000000000000000001 /* Build configuration list for PBXProject "FinderPlus" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = A400000000000000000001;
			productRefGroup = A400000000000000000003 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				A200000000000000000001 /* FinderPlus */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		A500000000000000000003 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		A500000000000000000001 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
$(echo -e "$SOURCE_BUILD_FILES")			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		A600000000000000000002 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"\$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG \$(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		A600000000000000000003 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MTL_FAST_MATH = YES;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = "wholemodule";
				SWIFT_OPTIMIZATION_LEVEL = "-O";
			};
			name = Release;
		};
		A700000000000000000002 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = "";
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Sources/FinderPlus/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"\$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.shawnlee.FinderPlus;
				PRODUCT_NAME = "\$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		A700000000000000000003 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = "";
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Sources/FinderPlus/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"\$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.shawnlee.FinderPlus;
				PRODUCT_NAME = "\$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		A600000000000000000001 /* Build configuration list for PBXProject "FinderPlus" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				A600000000000000000002 /* Debug */,
				A600000000000000000003 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		A700000000000000000001 /* Build configuration list for PBXNativeTarget "FinderPlus" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				A700000000000000000002 /* Debug */,
				A700000000000000000003 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = A100000000000000000001 /* Project object */;
}
PBXEOF

echo ""
echo "✅ Updated $PBXPROJ with ${#SWIFT_FILES[@]} Swift files."
