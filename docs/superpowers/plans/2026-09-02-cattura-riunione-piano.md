# Piano di implementazione — Cattura Riunione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App macOS nativa che registra riunioni (microfono + audio di sistema) e produce il verbale con trascrizione e divisione dei parlanti, tutta in locale.

**Architecture:** SwiftUI + AVFoundation/Core Audio per la registrazione (sorgenti riusati da `~/workspace/cattura brano`); FluidAudio (Core ML) per diarizzazione e trascrizione in post-elaborazione. La pipeline: diarizzazione sull'audio completo → ritaglio dell'audio per ciascun turno di parola → trascrizione ASR di ogni ritaglio → verbale `[Intervento]`. Ogni riunione è una cartella con `riunione.m4a`, `trascrizione.json`, `verbale.md`.

**Tech Stack:** Swift 5 (modulo con isolamento MainActor di default), SwiftUI, AVFoundation, Core Audio (process tap), XCTest, Swift Package **FluidAudio** (`https://github.com/FluidInference/FluidAudio`).

**Spec:** `docs/superpowers/specs/2026-09-02-cattura-riunione-design.md`

## Global Constraints

- macOS **15.0**+, solo **arm64** (Apple Silicon).
- Bundle id `it.emiliolodigiani.cattura-riunione`; prodotto «Cattura Riunione»; modulo Swift `Cattura_Riunione`.
- Hardened runtime SÌ, App Sandbox NO, entitlement `com.apple.security.device.audio-input`.
- Tutto in italiano: commenti, stringhe UI, messaggi di commit (riga breve descrittiva, stile cattura brano).
- Tipi di logica pura marcati `nonisolated` (il modulo ha `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
- Non modificare MAI nulla in `~/workspace/cattura brano`.
- Directory di lavoro: `/Users/emi/workspace/cattura riunione`.
- Dopo ogni task verificato: commit immediato, senza chiedere conferma.
- Comandi di verifica standard:
  - build: `xcodebuild -project "cattura riunione.xcodeproj" -scheme "Cattura Riunione" -configuration Debug -derivedDataPath build build`
  - test: `xcodebuild -project "cattura riunione.xcodeproj" -scheme "Cattura Riunione" -destination 'platform=macOS' -derivedDataPath build test`

---

### Task 1: Progetto Xcode, target di test e dipendenza FluidAudio

**Files:**
- Create: `.gitignore`
- Create: `cattura riunione.xcodeproj/project.pbxproj`
- Create: `cattura riunione.xcodeproj/xcshareddata/xcschemes/Cattura Riunione.xcscheme`
- Create: `cattura riunione/cattura riunione.entitlements`
- Create: `cattura riunione/Info.plist`
- Create: `cattura riunione/cattura_riunioneApp.swift`
- Create: `cattura riunione/ContentView.swift`
- Create: `cattura riunioneTests/SanityTests.swift`
- Copia: `cp -R "/Users/emi/workspace/cattura brano/cattura brano/Assets.xcassets" "cattura riunione/Assets.xcassets"` (icona riusata provvisoriamente)

**Interfaces:**
- Produces: progetto compilabile e testabile da Xcode e da `xcodebuild`; pacchetto FluidAudio risolto; struttura a cartelle sincronizzate (i file aggiunti nelle cartelle `cattura riunione/` e `cattura riunioneTests/` entrano nel target automaticamente, senza toccare il pbxproj).

- [ ] **Step 1: `.gitignore`**

```gitignore
build/
xcuserdata/
.DS_Store
```

- [ ] **Step 2: `project.pbxproj`** — scrivi ESATTAMENTE questo contenuto (derivato da cattura brano: formato objectVersion 77, cartelle sincronizzate; in più target di test e pacchetto FluidAudio; rimossi LAME/aubio/ThirdParty):

```text
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 77;
	objects = {

/* Begin PBXFileReference section */
		CA11000000000000000000A3 /* Cattura Riunione.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "Cattura Riunione.app"; sourceTree = BUILT_PRODUCTS_DIR; };
		CA11000000000000000000B3 /* Cattura RiunioneTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = "Cattura RiunioneTests.xctest"; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		CA11000000000000000000A1 /* cattura riunione */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = "cattura riunione";
			sourceTree = "<group>";
		};
		CA11000000000000000000B1 /* cattura riunioneTests */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = "cattura riunioneTests";
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		CA11000000000000000000A6 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		CA11000000000000000000B6 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		CA11000000000000000000A0 = {
			isa = PBXGroup;
			children = (
				CA11000000000000000000A1 /* cattura riunione */,
				CA11000000000000000000B1 /* cattura riunioneTests */,
				CA11000000000000000000A2 /* Products */,
			);
			sourceTree = "<group>";
		};
		CA11000000000000000000A2 /* Products */ = {
			isa = PBXGroup;
			children = (
				CA11000000000000000000A3 /* Cattura Riunione.app */,
				CA11000000000000000000B3 /* Cattura RiunioneTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		CA11000000000000000000A4 /* Cattura Riunione */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = CA11000000000000000000AD /* Build configuration list for PBXNativeTarget "Cattura Riunione" */;
			buildPhases = (
				CA11000000000000000000A5 /* Sources */,
				CA11000000000000000000A6 /* Frameworks */,
				CA11000000000000000000A7 /* Resources */,
				CA11000000000000000000A8 /* Numero di build automatico */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				CA11000000000000000000A1 /* cattura riunione */,
			);
			name = "Cattura Riunione";
			packageProductDependencies = (
				CA11000000000000000000D2 /* FluidAudio */,
			);
			productName = "Cattura Riunione";
			productReference = CA11000000000000000000A3 /* Cattura Riunione.app */;
			productType = "com.apple.product-type.application";
		};
		CA11000000000000000000B4 /* Cattura RiunioneTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = CA11000000000000000000BD /* Build configuration list for PBXNativeTarget "Cattura RiunioneTests" */;
			buildPhases = (
				CA11000000000000000000B5 /* Sources */,
				CA11000000000000000000B6 /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
				CA11000000000000000000C1 /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				CA11000000000000000000B1 /* cattura riunioneTests */,
			);
			name = "Cattura RiunioneTests";
			packageProductDependencies = (
			);
			productName = "Cattura RiunioneTests";
			productReference = CA11000000000000000000B3 /* Cattura RiunioneTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		CA11000000000000000000A9 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2660;
				LastUpgradeCheck = 2660;
				TargetAttributes = {
					CA11000000000000000000A4 = {
						CreatedOnToolsVersion = 26.6;
					};
					CA11000000000000000000B4 = {
						CreatedOnToolsVersion = 26.6;
						TestTargetID = CA11000000000000000000A4;
					};
				};
			};
			buildConfigurationList = CA11000000000000000000AA /* Build configuration list for PBXProject "cattura riunione" */;
			developmentRegion = it;
			hasScannedForEncodings = 0;
			knownRegions = (
				it,
				Base,
			);
			mainGroup = CA11000000000000000000A0;
			minimizedProjectReferenceProxies = 1;
			packageReferences = (
				CA11000000000000000000D1 /* XCRemoteSwiftPackageReference "FluidAudio" */,
			);
			preferredProjectObjectVersion = 77;
			productRefGroup = CA11000000000000000000A2 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				CA11000000000000000000A4 /* Cattura Riunione */,
				CA11000000000000000000B4 /* Cattura RiunioneTests */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		CA11000000000000000000A7 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXShellScriptBuildPhase section */
		CA11000000000000000000A8 /* Numero di build automatico */ = {
			isa = PBXShellScriptBuildPhase;
			alwaysOutOfDate = 1;
			buildActionMask = 2147483647;
			files = (
			);
			inputPaths = (
			);
			name = "Numero di build automatico";
			outputPaths = (
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "# Progressivo = numero di commit git: cresce a ogni modifica.\n# Versione mostrata = MARKETING_VERSION.progressivo (es. 1.0.25);\n# lo stesso progressivo fa anche da numero di build.\nBUILD_NUMBER=$(cd \"${SRCROOT}\" && git rev-list --count HEAD 2>/dev/null || echo 1)\nPLIST=\"${TARGET_BUILD_DIR}/${INFOPLIST_PATH}\"\nif [ -f \"$PLIST\" ]; then\n  /usr/libexec/PlistBuddy -c \"Set :CFBundleVersion ${BUILD_NUMBER}\" \"$PLIST\"\n  /usr/libexec/PlistBuddy -c \"Set :CFBundleShortVersionString ${MARKETING_VERSION}.${BUILD_NUMBER}\" \"$PLIST\"\nfi\n";
		};
/* End PBXShellScriptBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		CA11000000000000000000A5 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		CA11000000000000000000B5 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		CA11000000000000000000C1 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = CA11000000000000000000A4 /* Cattura Riunione */;
			targetProxy = CA11000000000000000000C2 /* PBXContainerItemProxy */;
		};
/* End PBXTargetDependency section */

/* Begin PBXContainerItemProxy section */
		CA11000000000000000000C2 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = CA11000000000000000000A9 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = CA11000000000000000000A4;
			remoteInfo = "Cattura Riunione";
		};
/* End PBXContainerItemProxy section */

/* Begin XCBuildConfiguration section */
		CA11000000000000000000AB /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MACOSX_DEPLOYMENT_TARGET = 15.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		CA11000000000000000000AC /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MACOSX_DEPLOYMENT_TARGET = 15.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
			};
			name = Release;
		};
		CA11000000000000000000AE /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ARCHS = arm64;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = "cattura riunione/cattura riunione.entitlements";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 99V4TJ55YX;
				ENABLE_APP_SANDBOX = NO;
				ENABLE_HARDENED_RUNTIME = YES;
				ENABLE_PREVIEWS = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = NO;
				ENABLE_USER_SELECTED_FILES = readwrite;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = "cattura riunione/Info.plist";
				INFOPLIST_KEY_CFBundleDisplayName = "Cattura Riunione";
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
				INFOPLIST_KEY_NSHumanReadableCopyright = "© 2026 Emilio Lodigiani";
				INFOPLIST_KEY_NSMicrophoneUsageDescription = "L'app registra l'audio dal microfono selezionato per trascrivere le riunioni.";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				OTHER_LDFLAGS = (
					"-framework",
					Accelerate,
				);
				PRODUCT_BUNDLE_IDENTIFIER = "it.emiliolodigiani.cattura-riunione";
				PRODUCT_NAME = "Cattura Riunione";
				REGISTER_APP_GROUPS = YES;
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_OBJC_BRIDGING_HEADER = "cattura riunione/cattura riunione-Bridging-Header.h";
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		CA11000000000000000000AF /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ARCHS = arm64;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = "cattura riunione/cattura riunione.entitlements";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 99V4TJ55YX;
				ENABLE_APP_SANDBOX = NO;
				ENABLE_HARDENED_RUNTIME = YES;
				ENABLE_PREVIEWS = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = NO;
				ENABLE_USER_SELECTED_FILES = readwrite;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = "cattura riunione/Info.plist";
				INFOPLIST_KEY_CFBundleDisplayName = "Cattura Riunione";
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
				INFOPLIST_KEY_NSHumanReadableCopyright = "© 2026 Emilio Lodigiani";
				INFOPLIST_KEY_NSMicrophoneUsageDescription = "L'app registra l'audio dal microfono selezionato per trascrivere le riunioni.";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				OTHER_LDFLAGS = (
					"-framework",
					Accelerate,
				);
				PRODUCT_BUNDLE_IDENTIFIER = "it.emiliolodigiani.cattura-riunione";
				PRODUCT_NAME = "Cattura Riunione";
				REGISTER_APP_GROUPS = YES;
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_OBJC_BRIDGING_HEADER = "cattura riunione/cattura riunione-Bridging-Header.h";
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Release;
		};
		CA11000000000000000000BE /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ARCHS = arm64;
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 99V4TJ55YX;
				GENERATE_INFOPLIST_FILE = YES;
				MACOSX_DEPLOYMENT_TARGET = 15.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "it.emiliolodigiani.cattura-riunione-tests";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Cattura Riunione.app/Contents/MacOS/Cattura Riunione";
			};
			name = Debug;
		};
		CA11000000000000000000BF /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ARCHS = arm64;
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 99V4TJ55YX;
				GENERATE_INFOPLIST_FILE = YES;
				MACOSX_DEPLOYMENT_TARGET = 15.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "it.emiliolodigiani.cattura-riunione-tests";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Cattura Riunione.app/Contents/MacOS/Cattura Riunione";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		CA11000000000000000000AA /* Build configuration list for PBXProject "cattura riunione" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				CA11000000000000000000AB /* Debug */,
				CA11000000000000000000AC /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		CA11000000000000000000AD /* Build configuration list for PBXNativeTarget "Cattura Riunione" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				CA11000000000000000000AE /* Debug */,
				CA11000000000000000000AF /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		CA11000000000000000000BD /* Build configuration list for PBXNativeTarget "Cattura RiunioneTests" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				CA11000000000000000000BE /* Debug */,
				CA11000000000000000000BF /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

/* Begin XCRemoteSwiftPackageReference section */
		CA11000000000000000000D1 /* XCRemoteSwiftPackageReference "FluidAudio" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/FluidInference/FluidAudio";
			requirement = {
				kind = upToNextMajorVersion;
				minimumVersion = 0.5.0;
			};
		};
/* End XCRemoteSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		CA11000000000000000000D2 /* FluidAudio */ = {
			isa = XCSwiftPackageProductDependency;
			package = CA11000000000000000000D1 /* XCRemoteSwiftPackageReference "FluidAudio" */;
			productName = FluidAudio;
		};
/* End XCSwiftPackageProductDependency section */
	};
	rootObject = CA11000000000000000000A9 /* Project object */;
}
```

Nota: se la risoluzione del pacchetto fallisse perché FluidAudio ha superato la versione 1.0, controlla l'ultima release su https://github.com/FluidInference/FluidAudio/releases e alza `minimumVersion` di conseguenza.

- [ ] **Step 3: schema condiviso** — `cattura riunione.xcodeproj/xcshareddata/xcschemes/Cattura Riunione.xcscheme`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2660" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "CA11000000000000000000A4"
               BuildableName = "Cattura Riunione.app"
               BlueprintName = "Cattura Riunione"
               ReferencedContainer = "container:cattura riunione.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES" shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "CA11000000000000000000B4"
               BuildableName = "Cattura RiunioneTests.xctest"
               BlueprintName = "Cattura RiunioneTests"
               ReferencedContainer = "container:cattura riunione.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "CA11000000000000000000A4"
            BuildableName = "Cattura Riunione.app"
            BlueprintName = "Cattura Riunione"
            ReferencedContainer = "container:cattura riunione.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES"/>
   <AnalyzeAction buildConfiguration = "Debug"/>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"/>
</Scheme>
```

- [ ] **Step 4: entitlements** — `cattura riunione/cattura riunione.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.device.audio-input</key>
	<true/>
</dict>
</plist>
```

- [ ] **Step 5: Info.plist parziale** (si fonde con quello generato; serve per la chiave che i build setting non coprono) — `cattura riunione/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSAudioCaptureUsageDescription</key>
	<string>L'app registra l'audio di sistema per catturare le voci degli altri partecipanti alle call.</string>
</dict>
</plist>
```

- [ ] **Step 6: sorgenti minimi.** `cattura riunione/cattura_riunioneApp.swift`:

```swift
//
//  cattura_riunioneApp.swift
//  cattura riunione
//
//  Punto d'ingresso: registra riunioni e ne produce il verbale trascritto.
//

import SwiftUI

@main
struct CatturaRiunioneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

`cattura riunione/ContentView.swift` (provvisorio, sostituito nel Task 10):

```swift
//
//  ContentView.swift
//  cattura riunione
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Cattura Riunione")
            .padding(40)
    }
}
```

Bridging header vuoto per ora (si riempie nel Task 5) — `cattura riunione/cattura riunione-Bridging-Header.h`:

```c
//
//  Header di bridging: espone a Swift le utilità Objective-C.
//
```

- [ ] **Step 7: test di sanità** — `cattura riunioneTests/SanityTests.swift`:

```swift
//
//  SanityTests.swift
//  Verifica che il target di test sia agganciato al modulo dell'app.
//

import XCTest
@testable import Cattura_Riunione

final class SanityTests: XCTestCase {
    func testModuloCaricato() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 8: copia Assets** — `cp -R "/Users/emi/workspace/cattura brano/cattura brano/Assets.xcassets" "cattura riunione/Assets.xcassets"`

- [ ] **Step 9: risolvi il pacchetto e compila** (serve rete la prima volta):

Run: `xcodebuild -project "cattura riunione.xcodeproj" -resolvePackageDependencies` poi il comando di build standard.
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 10: esegui i test**

Run: comando di test standard.
Expected: `TEST SUCCEEDED`, 1 test passato.

- [ ] **Step 11: Commit**

```bash
git add -A && git commit -m "Progetto Xcode: app, target di test e dipendenza FluidAudio"
```

---

### Task 2: Modello dati `Trascrizione`

**Files:**
- Create: `cattura riunione/Trascrizione.swift`
- Test: `cattura riunioneTests/TrascrizioneTests.swift`

**Interfaces:**
- Produces: `nonisolated struct Intervento: Codable, Equatable, Identifiable { var id: UUID; var idParlante: String; var inizio: Double; var fine: Double; var testo: String }`; `nonisolated struct Trascrizione: Codable, Equatable { var versione: Int; var durata: Double; var interventi: [Intervento]; var nomiParlanti: [String: String]; func nome(perParlante id: String) -> String; mutating func rinomina(parlante id: String, in nome: String); static func etichette(perOrdineDiComparsa interventi: [Intervento]) -> [String: String] }`; `nonisolated enum FormattaTempo { static func hhmmss(_ secondi: Double) -> String }`.

- [ ] **Step 1: test fallimentare** — `cattura riunioneTests/TrascrizioneTests.swift`:

```swift
//
//  TrascrizioneTests.swift
//  Modello del verbale: etichette, rinomina, andata/ritorno JSON, tempi.
//

import XCTest
@testable import Cattura_Riunione

final class TrascrizioneTests: XCTestCase {

    private func trascrizioneDiProva() -> Trascrizione {
        let interventi = [
            Intervento(id: UUID(), idParlante: "speaker_1", inizio: 0, fine: 4.2, testo: "Buongiorno a tutti."),
            Intervento(id: UUID(), idParlante: "speaker_0", inizio: 4.5, fine: 9.0, testo: "Buongiorno, iniziamo."),
            Intervento(id: UUID(), idParlante: "speaker_1", inizio: 9.4, fine: 12.0, testo: "Primo punto."),
        ]
        return Trascrizione(
            versione: 1,
            durata: 12.0,
            interventi: interventi,
            nomiParlanti: Trascrizione.etichette(perOrdineDiComparsa: interventi)
        )
    }

    func testEtichettePerOrdineDiComparsa() {
        let t = trascrizioneDiProva()
        // Chi parla per primo è "Parlante 1", a prescindere dall'id grezzo.
        XCTAssertEqual(t.nome(perParlante: "speaker_1"), "Parlante 1")
        XCTAssertEqual(t.nome(perParlante: "speaker_0"), "Parlante 2")
    }

    func testRinomina() {
        var t = trascrizioneDiProva()
        t.rinomina(parlante: "speaker_1", in: "Mario")
        XCTAssertEqual(t.nome(perParlante: "speaker_1"), "Mario")
        XCTAssertEqual(t.nome(perParlante: "speaker_0"), "Parlante 2")
    }

    func testRinominaVuotaRipristinaEtichetta() {
        var t = trascrizioneDiProva()
        t.rinomina(parlante: "speaker_1", in: "Mario")
        t.rinomina(parlante: "speaker_1", in: "   ")
        XCTAssertEqual(t.nome(perParlante: "speaker_1"), "Parlante 1")
    }

    func testAndataRitornoJSON() throws {
        let t = trascrizioneDiProva()
        let dati = try JSONEncoder().encode(t)
        let riletta = try JSONDecoder().decode(Trascrizione.self, from: dati)
        XCTAssertEqual(riletta, t)
    }

    func testFormattaTempo() {
        XCTAssertEqual(FormattaTempo.hhmmss(0), "00:00:00")
        XCTAssertEqual(FormattaTempo.hhmmss(62.9), "00:01:02")
        XCTAssertEqual(FormattaTempo.hhmmss(3725), "01:02:05")
    }
}
```

- [ ] **Step 2: esegui i test e verifica che falliscano**

Run: comando di test standard.
Expected: FAIL (tipi non definiti / errore di compilazione del target di test).

- [ ] **Step 3: implementazione** — `cattura riunione/Trascrizione.swift`:

```swift
//
//  Trascrizione.swift
//  cattura riunione
//
//  Il verbale strutturato di una riunione: interventi attribuiti ai
//  parlanti, con i nomi assegnati dall'utente. È il contenuto di
//  trascrizione.json nella cartella della riunione.
//

import Foundation

nonisolated struct Intervento: Codable, Equatable, Identifiable {
    var id: UUID
    /// Identificatore grezzo del parlante prodotto dalla diarizzazione.
    var idParlante: String
    /// Secondi dall'inizio della registrazione.
    var inizio: Double
    var fine: Double
    var testo: String
}

nonisolated struct Trascrizione: Codable, Equatable {
    var versione: Int
    var durata: Double
    var interventi: [Intervento]
    /// idParlante → nome mostrato. Contiene sempre tutti i parlanti:
    /// alla creazione le etichette ("Parlante 1"…) seguono l'ordine di
    /// prima comparsa, poi l'utente può sostituirle con i nomi veri.
    var nomiParlanti: [String: String]

    func nome(perParlante id: String) -> String {
        nomiParlanti[id] ?? "Parlante ?"
    }

    /// Rinomina un parlante; una stringa vuota ripristina l'etichetta
    /// predefinita in base all'ordine di comparsa.
    mutating func rinomina(parlante id: String, in nome: String) {
        let pulito = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        if pulito.isEmpty {
            nomiParlanti[id] = Self.etichette(perOrdineDiComparsa: interventi)[id]
        } else {
            nomiParlanti[id] = pulito
        }
    }

    /// Etichette predefinite: "Parlante 1" per chi parla per primo, e così via.
    static func etichette(perOrdineDiComparsa interventi: [Intervento]) -> [String: String] {
        var etichette: [String: String] = [:]
        for intervento in interventi.sorted(by: { $0.inizio < $1.inizio })
        where etichette[intervento.idParlante] == nil {
            etichette[intervento.idParlante] = "Parlante \(etichette.count + 1)"
        }
        return etichette
    }
}

nonisolated enum FormattaTempo {
    /// hh:mm:ss, troncato al secondo.
    static func hhmmss(_ secondi: Double) -> String {
        let s = max(0, Int(secondi))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}
```

- [ ] **Step 4: esegui i test e verifica che passino**

Run: comando di test standard.
Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "Modello Trascrizione: interventi, etichette e rinomina dei parlanti"`

---

### Task 3: Consolidamento dei turni di diarizzazione

**Files:**
- Create: `cattura riunione/TurniParlato.swift`
- Test: `cattura riunioneTests/TurniParlatoTests.swift`

**Interfaces:**
- Produces: `nonisolated struct TurnoParlato: Equatable { var idParlante: String; var inizio: Double; var fine: Double }`; `nonisolated enum TurniParlato { static func consolida(_ turni: [TurnoParlato], distanzaMassima: Double = 1.0, durataMinima: Double = 0.5) -> [TurnoParlato] }`
- Consumed by: Task 9 (`TranscriptionEngine` applica `consolida` all'uscita della diarizzazione prima di ritagliare l'audio).

- [ ] **Step 1: test fallimentare** — `cattura riunioneTests/TurniParlatoTests.swift`:

```swift
//
//  TurniParlatoTests.swift
//  La diarizzazione produce turni frammentati: qui si uniscono i
//  frammenti contigui dello stesso parlante e si scartano i microturni.
//

import XCTest
@testable import Cattura_Riunione

final class TurniParlatoTests: XCTestCase {

    func testUnisceFrammentiDelloStessoParlante() {
        let turni = [
            TurnoParlato(idParlante: "A", inizio: 0.0, fine: 3.0),
            TurnoParlato(idParlante: "A", inizio: 3.4, fine: 6.0),   // pausa 0,4 s: si unisce
            TurnoParlato(idParlante: "B", inizio: 6.5, fine: 9.0),
        ]
        let esito = TurniParlato.consolida(turni)
        XCTAssertEqual(esito, [
            TurnoParlato(idParlante: "A", inizio: 0.0, fine: 6.0),
            TurnoParlato(idParlante: "B", inizio: 6.5, fine: 9.0),
        ])
    }

    func testNonUnisceOltreLaDistanzaMassima() {
        let turni = [
            TurnoParlato(idParlante: "A", inizio: 0.0, fine: 3.0),
            TurnoParlato(idParlante: "A", inizio: 5.0, fine: 8.0),   // pausa 2 s: resta separato
        ]
        XCTAssertEqual(TurniParlato.consolida(turni).count, 2)
    }

    func testScartaMicroturni() {
        let turni = [
            TurnoParlato(idParlante: "A", inizio: 0.0, fine: 3.0),
            TurnoParlato(idParlante: "B", inizio: 3.1, fine: 3.3),   // 0,2 s: rumore, via
            TurnoParlato(idParlante: "A", inizio: 3.5, fine: 6.0),
        ]
        // Tolto il microturno di B, i due turni di A tornano contigui e si uniscono.
        XCTAssertEqual(TurniParlato.consolida(turni), [
            TurnoParlato(idParlante: "A", inizio: 0.0, fine: 6.0),
        ])
    }

    func testOrdinaPerInizio() {
        let turni = [
            TurnoParlato(idParlante: "B", inizio: 5.0, fine: 8.0),
            TurnoParlato(idParlante: "A", inizio: 0.0, fine: 4.0),
        ]
        XCTAssertEqual(TurniParlato.consolida(turni).map(\.idParlante), ["A", "B"])
    }

    func testVuoto() {
        XCTAssertEqual(TurniParlato.consolida([]), [])
    }
}
```

- [ ] **Step 2: esegui i test e verifica che falliscano** — Expected: errore di compilazione (tipi mancanti).

- [ ] **Step 3: implementazione** — `cattura riunione/TurniParlato.swift`:

```swift
//
//  TurniParlato.swift
//  cattura riunione
//
//  Pulizia dei turni di parola in uscita dalla diarizzazione, prima del
//  ritaglio audio per la trascrizione.
//

import Foundation

nonisolated struct TurnoParlato: Equatable {
    var idParlante: String
    var inizio: Double
    var fine: Double
}

nonisolated enum TurniParlato {
    /// Ordina i turni, scarta quelli più corti di `durataMinima` e unisce
    /// i turni consecutivi dello stesso parlante separati da meno di
    /// `distanzaMassima` secondi. L'ordine delle operazioni conta: lo
    /// scarto dei microturni può rendere contigui turni prima separati.
    static func consolida(
        _ turni: [TurnoParlato],
        distanzaMassima: Double = 1.0,
        durataMinima: Double = 0.5
    ) -> [TurnoParlato] {
        let validi = turni
            .filter { $0.fine - $0.inizio >= durataMinima }
            .sorted { $0.inizio < $1.inizio }

        var esito: [TurnoParlato] = []
        for turno in validi {
            if var ultimo = esito.last,
               ultimo.idParlante == turno.idParlante,
               turno.inizio - ultimo.fine <= distanzaMassima {
                ultimo.fine = max(ultimo.fine, turno.fine)
                esito[esito.count - 1] = ultimo
            } else {
                esito.append(turno)
            }
        }
        return esito
    }
}
```

- [ ] **Step 4: esegui i test e verifica che passino** — Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "Consolidamento dei turni di parola dalla diarizzazione"`

---

### Task 4: Esportazione del verbale in Markdown

**Files:**
- Create: `cattura riunione/VerbaleMarkdown.swift`
- Test: `cattura riunioneTests/VerbaleMarkdownTests.swift`

**Interfaces:**
- Consumes: `Trascrizione`, `FormattaTempo` (Task 2).
- Produces: `nonisolated enum VerbaleMarkdown { static func esporta(_ trascrizione: Trascrizione, titolo: String, data: Date) -> String }`

- [ ] **Step 1: test fallimentare** — `cattura riunioneTests/VerbaleMarkdownTests.swift`:

```swift
//
//  VerbaleMarkdownTests.swift
//

import XCTest
@testable import Cattura_Riunione

final class VerbaleMarkdownTests: XCTestCase {

    func testEsportazione() {
        let interventi = [
            Intervento(id: UUID(), idParlante: "s1", inizio: 0, fine: 4, testo: "Buongiorno a tutti."),
            Intervento(id: UUID(), idParlante: "s0", inizio: 65, fine: 70, testo: "Iniziamo."),
        ]
        var t = Trascrizione(
            versione: 1, durata: 70, interventi: interventi,
            nomiParlanti: Trascrizione.etichette(perOrdineDiComparsa: interventi)
        )
        t.rinomina(parlante: "s0", in: "Mario")

        var componenti = DateComponents()
        (componenti.year, componenti.month, componenti.day) = (2026, 9, 2)
        let data = Calendar(identifier: .gregorian).date(from: componenti)!

        let md = VerbaleMarkdown.esporta(t, titolo: "Riunione di prova", data: data)

        XCTAssertTrue(md.hasPrefix("# Riunione di prova\n"))
        XCTAssertTrue(md.contains("2 settembre 2026"))
        XCTAssertTrue(md.contains("**Parlante 1** (00:00:00)\nBuongiorno a tutti."))
        XCTAssertTrue(md.contains("**Mario** (00:01:05)\nIniziamo."))
        XCTAssertTrue(md.contains("Durata: 00:01:10"))
    }

    func testSenzaInterventi() {
        let t = Trascrizione(versione: 1, durata: 0, interventi: [], nomiParlanti: [:])
        let md = VerbaleMarkdown.esporta(t, titolo: "Vuota", data: Date())
        XCTAssertTrue(md.contains("Nessun intervento rilevato."))
    }
}
```

- [ ] **Step 2: esegui i test e verifica che falliscano** — Expected: errore di compilazione.

- [ ] **Step 3: implementazione** — `cattura riunione/VerbaleMarkdown.swift`:

```swift
//
//  VerbaleMarkdown.swift
//  cattura riunione
//
//  Il verbale in forma leggibile: il file verbale.md salvato accanto
//  all'audio e il testo per il pulsante Copia.
//

import Foundation

nonisolated enum VerbaleMarkdown {

    static func esporta(_ trascrizione: Trascrizione, titolo: String, data: Date) -> String {
        let formattatore = DateFormatter()
        formattatore.locale = Locale(identifier: "it_IT")
        formattatore.dateStyle = .long
        formattatore.timeStyle = .none

        var righe: [String] = []
        righe.append("# \(titolo)")
        righe.append("")
        righe.append("\(formattatore.string(from: data)) · Durata: \(FormattaTempo.hhmmss(trascrizione.durata))")
        righe.append("")

        if trascrizione.interventi.isEmpty {
            righe.append("Nessun intervento rilevato.")
        } else {
            for intervento in trascrizione.interventi.sorted(by: { $0.inizio < $1.inizio }) {
                righe.append("**\(trascrizione.nome(perParlante: intervento.idParlante))** (\(FormattaTempo.hhmmss(intervento.inizio)))")
                righe.append(intervento.testo)
                righe.append("")
            }
        }
        return righe.joined(separator: "\n")
    }
}
```

- [ ] **Step 4: esegui i test e verifica che passino** — Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "Esportazione del verbale in Markdown"`

---

### Task 5: Sorgenti di registrazione riusati da cattura brano

**Files:**
- Copia testuale (aggiorna solo l'intestazione del file col nuovo nome dell'app):
  - `cattura riunione/AudioInputDevice.swift` ← `/Users/emi/workspace/cattura brano/cattura brano/AudioInputDevice.swift`
  - `cattura riunione/OutputFolderStore.swift` ← `.../OutputFolderStore.swift`
  - `cattura riunione/ObjCExceptionCatcher.h` e `.m` ← `.../ObjCExceptionCatcher.h`, `.m`
- Modify: `cattura riunione/cattura riunione-Bridging-Header.h` (importa ObjCExceptionCatcher.h, come fa `cattura brano-Bridging-Header.h`)
- Create: `cattura riunione/TapWriter.swift` ← estrai da `.../AudioProcessing.swift` SOLO `RecorderError` (righe ~10–30) e `TapWriter` (righe ~47–117), copiandoli tali e quali in un file nuovo con una breve intestazione
- Create: `cattura riunione/AudioRecorder.swift` (versione adattata, sotto)

**Interfaces:**
- Consumes: `TapWriter(url: URL?, format: AVAudioFormat)`, `.append(_:)`, `.close()`, `.consumePeaks()`; `AudioDeviceEnumerator.inputDevices()`, `.defaultInputDevice()`; `CBCatchObjCException` (dal bridging header).
- Produces: `@MainActor @Observable final class AudioRecorder` con `devices`, `selectedDeviceID`, `selectedDevice`, `isRecording`, `elapsed`, `levels`, `errorMessage`, `func refreshDevices()`, `func startMonitoring() async`, `func noteDeviceChanged()`, `func startRecording() async -> Bool`, `func stopRecording() -> URL?` (restituisce il CAF temporaneo del microfono).

- [ ] **Step 1: copia i file elencati** (comandi `cp`, poi aggiorna il commento d'intestazione «cattura brano» → «cattura riunione» in ciascuno). Nel bridging header replica il contenuto di quello di cattura brano (l'`#import "ObjCExceptionCatcher.h"`).

- [ ] **Step 2: `TapWriter.swift`** — file nuovo con intestazione:

```swift
//
//  TapWriter.swift
//  cattura riunione
//
//  Riusato da cattura brano: scrittura su file del tap di AVAudioEngine
//  e misura dei picchi per il misuratore di livello.
//
```

seguita dalla copia INTEGRALE e non modificata di `RecorderError` e `TapWriter` da `AudioProcessing.swift` di cattura brano (con i loro `import` necessari: `AVFoundation`).

- [ ] **Step 3: `AudioRecorder.swift` adattato** — è l'AudioRecorder di cattura brano senza tutta la pipeline musicale (trim, BPM, click, demucs, formati). Contenuto completo:

```swift
//
//  AudioRecorder.swift
//  cattura riunione
//
//  Riusato da cattura brano e ridotto all'essenziale: selezione
//  dell'interfaccia, monitoraggio del livello, registrazione del
//  microfono su file temporaneo. Le lezioni imparate restano: tap sul
//  formato REALE dell'hardware e guardia sulle NSException di
//  AVAudioEngine.
//

import AVFoundation
import CoreAudio
import Observation
import SwiftUI

@MainActor
@Observable
final class AudioRecorder {

    // MARK: Stato osservabile

    var devices: [AudioInputDevice] = []
    var selectedDeviceID: AudioDeviceID?
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    /// Picchi lineari (0…1) per canale, aggiornati durante la registrazione.
    private(set) var levels: [Float] = []
    var errorMessage: String?

    // MARK: Stato interno

    private let engine = AVAudioEngine()
    private var writer: TapWriter?
    /// Tap di solo monitoraggio, attivo quando non si registra.
    private var monitor: TapWriter?
    private var tempURL: URL?
    private var startDate: Date?
    private var meterTask: Task<Void, Never>?

    var selectedDevice: AudioInputDevice? {
        devices.first { $0.id == selectedDeviceID }
    }

    init() {
        refreshDevices()
        Task { await startMonitoring() }
    }

    // MARK: Dispositivi

    func refreshDevices() {
        devices = AudioDeviceEnumerator.inputDevices()
        if selectedDeviceID == nil || !devices.contains(where: { $0.id == selectedDeviceID }) {
            selectedDeviceID = AudioDeviceEnumerator.defaultInputDevice() ?? devices.first?.id
        }
    }

    // MARK: Monitoraggio del livello (senza registrare)

    /// Avvia il motore audio con un tap di sola misura, così il misuratore
    /// mostra il livello d'ingresso anche prima di registrare.
    func startMonitoring() async {
        guard !isRecording, monitor == nil else { return }
        // Senza permesso non mostriamo errori: il messaggio arriva solo
        // quando l'utente prova davvero a registrare.
        guard await requestMicrophoneAccess() else { return }
        // La risposta al permesso può arrivare molto dopo (finestra di sistema
        // al primo avvio): nel frattempo l'utente può aver premuto Registra.
        // Senza questo ricontrollo si installerebbe un secondo tap sul bus già
        // occupato, e AVAudioEngine abbatte l'app con una NSException.
        guard !isRecording, monitor == nil else { return }

        do {
            try configureEngineInput()
            let input = engine.inputNode
            let format = try validatedInputFormat(of: input)

            let monitor = try TapWriter(url: nil, format: format)
            try withObjCExceptionGuard {
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    monitor.append(buffer)
                }
                engine.prepare()
                try engine.start()
            }

            self.monitor = monitor
            startMeter()
        } catch {
            stopMonitoring()
            if errorMessage == nil {
                errorMessage = "Ingresso non attivo: \(error.localizedDescription)"
            }
        }
    }

    private func stopMonitoring() {
        // Nessuna guardia su `monitor`: se l'avvio del monitoraggio fallisce
        // dopo installTap, il tap resta installato con `monitor` ancora nil,
        // e va comunque rimosso (removeTap è innocuo se non c'è alcun tap).
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        monitor = nil
        stopMeter()
        levels = []
    }

    /// Da chiamare quando cambia l'interfaccia selezionata.
    func noteDeviceChanged() {
        guard !isRecording else { return }
        errorMessage = nil
        stopMonitoring()
        Task { await startMonitoring() }
    }

    // MARK: Registrazione

    /// Avvia la registrazione del microfono. Restituisce `false` se non
    /// è stato possibile partire (l'errore è in `errorMessage`).
    func startRecording() async -> Bool {
        guard !isRecording else { return false }
        errorMessage = nil

        guard await requestMicrophoneAccess() else {
            errorMessage = "Permesso al microfono negato. Abilitalo in Impostazioni di Sistema › Privacy e sicurezza › Microfono."
            return false
        }

        stopMonitoring()

        do {
            let input = engine.inputNode
            try configureEngineInput()
            let format = try validatedInputFormat(of: input)

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("riunione-mic-\(UUID().uuidString).caf")
            let writer = try TapWriter(url: tempURL, format: format)

            try withObjCExceptionGuard {
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    writer.append(buffer)
                }
                engine.prepare()
                try engine.start()
            }

            self.writer = writer
            self.tempURL = tempURL
            self.startDate = Date()
            self.elapsed = 0
            self.isRecording = true
            startMeter()
            return true
        } catch {
            cleanupEngine()
            errorMessage = "Impossibile avviare la registrazione: \(error.localizedDescription)"
            await startMonitoring()
            return false
        }
    }

    /// Ferma la registrazione e restituisce il CAF temporaneo col
    /// microfono; il chiamante ne diventa proprietario (e lo elimina).
    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        isRecording = false
        stopMeter()
        levels = []
        startDate = nil

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        defer { Task { await startMonitoring() } }

        guard let writer, let tempURL else { return nil }
        writer.close()
        self.writer = nil
        self.tempURL = nil
        return tempURL
    }

    // MARK: Utilità

    /// Formato con cui installare il tap sul nodo d'ingresso: quello REALE
    /// dell'hardware (`inputFormat`), mai quello del bus di uscita
    /// (`outputFormat`), che dopo un cambio di interfaccia può restare in
    /// cache col formato del dispositivo precedente e far fallire
    /// installTap con "Failed to create tap due to format mismatch".
    private func validatedInputFormat(of input: AVAudioInputNode) throws -> AVAudioFormat {
        let hardware = input.inputFormat(forBus: 0)
        guard hardware.sampleRate > 0, hardware.channelCount > 0 else {
            throw RecorderError.invalidFormat
        }
        return hardware
    }

    /// Esegue `body` intercettando sia gli errori Swift sia le NSException
    /// Objective-C di AVAudioEngine: un'eccezione lasciata correre fin
    /// dentro AppKit corromperebbe lo stato della concorrenza Swift.
    private func withObjCExceptionGuard(_ body: () throws -> Void) throws {
        var swiftError: Error?
        let objcError = CBCatchObjCException {
            do { try body() } catch { swiftError = error }
        }
        if let swiftError { throw swiftError }
        if let objcError { throw objcError }
    }

    /// Instrada il nodo d'ingresso del motore verso l'interfaccia selezionata.
    private func configureEngineInput() throws {
        guard let device = selectedDevice, let audioUnit = engine.inputNode.audioUnit else { return }
        var deviceID = device.id
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else { throw RecorderError.deviceSelectionFailed(status) }
        // Scarta i formati che il motore tiene in cache dal dispositivo
        // precedente: senza reset il tap fallirebbe per formato discordante.
        engine.reset()
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    private func startMeter() {
        stopMeter()
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard let self else { break }
                guard let source = self.writer ?? self.monitor else { break }
                let peaks = source.consumePeaks()
                if self.levels.count != peaks.count {
                    self.levels = peaks
                } else {
                    // Balistica da peak meter: attacco immediato, rilascio
                    // graduale, per una lettura stabile senza sfarfallio.
                    self.levels = zip(self.levels, peaks).map { max($1, $0 * 0.631) }
                }
                if self.isRecording, let startDate = self.startDate {
                    self.elapsed = Date().timeIntervalSince(startDate)
                }
            }
        }
    }

    private func stopMeter() {
        meterTask?.cancel()
        meterTask = nil
    }

    private func cleanupEngine() {
        stopMeter()
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        writer?.close()
        writer = nil
        monitor = nil
        if let tempURL { try? FileManager.default.removeItem(at: tempURL) }
        tempURL = nil
        isRecording = false
    }
}
```

NOTA: se `RecorderError` in cattura brano non ha esattamente i casi `invalidFormat` e `deviceSelectionFailed(OSStatus)`, adegua i riferimenti qui sopra ai casi reali copiati nel Task 5 Step 2 — mai il contrario.

- [ ] **Step 4: compila** — Run: comando di build standard. Expected: BUILD SUCCEEDED (i tipi nuovi non sono ancora usati dalla UI: va bene).

- [ ] **Step 5: esegui i test** (regressione) — Expected: TEST SUCCEEDED.

- [ ] **Step 6: Commit** — `git add -A && git commit -m "Impianto di registrazione riusato da cattura brano"`

---

### Task 6: Utilità audio — caricamento/ricampionamento, miscelazione, m4a

**Files:**
- Create: `cattura riunione/AudioCampioni.swift`
- Test: `cattura riunioneTests/AudioCampioniTests.swift`

**Interfaces:**
- Produces: `nonisolated enum AudioCampioni { static func carica(_ url: URL, frequenza: Double) throws -> [Float]; static func miscela(_ a: [Float], _ b: [Float]) -> [Float]; static func scriviM4A(_ campioni: [Float], frequenza: Double, in url: URL) throws }`
- Consumed by: Task 8 (mixdown → m4a) e Task 9 (file → campioni 16 kHz per i modelli).

- [ ] **Step 1: test fallimentare** — `cattura riunioneTests/AudioCampioniTests.swift`:

```swift
//
//  AudioCampioniTests.swift
//  Le utilità audio si provano con file sintetici generati al volo.
//

import AVFoundation
import XCTest
@testable import Cattura_Riunione

final class AudioCampioniTests: XCTestCase {

    /// Scrive un WAV mono di `durata` secondi con una sinusoide a 440 Hz.
    private func wavDiProva(frequenza: Double, durata: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("prova-\(UUID().uuidString).wav")
        let formato = AVAudioFormat(standardFormatWithSampleRate: frequenza, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: formato.settings)
        let frames = AVAudioFrameCount(frequenza * durata)
        let buffer = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: frames)!
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            buffer.floatChannelData![0][i] = sin(Float(i) * 2 * .pi * 440 / Float(frequenza)) * 0.5
        }
        try file.write(from: buffer)
        return url
    }

    func testCaricaRicampionaA16k() throws {
        let url = try wavDiProva(frequenza: 48000, durata: 2.0)
        defer { try? FileManager.default.removeItem(at: url) }
        let campioni = try AudioCampioni.carica(url, frequenza: 16000)
        // 2 secondi a 16 kHz, con tolleranza per i bordi del convertitore.
        XCTAssertEqual(Double(campioni.count), 32000, accuracy: 1600)
        XCTAssertTrue(campioni.contains { abs($0) > 0.1 }, "il segnale non deve sparire")
    }

    func testMiscelaSommaEConserva() {
        let a: [Float] = [0.5, 0.5, 0.5]
        let b: [Float] = [0.25, -0.25]
        let mix = AudioCampioni.miscela(a, b)
        XCTAssertEqual(mix.count, 3)
        XCTAssertEqual(mix[0], 0.75, accuracy: 0.001)
        XCTAssertEqual(mix[1], 0.25, accuracy: 0.001)
        XCTAssertEqual(mix[2], 0.5, accuracy: 0.001)
    }

    func testMiscelaLimitaIlFondoScala() {
        let mix = AudioCampioni.miscela([0.9], [0.9])
        XCTAssertLessThanOrEqual(mix[0], 1.0)
    }

    func testScriviM4A() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("prova-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let campioni = [Float](repeating: 0.1, count: 48000)
        try AudioCampioni.scriviM4A(campioni, frequenza: 48000, in: url)
        let riletto = try AVAudioFile(forReading: url)
        // Un secondo di audio, con la tolleranza del priming AAC.
        XCTAssertEqual(Double(riletto.length), 48000, accuracy: 4800)
    }
}
```

- [ ] **Step 2: esegui i test e verifica che falliscano** — Expected: errore di compilazione.

- [ ] **Step 3: implementazione** — `cattura riunione/AudioCampioni.swift`:

```swift
//
//  AudioCampioni.swift
//  cattura riunione
//
//  Passaggi audio della post-elaborazione: decodifica qualunque file in
//  campioni mono Float alla frequenza voluta (48 kHz per l'archivio,
//  16 kHz per i modelli), miscela microfono e audio di sistema, scrive
//  l'm4a d'archivio.
//

import AVFoundation

nonisolated enum AudioCampioni {

    enum Errore: LocalizedError {
        case formatoNonValido
        case conversioneFallita
        var errorDescription: String? {
            switch self {
            case .formatoNonValido: "Formato audio non gestibile."
            case .conversioneFallita: "Conversione audio fallita."
            }
        }
    }

    /// Decodifica `url` (wav, caf, m4a, mp3, aiff…) in campioni mono
    /// Float32 alla frequenza richiesta.
    static func carica(_ url: URL, frequenza: Double) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard let destinazione = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: frequenza,
            channels: 1, interleaved: false
        ), let convertitore = AVAudioConverter(from: file.processingFormat, to: destinazione) else {
            throw Errore.formatoNonValido
        }

        var campioni: [Float] = []
        campioni.reserveCapacity(Int(Double(file.length) * frequenza / file.processingFormat.sampleRate) + 4096)
        let blocco = AVAudioFrameCount(8192)
        var finita = false

        while true {
            guard let uscita = AVAudioPCMBuffer(pcmFormat: destinazione, frameCapacity: blocco) else {
                throw Errore.conversioneFallita
            }
            var erroreConversione: NSError?
            let stato = convertitore.convert(to: uscita, error: &erroreConversione) { richiesti, statoIngresso in
                if finita {
                    statoIngresso.pointee = .endOfStream
                    return nil
                }
                guard let ingresso = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: richiesti) else {
                    statoIngresso.pointee = .endOfStream
                    return nil
                }
                do {
                    try file.read(into: ingresso)
                } catch {
                    statoIngresso.pointee = .endOfStream
                    return nil
                }
                if ingresso.frameLength == 0 {
                    finita = true
                    statoIngresso.pointee = .endOfStream
                    return nil
                }
                statoIngresso.pointee = .haveData
                return ingresso
            }
            if let erroreConversione { throw erroreConversione }
            if uscita.frameLength > 0, let dati = uscita.floatChannelData {
                campioni.append(contentsOf: UnsafeBufferPointer(start: dati[0], count: Int(uscita.frameLength)))
            }
            if stato == .endOfStream || (stato == .inputRanDry && finita) { break }
            if uscita.frameLength == 0 { break }
        }
        return campioni
    }

    /// Somma due tracce campione per campione (lunghezze diverse ammesse)
    /// con limitazione morbida del fondo scala.
    static func miscela(_ a: [Float], _ b: [Float]) -> [Float] {
        let (lunga, corta) = a.count >= b.count ? (a, b) : (b, a)
        var esito = lunga
        for i in corta.indices { esito[i] += corta[i] }
        for i in esito.indices { esito[i] = max(-1, min(1, esito[i])) }
        return esito
    }

    /// Scrive i campioni mono in un m4a (AAC) alla frequenza data.
    static func scriviM4A(_ campioni: [Float], frequenza: Double, in url: URL) throws {
        guard let formato = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: frequenza,
            channels: 1, interleaved: false
        ) else { throw Errore.formatoNonValido }

        let impostazioni: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: frequenza,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96000,
        ]
        let file = try AVAudioFile(forWriting: url, settings: impostazioni,
                                   commonFormat: .pcmFormatFloat32, interleaved: false)

        let blocco = 8192
        var indice = 0
        while indice < campioni.count {
            let quanti = min(blocco, campioni.count - indice)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: AVAudioFrameCount(quanti)) else {
                throw Errore.conversioneFallita
            }
            buffer.frameLength = AVAudioFrameCount(quanti)
            campioni.withUnsafeBufferPointer { sorgente in
                buffer.floatChannelData![0].update(from: sorgente.baseAddress! + indice, count: quanti)
            }
            try file.write(from: buffer)
            indice += quanti
        }
    }
}
```

- [ ] **Step 4: esegui i test e verifica che passino** — Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "Utilità audio: decodifica, ricampionamento, miscelazione e m4a"`

---

### Task 7: Cattura dell'audio di sistema (process tap)

**Files:**
- Create: `cattura riunione/SystemAudioTap.swift`

**Interfaces:**
- Produces: `final class SystemAudioTap` (MainActor per il ciclo di vita, callback audio interne nonisolate) con `init()`, `func avvia() throws -> URL` (crea il tap, il dispositivo aggregato e il file CAF temporaneo; il primo avvio fa comparire la richiesta di permesso di sistema), `func ferma()`. In caso d'errore lancia `SystemAudioTap.Errore` con messaggi in italiano.
- Consumed by: Task 8 (`MeetingRecorder`), che in caso di `throw` prosegue col solo microfono.

- [ ] **Step 1: implementazione** — `cattura riunione/SystemAudioTap.swift`. Riferimento: process tap di Core Audio, macOS 14.2+ (documentazione: `CATapDescription`, `AudioHardwareCreateProcessTap`, `AudioHardwareCreateAggregateDevice`). Se un simbolo non corrisponde, consulta gli header di CoreAudio nell'SDK e correggi mantenendo la struttura:

```swift
//
//  SystemAudioTap.swift
//  cattura riunione
//
//  Cattura l'audio riprodotto dalle altre app (le voci dei partecipanti
//  a una call) con un process tap di Core Audio: tap globale su tutti i
//  processi → dispositivo aggregato privato → IOProc che scrive su CAF.
//  Il primo avvio fa comparire la richiesta di sistema "registrazione
//  dell'audio di sistema" (NSAudioCaptureUsageDescription).
//

import AudioToolbox
import CoreAudio
import Foundation

final class SystemAudioTap {

    nonisolated enum Errore: LocalizedError {
        case creazioneTap(OSStatus)
        case formatoTap(OSStatus)
        case dispositivoAggregato(OSStatus)
        case ioProc(OSStatus)
        case file(OSStatus)

        var errorDescription: String? {
            switch self {
            case .creazioneTap(let s): "Cattura dell'audio di sistema negata o non disponibile (\(s))."
            case .formatoTap(let s): "Formato del tap di sistema non leggibile (\(s))."
            case .dispositivoAggregato(let s): "Creazione del dispositivo di cattura fallita (\(s))."
            case .ioProc(let s): "Avvio della cattura di sistema fallito (\(s))."
            case .file(let s): "Creazione del file per l'audio di sistema fallita (\(s))."
            }
        }
    }

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregatoID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var file: ExtAudioFileRef?
    private var bytesPerFrame: UInt32 = 0
    private(set) var url: URL?

    /// Crea tap, dispositivo aggregato e file, e avvia la cattura.
    /// Restituisce l'URL del CAF temporaneo in scrittura.
    func avvia() throws -> URL {
        // 1. Tap globale: mixdown stereo di tutti i processi.
        let descrizione = CATapDescription(stereoMixdownOfProcesses: [])
        descrizione.isPrivate = true
        var nuovoTap = AudioObjectID(kAudioObjectUnknown)
        var stato = AudioHardwareCreateProcessTap(descrizione, &nuovoTap)
        guard stato == noErr else { throw Errore.creazioneTap(stato) }
        tapID = nuovoTap

        // 2. Formato dell'audio prodotto dal tap.
        var indirizzo = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var asbd = AudioStreamBasicDescription()
        var dimensione = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        stato = AudioObjectGetPropertyData(tapID, &indirizzo, 0, nil, &dimensione, &asbd)
        guard stato == noErr else { ferma(); throw Errore.formatoTap(stato) }
        bytesPerFrame = asbd.mBytesPerFrame

        // 3. Dispositivo aggregato privato che contiene solo il tap.
        let composizione: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Cattura Riunione — audio di sistema",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [
                [kAudioSubTapUIDKey: descrizione.uuid.uuidString]
            ],
        ]
        var nuovoAggregato = AudioObjectID(kAudioObjectUnknown)
        stato = AudioHardwareCreateAggregateDevice(composizione as CFDictionary, &nuovoAggregato)
        guard stato == noErr else { ferma(); throw Errore.dispositivoAggregato(stato) }
        aggregatoID = nuovoAggregato

        // 4. File CAF temporaneo nel formato del tap.
        let destinazione = FileManager.default.temporaryDirectory
            .appendingPathComponent("riunione-sistema-\(UUID().uuidString).caf")
        var nuovoFile: ExtAudioFileRef?
        stato = ExtAudioFileCreateWithURL(
            destinazione as CFURL, kAudioFileCAFType, &asbd, nil,
            AudioFileFlags.eraseFile.rawValue, &nuovoFile
        )
        guard stato == noErr, let nuovoFile else { ferma(); throw Errore.file(stato) }
        stato = ExtAudioFileSetProperty(
            nuovoFile, kExtAudioFileProperty_ClientDataFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &asbd
        )
        guard stato == noErr else { ferma(); throw Errore.file(stato) }
        ExtAudioFileWriteAsync(nuovoFile, 0, nil) // innesca la coda asincrona
        file = nuovoFile

        // 5. IOProc: copia l'ingresso del dispositivo aggregato sul file.
        let fileLocale = nuovoFile
        let bpf = bytesPerFrame
        stato = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregatoID, nil) {
            _, ingresso, _, _, _ in
            let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: ingresso))
            guard let primo = buffers.first, bpf > 0 else { return }
            let frames = primo.mDataByteSize / bpf
            if frames > 0 {
                ExtAudioFileWriteAsync(fileLocale, frames, ingresso)
            }
        }
        guard stato == noErr, let ioProcID else { ferma(); throw Errore.ioProc(stato) }
        stato = AudioDeviceStart(aggregatoID, ioProcID)
        guard stato == noErr else { ferma(); throw Errore.ioProc(stato) }

        url = destinazione
        return destinazione
    }

    /// Ferma la cattura e rilascia tap, dispositivo e file (idempotente).
    func ferma() {
        if let ioProcID, aggregatoID != kAudioObjectUnknown {
            AudioDeviceStop(aggregatoID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregatoID, ioProcID)
        }
        ioProcID = nil
        if aggregatoID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregatoID)
            aggregatoID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        if let file {
            ExtAudioFileDispose(file)
            self.file = nil
        }
    }
}
```

- [ ] **Step 2: compila** — Run: comando di build standard. Expected: BUILD SUCCEEDED. Se qualche simbolo Core Audio non esiste con quel nome esatto, cercalo negli header dell'SDK (`xcrun --show-sdk-path`, poi in `System/Library/Frameworks/CoreAudio.framework/Headers/AudioHardwareTapping.h` e `CATapDescription.h`) e adatta.

- [ ] **Step 3: esegui i test** (regressione) — Expected: TEST SUCCEEDED.

- [ ] **Step 4: Commit** — `git add -A && git commit -m "Cattura dell'audio di sistema con i process tap di Core Audio"`

Nota: il comportamento reale (permesso, contenuto del file) si verifica nel Task 13 con la prova guidata; qui basta che compili e che l'API regga i fallimenti.

---

### Task 8: `MeetingStore` (cartelle riunione) e `MeetingRecorder` (orchestrazione)

**Files:**
- Create: `cattura riunione/MeetingStore.swift`
- Create: `cattura riunione/MeetingRecorder.swift`
- Test: `cattura riunioneTests/MeetingStoreTests.swift`

**Interfaces:**
- Consumes: `Trascrizione`, `VerbaleMarkdown` (Task 2/4), `AudioCampioni` (Task 6), `AudioRecorder` (Task 5), `SystemAudioTap` (Task 7).
- Produces:
  - `nonisolated struct Riunione: Identifiable, Equatable { var id: URL { cartella }; var cartella: URL; var nome: String; var data: Date; var audioURL: URL; var haTrascrizione: Bool }`
  - `nonisolated enum MeetingStore { static func creaCartella(in base: URL, data: Date) throws -> URL; static func salva(_ t: Trascrizione, in cartella: URL) throws; static func caricaTrascrizione(da cartella: URL) -> Trascrizione?; static func salvaVerbale(_ t: Trascrizione, in cartella: URL) throws; static func elenca(in base: URL) -> [Riunione] }` — nomi file fissi: `riunione.m4a`, `trascrizione.json`, `verbale.md`.
  - `@MainActor @Observable final class MeetingRecorder` con `let microfono: AudioRecorder`, `var catturaSistema = true`, `private(set) var avvisoSistema: String?`, `func avvia() async`, `func ferma(in cartellaBase: URL) async -> URL?` (restituisce la cartella della riunione con `riunione.m4a` già scritto, o `nil` con errore in `microfono.errorMessage`).

- [ ] **Step 1: test fallimentare** — `cattura riunioneTests/MeetingStoreTests.swift`:

```swift
//
//  MeetingStoreTests.swift
//

import XCTest
@testable import Cattura_Riunione

final class MeetingStoreTests: XCTestCase {

    private var base: URL!

    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("riunioni-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: base)
    }

    private var trascrizione: Trascrizione {
        let interventi = [Intervento(id: UUID(), idParlante: "s0", inizio: 0, fine: 3, testo: "Ciao.")]
        return Trascrizione(versione: 1, durata: 3, interventi: interventi,
                            nomiParlanti: Trascrizione.etichette(perOrdineDiComparsa: interventi))
    }

    func testCreaCartellaConNomeDatato() throws {
        var c = DateComponents()
        (c.year, c.month, c.day, c.hour, c.minute) = (2026, 9, 2, 14, 30)
        let data = Calendar(identifier: .gregorian).date(from: c)!
        let cartella = try MeetingStore.creaCartella(in: base, data: data)
        XCTAssertEqual(cartella.lastPathComponent, "Riunione 2026-09-02 14.30")
        XCTAssertTrue(FileManager.default.fileExists(atPath: cartella.path))
    }

    func testCartellaDuplicataRiceveSuffisso() throws {
        let data = Date()
        let prima = try MeetingStore.creaCartella(in: base, data: data)
        let seconda = try MeetingStore.creaCartella(in: base, data: data)
        XCTAssertNotEqual(prima, seconda)
        XCTAssertTrue(FileManager.default.fileExists(atPath: seconda.path))
    }

    func testSalvaECarica() throws {
        let cartella = try MeetingStore.creaCartella(in: base, data: Date())
        try MeetingStore.salva(trascrizione, in: cartella)
        let riletta = MeetingStore.caricaTrascrizione(da: cartella)
        XCTAssertEqual(riletta, trascrizione)
        // salva() rigenera anche il verbale.md.
        let verbale = cartella.appendingPathComponent("verbale.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: verbale.path))
    }

    func testElenca() throws {
        let cartella = try MeetingStore.creaCartella(in: base, data: Date())
        // Senza riunione.m4a la cartella non è una riunione valida.
        XCTAssertTrue(MeetingStore.elenca(in: base).isEmpty)
        FileManager.default.createFile(
            atPath: cartella.appendingPathComponent("riunione.m4a").path, contents: Data([0])
        )
        let riunioni = MeetingStore.elenca(in: base)
        XCTAssertEqual(riunioni.count, 1)
        XCTAssertEqual(riunioni[0].cartella, cartella)
        XCTAssertFalse(riunioni[0].haTrascrizione)
    }
}
```

- [ ] **Step 2: esegui i test e verifica che falliscano** — Expected: errore di compilazione.

- [ ] **Step 3: implementazione `MeetingStore.swift`**:

```swift
//
//  MeetingStore.swift
//  cattura riunione
//
//  Ogni riunione è una cartella "Riunione AAAA-MM-GG HH.mm" nella
//  cartella di destinazione, con dentro riunione.m4a, trascrizione.json
//  e verbale.md. Qui vivono creazione, salvataggio, lettura ed elenco.
//

import Foundation

nonisolated struct Riunione: Identifiable, Equatable {
    var id: URL { cartella }
    var cartella: URL
    var nome: String
    var data: Date
    var audioURL: URL
    var haTrascrizione: Bool
}

nonisolated enum MeetingStore {

    static let nomeAudio = "riunione.m4a"
    static let nomeTrascrizione = "trascrizione.json"
    static let nomeVerbale = "verbale.md"

    private static var formattatore: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "yyyy-MM-dd HH.mm"
        return f
    }

    /// Crea la cartella "Riunione AAAA-MM-GG HH.mm" (con suffisso ~2, ~3…
    /// se esiste già) e la restituisce.
    static func creaCartella(in base: URL, data: Date) throws -> URL {
        let nomeBase = "Riunione \(formattatore.string(from: data))"
        var candidata = base.appendingPathComponent(nomeBase)
        var progressivo = 2
        while FileManager.default.fileExists(atPath: candidata.path) {
            candidata = base.appendingPathComponent("\(nomeBase) ~\(progressivo)")
            progressivo += 1
        }
        try FileManager.default.createDirectory(at: candidata, withIntermediateDirectories: true)
        return candidata
    }

    /// Salva trascrizione.json e rigenera verbale.md.
    static func salva(_ trascrizione: Trascrizione, in cartella: URL) throws {
        let codificatore = JSONEncoder()
        codificatore.outputFormatting = [.prettyPrinted, .sortedKeys]
        try codificatore.encode(trascrizione)
            .write(to: cartella.appendingPathComponent(nomeTrascrizione), options: .atomic)
        try salvaVerbale(trascrizione, in: cartella)
    }

    static func caricaTrascrizione(da cartella: URL) -> Trascrizione? {
        guard let dati = try? Data(contentsOf: cartella.appendingPathComponent(nomeTrascrizione)) else {
            return nil
        }
        return try? JSONDecoder().decode(Trascrizione.self, from: dati)
    }

    static func salvaVerbale(_ trascrizione: Trascrizione, in cartella: URL) throws {
        let info = try? FileManager.default.attributesOfItem(atPath: cartella.path)
        let data = info?[.creationDate] as? Date ?? Date()
        let markdown = VerbaleMarkdown.esporta(
            trascrizione, titolo: cartella.lastPathComponent, data: data
        )
        try markdown.data(using: .utf8)!
            .write(to: cartella.appendingPathComponent(nomeVerbale), options: .atomic)
    }

    /// Le riunioni valide (cartelle con riunione.m4a), dalla più recente.
    static func elenca(in base: URL) -> [Riunione] {
        let contenuto = (try? FileManager.default.contentsOfDirectory(
            at: base, includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey]
        )) ?? []
        return contenuto.compactMap { cartella -> Riunione? in
            let audio = cartella.appendingPathComponent(nomeAudio)
            guard FileManager.default.fileExists(atPath: audio.path) else { return nil }
            let attributi = try? FileManager.default.attributesOfItem(atPath: cartella.path)
            return Riunione(
                cartella: cartella,
                nome: cartella.lastPathComponent,
                data: attributi?[.creationDate] as? Date ?? .distantPast,
                audioURL: audio,
                haTrascrizione: FileManager.default.fileExists(
                    atPath: cartella.appendingPathComponent(nomeTrascrizione).path
                )
            )
        }
        .sorted { $0.data > $1.data }
    }
}
```

- [ ] **Step 4: esegui i test e verifica che passino** — Expected: TEST SUCCEEDED.

- [ ] **Step 5: implementazione `MeetingRecorder.swift`**:

```swift
//
//  MeetingRecorder.swift
//  cattura riunione
//
//  Orchestra la registrazione di una riunione: microfono (AudioRecorder)
//  e audio di sistema (SystemAudioTap) partono insieme; allo stop i due
//  file si miscelano in riunione.m4a dentro una nuova cartella riunione.
//

import Foundation
import Observation

@MainActor
@Observable
final class MeetingRecorder {

    let microfono = AudioRecorder()
    private let sistema = SystemAudioTap()

    /// Preferenza dell'utente: catturare anche l'audio delle altre app.
    var catturaSistema: Bool = UserDefaults.standard.object(forKey: "catturaSistema") as? Bool ?? true {
        didSet { UserDefaults.standard.set(catturaSistema, forKey: "catturaSistema") }
    }
    /// Avviso non bloccante (es. permesso di sistema negato).
    private(set) var avvisoSistema: String?
    private(set) var staMiscelando = false

    private var urlSistema: URL?

    var isRecording: Bool { microfono.isRecording }

    func avvia() async {
        avvisoSistema = nil
        urlSistema = nil
        guard await microfono.startRecording() else { return }
        if catturaSistema {
            do {
                urlSistema = try sistema.avvia()
            } catch {
                // Senza permesso o senza supporto si prosegue col solo
                // microfono: la riunione non va persa per questo.
                avvisoSistema = "Audio di sistema non catturato: \(error.localizedDescription)"
            }
        }
    }

    /// Ferma tutto, miscela e scrive riunione.m4a in una nuova cartella
    /// dentro `cartellaBase`. Restituisce la cartella della riunione.
    func ferma(in cartellaBase: URL) async -> URL? {
        sistema.ferma()
        guard let urlMicrofono = microfono.stopRecording() else { return nil }
        let urlSistema = self.urlSistema
        self.urlSistema = nil

        staMiscelando = true
        defer { staMiscelando = false }

        do {
            let cartella = try MeetingStore.creaCartella(in: cartellaBase, data: Date())
            let destinazione = cartella.appendingPathComponent(MeetingStore.nomeAudio)
            try await Task.detached(priority: .userInitiated) {
                var mix = try AudioCampioni.carica(urlMicrofono, frequenza: 48000)
                if let urlSistema,
                   let campioniSistema = try? AudioCampioni.carica(urlSistema, frequenza: 48000) {
                    mix = AudioCampioni.miscela(mix, campioniSistema)
                }
                try AudioCampioni.scriviM4A(mix, frequenza: 48000, in: destinazione)
            }.value
            pulisci(urlMicrofono, urlSistema)
            return cartella
        } catch {
            pulisci(urlMicrofono, urlSistema)
            microfono.errorMessage = "Impossibile salvare la riunione: \(error.localizedDescription)"
            return nil
        }
    }

    private nonisolated func pulisci(_ urls: URL?...) {
        for url in urls.compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
```

- [ ] **Step 6: compila ed esegui i test** — Expected: BUILD SUCCEEDED, TEST SUCCEEDED.

- [ ] **Step 7: Commit** — `git add -A && git commit -m "Cartelle riunione e orchestrazione della registrazione doppia"`

---

### Task 9: `ModelStore` e `TranscriptionEngine` (FluidAudio)

**Files:**
- Create: `cattura riunione/ModelStore.swift`
- Create: `cattura riunione/TranscriptionEngine.swift`

**Interfaces:**
- Consumes: `AudioCampioni.carica(_:frequenza:)` (Task 6), `TurniParlato.consolida` (Task 3), `Trascrizione`/`Intervento` (Task 2).
- Produces:
  - `@MainActor @Observable final class ModelStore { enum Stato: Equatable { case daScaricare, inScaricamento(String), pronti, errore(String) }; private(set) var stato: Stato; func prepara() async }` — al termine con successo `stato == .pronti` e i gestori FluidAudio inizializzati restano in memoria.
  - `@MainActor @Observable final class TranscriptionEngine { enum Fase: Equatable { case inattivo, decodifica, diarizzazione, trascrizione(Double), completato, errore(String) }; private(set) var fase: Fase; func trascrivi(audio: URL) async -> Trascrizione? }`

- [ ] **Step 1: verifica l'API reale di FluidAudio.** Il pacchetto è già risolto (Task 1). Leggi:
  - `build/SourcePackages/checkouts/FluidAudio/README.md`
  - i sorgenti in `build/SourcePackages/checkouts/FluidAudio/Sources/FluidAudio/` (in particolare le cartelle ASR e Diarizer)

  Cerca i tipi equivalenti a: scaricamento/caricamento modelli ASR (`AsrModels.downloadAndLoad()` o simile), gestore ASR (`AsrManager`, `transcribe(_ campioni: [Float])`), scaricamento modelli di diarizzazione (`DiarizerModels.downloadIfNeeded()` o simile), gestore diarizzazione (`DiarizerManager`, `performCompleteDiarization(_ campioni: [Float], sampleRate: 16000)` con segmenti dotati di id parlante, inizio e fine in secondi). Annota i nomi REALI e usali nei passi seguenti al posto di quelli indicativi.

- [ ] **Step 2: implementazione `ModelStore.swift`** (adatta i nomi all'API verificata):

```swift
//
//  ModelStore.swift
//  cattura riunione
//
//  Stato dei modelli Core ML di FluidAudio: al primo avvio vanno
//  scaricati da Hugging Face (~1 GB), poi restano in locale e l'app
//  funziona offline. I gestori inizializzati vivono qui e vengono
//  riusati per tutte le trascrizioni della sessione.
//

import FluidAudio
import Foundation
import Observation

@MainActor
@Observable
final class ModelStore {

    enum Stato: Equatable {
        case daScaricare
        case inScaricamento(String)
        case pronti
        case errore(String)
    }

    private(set) var stato: Stato = .daScaricare
    private(set) var asr: AsrManager?
    private(set) var diarizzatore: DiarizerManager?

    /// Scarica (se serve) e inizializza i modelli. Riprovabile: in caso
    /// di errore lo stato torna interrogabile e si può richiamare.
    func prepara() async {
        guard stato != .pronti, asr == nil || diarizzatore == nil else { return }
        do {
            stato = .inScaricamento("Modelli di trascrizione…")
            let modelliAsr = try await AsrModels.downloadAndLoad()
            let asr = AsrManager(config: .default)
            try await asr.initialize(models: modelliAsr)

            stato = .inScaricamento("Modelli di diarizzazione…")
            let modelliDiar = try await DiarizerModels.downloadIfNeeded()
            let diarizzatore = DiarizerManager()
            diarizzatore.initialize(models: modelliDiar)

            self.asr = asr
            self.diarizzatore = diarizzatore
            stato = .pronti
        } catch {
            stato = .errore(
                "Scaricamento dei modelli non riuscito: \(error.localizedDescription) "
                + "Controlla la connessione e riprova."
            )
        }
    }
}
```

- [ ] **Step 3: implementazione `TranscriptionEngine.swift`** (adatta i nomi all'API verificata):

```swift
//
//  TranscriptionEngine.swift
//  cattura riunione
//
//  La post-elaborazione che produce il verbale: audio → 16 kHz mono →
//  diarizzazione → consolidamento dei turni → trascrizione ASR di ogni
//  turno ritagliato → Trascrizione.
//

import FluidAudio
import Foundation
import Observation

@MainActor
@Observable
final class TranscriptionEngine {

    enum Fase: Equatable {
        case inattivo
        case decodifica
        case diarizzazione
        /// Avanzamento 0…1 sulla trascrizione dei turni.
        case trascrizione(Double)
        case completato
        case errore(String)
    }

    private(set) var fase: Fase = .inattivo
    private let modelli: ModelStore

    init(modelli: ModelStore) {
        self.modelli = modelli
    }

    /// Trascrive il file audio e restituisce il verbale, o nil (con la
    /// fase a .errore) se qualcosa va storto.
    func trascrivi(audio url: URL) async -> Trascrizione? {
        guard let asr = modelli.asr, let diarizzatore = modelli.diarizzatore else {
            fase = .errore("I modelli non sono pronti: scaricali dalle Impostazioni.")
            return nil
        }

        do {
            fase = .decodifica
            let campioni = try await Task.detached(priority: .userInitiated) {
                try AudioCampioni.carica(url, frequenza: 16000)
            }.value
            let durata = Double(campioni.count) / 16000

            fase = .diarizzazione
            let risultato = try diarizzatore.performCompleteDiarization(campioni, sampleRate: 16000)
            let turni = TurniParlato.consolida(risultato.segments.map {
                TurnoParlato(
                    idParlante: $0.speakerId,
                    inizio: Double($0.startTimeSeconds),
                    fine: Double($0.endTimeSeconds)
                )
            })

            var interventi: [Intervento] = []
            for (indice, turno) in turni.enumerated() {
                fase = .trascrizione(Double(indice) / Double(max(1, turni.count)))
                let da = max(0, Int(turno.inizio * 16000))
                let a = min(campioni.count, Int(turno.fine * 16000))
                guard a > da else { continue }
                let ritaglio = Array(campioni[da..<a])
                let esito = try await asr.transcribe(ritaglio)
                let testo = esito.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !testo.isEmpty else { continue }
                interventi.append(Intervento(
                    id: UUID(), idParlante: turno.idParlante,
                    inizio: turno.inizio, fine: turno.fine, testo: testo
                ))
            }

            let trascrizione = Trascrizione(
                versione: 1,
                durata: durata,
                interventi: interventi,
                nomiParlanti: Trascrizione.etichette(perOrdineDiComparsa: interventi)
            )
            fase = .completato
            return trascrizione
        } catch {
            fase = .errore("Trascrizione non riuscita: \(error.localizedDescription)")
            return nil
        }
    }
}
```

- [ ] **Step 4: compila ed esegui i test** — Expected: BUILD SUCCEEDED, TEST SUCCEEDED. Gli errori di compilazione qui indicano quasi sempre nomi d'API diversi: torna allo Step 1 e allinea.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "Pipeline di trascrizione con diarizzazione via FluidAudio"`

---

### Task 10: Finestra principale (registrazione, elenco, importazione)

**Files:**
- Modify: `cattura riunione/ContentView.swift` (sostituzione completa del provvisorio)

**Interfaces:**
- Consumes: `MeetingRecorder`, `MeetingStore`, `ModelStore`, `TranscriptionEngine`, `OutputFolderStore`, `FormattaTempo`.
- Produces: `struct ContentView: View`; naviga alla `VerbaleView(cartella:)` (Task 11 — per ora un segnaposto compilabile va creato qui e sostituito nel Task 11).

- [ ] **Step 1: implementazione.** Sostituisci `ContentView.swift` con:

```swift
//
//  ContentView.swift
//  cattura riunione
//
//  La finestra principale: a sinistra registrazione e importazione,
//  a destra l'elenco delle riunioni; la selezione apre il verbale.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    @State private var registratore = MeetingRecorder()
    @State private var modelli = ModelStore()
    @State private var motore: TranscriptionEngine?
    @State private var cartelle = OutputFolderStore()
    @State private var riunioni: [Riunione] = []
    @State private var selezione: URL?
    @State private var cartellaInElaborazione: URL?

    var body: some View {
        NavigationSplitView {
            barraLaterale
                .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        } detail: {
            if let selezione {
                VerbaleView(cartella: selezione)
                    .id(selezione)
            } else {
                Text("Seleziona una riunione o avviane una nuova.")
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            aggiornaElenco()
            await modelli.prepara()
        }
        .onChange(of: modelli.stato) {
            if motore == nil, modelli.stato == .pronti {
                motore = TranscriptionEngine(modelli: modelli)
            }
        }
    }

    private var barraLaterale: some View {
        VStack(alignment: .leading, spacing: 12) {
            pannelloRegistrazione
            Divider()
            pannelloStato
            List(riunioni, selection: $selezione) { riunione in
                VStack(alignment: .leading) {
                    Text(riunione.nome)
                    if !riunione.haTrascrizione {
                        Text("Da trascrivere").font(.caption).foregroundStyle(.orange)
                    }
                }
                .tag(riunione.cartella)
            }
            .onDrop(of: [UTType.audio], isTargeted: nil) { fornitori in
                importa(fornitori)
            }
        }
        .padding(.top, 8)
    }

    private var pannelloRegistrazione: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Ingresso", selection: $registratore.microfono.selectedDeviceID) {
                ForEach(registratore.microfono.devices) { dispositivo in
                    Text(dispositivo.name).tag(Optional(dispositivo.id))
                }
            }
            .onChange(of: registratore.microfono.selectedDeviceID) {
                registratore.microfono.noteDeviceChanged()
            }

            Toggle("Registra anche l'audio di sistema (call)", isOn: $registratore.catturaSistema)
                .disabled(registratore.isRecording)

            HStack {
                if registratore.isRecording {
                    Button {
                        Task { await fermaRegistrazione() }
                    } label: {
                        Label("Ferma", systemImage: "stop.circle.fill")
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    Text(FormattaTempo.hhmmss(registratore.microfono.elapsed))
                        .monospacedDigit()
                } else {
                    Button {
                        Task { await registratore.avvia() }
                    } label: {
                        Label("Registra", systemImage: "record.circle")
                    }
                    .disabled(registratore.staMiscelando || cartellaInElaborazione != nil)
                }
            }

            MisuratoreLivello(livelli: registratore.microfono.levels)

            if let avviso = registratore.avvisoSistema {
                Text(avviso).font(.caption).foregroundStyle(.orange)
            }
            if let errore = registratore.microfono.errorMessage {
                Text(errore).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var pannelloStato: some View {
        switch modelli.stato {
        case .daScaricare, .pronti:
            EmptyView()
        case .inScaricamento(let cosa):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Scaricamento: \(cosa)").font(.caption)
            }
            .padding(.horizontal, 12)
        case .errore(let messaggio):
            VStack(alignment: .leading, spacing: 4) {
                Text(messaggio).font(.caption).foregroundStyle(.red)
                Button("Riprova") { Task { await modelli.prepara() } }
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
        }
        if let motore, cartellaInElaborazione != nil {
            statoElaborazione(motore.fase)
                .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func statoElaborazione(_ fase: TranscriptionEngine.Fase) -> some View {
        switch fase {
        case .inattivo, .completato:
            EmptyView()
        case .decodifica:
            Label("Preparazione dell'audio…", systemImage: "waveform").font(.caption)
        case .diarizzazione:
            Label("Riconoscimento dei parlanti…", systemImage: "person.2").font(.caption)
        case .trascrizione(let avanzamento):
            ProgressView(value: avanzamento) { Text("Trascrizione…").font(.caption) }
        case .errore(let messaggio):
            Text(messaggio).font(.caption).foregroundStyle(.red)
        }
    }

    // MARK: Azioni

    private func aggiornaElenco() {
        guard let base = cartelle.currentFolder else { return }
        riunioni = MeetingStore.elenca(in: base)
    }

    private func fermaRegistrazione() async {
        guard let base = cartelle.currentFolder else {
            registratore.microfono.errorMessage = "Scegli una cartella di destinazione nelle Impostazioni (⌘,)."
            return
        }
        guard let cartella = await registratore.ferma(in: base) else { return }
        aggiornaElenco()
        await trascrivi(cartella: cartella)
    }

    private func trascrivi(cartella: URL) async {
        guard let motore else { return }
        cartellaInElaborazione = cartella
        defer { cartellaInElaborazione = nil }
        let audio = cartella.appendingPathComponent(MeetingStore.nomeAudio)
        if let trascrizione = await motore.trascrivi(audio: audio) {
            try? MeetingStore.salva(trascrizione, in: cartella)
            aggiornaElenco()
            selezione = cartella
        }
    }

    private func importa(_ fornitori: [NSItemProvider]) -> Bool {
        guard let fornitore = fornitori.first else { return false }
        _ = fornitore.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                guard let base = cartelle.currentFolder else { return }
                do {
                    let cartella = try MeetingStore.creaCartella(in: base, data: Date())
                    let destinazione = cartella.appendingPathComponent(MeetingStore.nomeAudio)
                    // L'audio importato si riporta comunque a m4a 48 kHz,
                    // così la cartella riunione è uniforme.
                    try await Task.detached(priority: .userInitiated) {
                        let campioni = try AudioCampioni.carica(url, frequenza: 48000)
                        try AudioCampioni.scriviM4A(campioni, frequenza: 48000, in: destinazione)
                    }.value
                    aggiornaElenco()
                    await trascrivi(cartella: cartella)
                } catch {
                    registratore.microfono.errorMessage =
                        "Importazione non riuscita: \(error.localizedDescription)"
                }
            }
        }
        return true
    }
}

/// Barra del livello d'ingresso, un canale per riga.
struct MisuratoreLivello: View {
    let livelli: [Float]

    var body: some View {
        VStack(spacing: 2) {
            ForEach(livelli.indices, id: \.self) { indice in
                GeometryReader { geometria in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule()
                            .fill(livelli[indice] > 0.9 ? .red : .green)
                            .frame(width: geometria.size.width * CGFloat(livelli[indice]))
                    }
                }
                .frame(height: 6)
            }
        }
        .animation(.linear(duration: 0.05), value: livelli)
    }
}
```

- [ ] **Step 2: segnaposto `VerbaleView`** (sostituito nel Task 11) — crea `cattura riunione/VerbaleView.swift`:

```swift
//
//  VerbaleView.swift
//  cattura riunione
//
//  Segnaposto: il verbale vero arriva col task successivo.
//

import SwiftUI

struct VerbaleView: View {
    let cartella: URL
    var body: some View {
        Text(cartella.lastPathComponent)
    }
}
```

- [ ] **Step 3: compila ed esegui i test** — Expected: BUILD SUCCEEDED, TEST SUCCEEDED. Verifica anche i riferimenti reali di `OutputFolderStore` (proprietà `currentFolder`): se il nome differisce nel file copiato, allinea QUESTA vista al file copiato.

- [ ] **Step 4: avvio manuale di fumo** — `open "build/Build/Products/Debug/Cattura Riunione.app"`; la finestra deve aprirsi con picker dell'ingresso e pulsante Registra. Chiudi.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "Finestra principale: registrazione, elenco riunioni, importazione"`

---

### Task 11: Vista del verbale (rinomina, riascolto, esportazione)

**Files:**
- Modify: `cattura riunione/VerbaleView.swift` (sostituzione completa del segnaposto)

**Interfaces:**
- Consumes: `MeetingStore` (caricaTrascrizione/salva), `Trascrizione`, `FormattaTempo`.

- [ ] **Step 1: implementazione** — sostituisci `VerbaleView.swift`:

```swift
//
//  VerbaleView.swift
//  cattura riunione
//
//  Il verbale della riunione: interventi attribuiti, rinomina dei
//  parlanti (doppio clic sul nome), riascolto sincronizzato (clic su un
//  intervento), esportazione e copia.
//

import AVFoundation
import SwiftUI

struct VerbaleView: View {

    let cartella: URL

    @State private var trascrizione: Trascrizione?
    @State private var lettore: AVAudioPlayer?
    @State private var inRiproduzione = false
    @State private var posizione: TimeInterval = 0
    @State private var orologio: Timer?
    @State private var parlanteInRinomina: String?
    @State private var nuovoNome = ""

    var body: some View {
        Group {
            if let trascrizione {
                verbale(trascrizione)
            } else {
                Text("Questa riunione non è ancora stata trascritta.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(cartella.lastPathComponent)
        .onAppear(perform: carica)
        .onDisappear(perform: fermaRiproduzione)
    }

    private func verbale(_ t: Trascrizione) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(t.interventi) { intervento in
                    riga(intervento, in: t)
                }
            }
            .padding(16)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    inRiproduzione ? pausa() : riproduci(da: posizione)
                } label: {
                    Label(inRiproduzione ? "Pausa" : "Riproduci",
                          systemImage: inRiproduzione ? "pause.fill" : "play.fill")
                }
                Text(FormattaTempo.hhmmss(posizione)).monospacedDigit()
                Button("Copia") { copia(t) }
                Button("Esporta") { esporta(t) }
            }
        }
    }

    private func riga(_ intervento: Intervento, in t: Trascrizione) -> some View {
        let attivo = posizione >= intervento.inizio && posizione < intervento.fine
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if parlanteInRinomina == intervento.idParlante {
                    TextField("Nome", text: $nuovoNome)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .onSubmit { confermaRinomina(intervento.idParlante) }
                } else {
                    Text(t.nome(perParlante: intervento.idParlante))
                        .bold()
                        .onTapGesture(count: 2) {
                            nuovoNome = t.nomiParlanti[intervento.idParlante] ?? ""
                            parlanteInRinomina = intervento.idParlante
                        }
                }
                Text(FormattaTempo.hhmmss(intervento.inizio))
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Text(intervento.testo)
                .textSelection(.enabled)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(attivo ? Color.accentColor.opacity(0.12) : .clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { riproduci(da: intervento.inizio) }
    }

    // MARK: Dati

    private func carica() {
        trascrizione = MeetingStore.caricaTrascrizione(da: cartella)
    }

    private func confermaRinomina(_ id: String) {
        guard var t = trascrizione else { return }
        t.rinomina(parlante: id, in: nuovoNome)
        trascrizione = t
        parlanteInRinomina = nil
        try? MeetingStore.salva(t, in: cartella)
    }

    // MARK: Riproduzione

    private func riproduci(da secondi: TimeInterval) {
        if lettore == nil {
            lettore = try? AVAudioPlayer(
                contentsOf: cartella.appendingPathComponent(MeetingStore.nomeAudio)
            )
        }
        guard let lettore else { return }
        lettore.currentTime = secondi
        lettore.play()
        inRiproduzione = true
        orologio?.invalidate()
        orologio = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            Task { @MainActor in
                posizione = lettore.currentTime
                if !lettore.isPlaying { inRiproduzione = false }
            }
        }
    }

    private func pausa() {
        lettore?.pause()
        inRiproduzione = false
    }

    private func fermaRiproduzione() {
        orologio?.invalidate()
        orologio = nil
        lettore?.stop()
        lettore = nil
        inRiproduzione = false
    }

    // MARK: Esportazione

    private func copia(_ t: Trascrizione) {
        let testo = VerbaleMarkdown.esporta(t, titolo: cartella.lastPathComponent, data: Date())
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(testo, forType: .string)
    }

    private func esporta(_ t: Trascrizione) {
        try? MeetingStore.salvaVerbale(t, in: cartella)
        NSWorkspace.shared.activateFileViewerSelecting(
            [cartella.appendingPathComponent(MeetingStore.nomeVerbale)]
        )
    }
}
```

- [ ] **Step 2: compila ed esegui i test** — Expected: BUILD SUCCEEDED, TEST SUCCEEDED.

- [ ] **Step 3: Commit** — `git add -A && git commit -m "Vista del verbale: rinomina, riascolto sincronizzato, esportazione"`

---

### Task 12: Impostazioni (⌘,)

**Files:**
- Create: `cattura riunione/SettingsView.swift`
- Modify: `cattura riunione/cattura_riunioneApp.swift`

**Interfaces:**
- Consumes: `OutputFolderStore` (usa i nomi reali del file copiato nel Task 5: la vista Impostazioni di cattura brano è il riferimento per la scelta cartella con NSOpenPanel).

- [ ] **Step 1: implementazione `SettingsView.swift`** (segui il pattern di `/Users/emi/workspace/cattura brano/cattura brano/SettingsView.swift` per la scelta della cartella; qui la versione ridotta):

```swift
//
//  SettingsView.swift
//  cattura riunione
//
//  Impostazioni (⌘,): cartella di destinazione delle riunioni e
//  preferenza sulla cattura dell'audio di sistema.
//

import AppKit
import SwiftUI

struct SettingsView: View {

    @State private var cartelle = OutputFolderStore()
    @AppStorage("catturaSistema") private var catturaSistema = true

    var body: some View {
        Form {
            Section("Destinazione") {
                HStack {
                    Text(cartelle.currentFolder?.path(percentEncoded: false) ?? "Nessuna cartella scelta")
                        .truncationMode(.middle)
                        .lineLimit(1)
                    Spacer()
                    Button("Scegli…") { scegliCartella() }
                }
            }
            Section("Registrazione") {
                Toggle("Cattura l'audio di sistema (call)", isOn: $catturaSistema)
                Text("Alla prima registrazione macOS chiede il permesso di registrare l'audio di sistema.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding()
    }

    private func scegliCartella() {
        let pannello = NSOpenPanel()
        pannello.canChooseDirectories = true
        pannello.canChooseFiles = false
        pannello.allowsMultipleSelection = false
        pannello.prompt = "Scegli"
        if pannello.runModal() == .OK, let url = pannello.url {
            cartelle.setFolder(url)
        }
    }
}
```

NOTA: `currentFolder` e `setFolder` sono indicativi — usa i membri REALI di `OutputFolderStore` copiato nel Task 5 (leggilo prima di scrivere questa vista) e, se differiscono, allinea anche `ContentView` del Task 10.

- [ ] **Step 2: aggiungi la scena Settings** in `cattura_riunioneApp.swift`:

```swift
        Settings {
            SettingsView()
        }
```

(dentro `var body: some Scene`, dopo il `WindowGroup`).

- [ ] **Step 3: compila ed esegui i test** — Expected: BUILD SUCCEEDED, TEST SUCCEEDED.

- [ ] **Step 4: Commit** — `git add -A && git commit -m "Impostazioni: cartella di destinazione e cattura di sistema"`

---

### Task 13: Prova reale guidata e chiusura

**Files:**
- Create: `README.md`

- [ ] **Step 1: build Release** — Run: comando di build con `-configuration Release`. Expected: BUILD SUCCEEDED.

- [ ] **Step 2: prova reale guidata.** Avvia l'app Debug e accompagna l'utente in questa sequenza (serve la sua presenza: permessi e voce):
  1. Primo avvio: parte lo scaricamento dei modelli; a fine scaricamento lo stato sparisce.
  2. Impostazioni (⌘,): scegli la cartella di destinazione.
  3. Registra 30–60 s parlando con due voci diverse (o due persone); nel frattempo fai riprodurre un parlato dal Mac (es. `say "Questa è la voce di sistema"` ripetuto, o un video): al primo avvio compare la richiesta di permesso per l'audio di sistema → concedi.
  4. Ferma: la trascrizione parte da sola; a fine elaborazione si apre il verbale.
  5. Verifica: interventi divisi per parlante, voce di sistema inclusa; doppio clic su un nome → rinomina; clic su un intervento → il riascolto parte da lì; Esporta → il Finder mostra `verbale.md`.
  6. Trascina nell'elenco un file audio esistente (es. un m4a di Vocal Memos): viene importato e trascritto.
  7. Nega il permesso audio di sistema (Impostazioni di Sistema › Privacy) e registra di nuovo: l'app avvisa ma registra dal microfono.

  Se un passaggio fallisce: NON proseguire con la checklist; apri un'indagine col processo di debug sistematico, correggi, ricomincia la prova dal passaggio fallito.

- [ ] **Step 3: `README.md`**:

```markdown
# Cattura Riunione

App macOS (15+, Apple Silicon) che registra riunioni — microfono e, per
le call, audio di sistema — e produce il verbale con trascrizione e
divisione dei parlanti. Tutto avviene in locale: dopo il primo
scaricamento dei modelli (~1 GB da Hugging Face) non serve la rete.

## Come funziona

1. **Registra**: microfono + (opzionale) audio di sistema via process
   tap di Core Audio. Allo stop le due tracce vengono miscelate in
   `riunione.m4a`.
2. **Trascrive**: diarizzazione (chi parla e quando) e trascrizione
   (Parakeet TDT v3, italiano incluso) con FluidAudio/Core ML, sul
   Neural Engine.
3. **Verbale**: interventi per parlante con orari; rinomina dei
   parlanti, riascolto sincronizzato, esportazione Markdown.

Ogni riunione è una cartella `Riunione AAAA-MM-GG HH.mm` nella cartella
di destinazione, con `riunione.m4a`, `trascrizione.json`, `verbale.md`.

## Sviluppo

Progetto Xcode standard: `cattura riunione.xcodeproj`, schema
«Cattura Riunione». Test: `xcodebuild … test`. Le convenzioni del
progetto sono in `CLAUDE.md`; specifica e piano in `docs/superpowers/`.
```

- [ ] **Step 4: Commit finale** — `git add -A && git commit -m "README e prova reale guidata completata"`

---

## Autoverifica del piano (eseguita)

- Copertura della specifica: registrazione mic (T5), audio di sistema (T7), importazione (T10), trascrizione post con diarizzazione (T9), verbale con rinomina/riascolto/esportazione (T11), riapertura riunioni (T10), offline dopo primo scaricamento (T9), permessi e degradazioni (T5/T7/T8/T10), formato cartella riunione (T8), test logica pura (T2/T3/T4/T6/T8), prova reale (T13).
- I nomi d'API FluidAudio nel Task 9 sono INDICATIVI per esplicita decisione: lo Step 1 del task impone la verifica sull'albero sorgente reale del pacchetto. Lo stesso vale per i membri di `OutputFolderStore` (file copiato, non riscritto) nei Task 10 e 12.
- Tipi coerenti tra i task: `Intervento`/`Trascrizione` (T2) usati da T4/T8/T9/T11; `TurnoParlato` (T3) usato da T9; `AudioCampioni` (T6) usato da T8/T9/T10; `MeetingStore` (T8) usato da T10/T11.
```
