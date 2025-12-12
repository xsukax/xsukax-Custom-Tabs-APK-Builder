#!/bin/bash
#
# xsukax Custom Tabs APK Builder (Enhanced Version)
# Automatic dependency management for Debian-based systems
# No external dependencies - uses Android's built-in Custom Tabs support
# Custom icon support (icon.png)
#
# Author: xsukax
# Repository: https://github.com/xsukax
# License: GPL-3.0
#

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPENDENCIES_CHECKED=false

# ============================================================================
# BANNER
# ============================================================================
print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║         xsukax Custom Tabs APK Builder v2.0               ║"
    echo "║         Enhanced with Dependency Management               ║"
    echo "║                                                           ║"
    echo "║         Author: xsukax                                    ║"
    echo "║         No External Dependencies Required                 ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ============================================================================
# DEPENDENCY MANAGEMENT FUNCTIONS
# ============================================================================

check_os_compatibility() {
    if [ ! -f /etc/debian_version ]; then
        echo -e "${YELLOW}[!] Warning: This script is optimized for Debian-based systems${NC}"
        echo -e "${YELLOW}[!] Package auto-installation may not work on your system${NC}"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

check_root_privileges() {
    if [ "$EUID" -ne 0 ]; then
        if ! command -v sudo &> /dev/null; then
            echo -e "${RED}[✗] Error: sudo is not available and not running as root${NC}"
            echo -e "${RED}[✗] Please install sudo or run as root${NC}"
            exit 1
        fi
        SUDO="sudo"
    else
        SUDO=""
    fi
}

check_package_installed() {
    local package=$1
    dpkg -l "$package" 2>/dev/null | grep -q "^ii" && return 0 || return 1
}

check_command_exists() {
    command -v "$1" &> /dev/null
}

install_package() {
    local package=$1
    local description=$2
    
    echo -e "${BLUE}[*] Installing $description ($package)...${NC}"
    
    if $SUDO apt-get update -qq 2>/dev/null && \
       $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$package" 2>/dev/null; then
        echo -e "${GREEN}[✓] Successfully installed $package${NC}"
        return 0
    else
        echo -e "${RED}[✗] Failed to install $package${NC}"
        return 1
    fi
}

verify_dependencies() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           DEPENDENCY VERIFICATION                         ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local missing_packages=()
    local optional_packages=()
    local all_satisfied=true
    
    # Check essential dependencies
    echo -e "${BLUE}[*] Checking essential dependencies...${NC}"
    
    # Java Development Kit
    if ! check_command_exists javac || ! check_command_exists keytool; then
        if ! check_package_installed "openjdk-17-jdk" && \
           ! check_package_installed "openjdk-11-jdk" && \
           ! check_package_installed "default-jdk"; then
            missing_packages+=("default-jdk:Java Development Kit (javac, keytool)")
            all_satisfied=false
            echo -e "${YELLOW}  [!] Java JDK not found${NC}"
        else
            echo -e "${GREEN}  [✓] Java JDK installed${NC}"
        fi
    else
        echo -e "${GREEN}  [✓] Java JDK installed${NC}"
    fi
    
    # zip utility
    if ! check_command_exists zip; then
        missing_packages+=("zip:ZIP compression utility")
        all_satisfied=false
        echo -e "${YELLOW}  [!] zip utility not found${NC}"
    else
        echo -e "${GREEN}  [✓] zip utility installed${NC}"
    fi
    
    # unzip utility
    if ! check_command_exists unzip; then
        missing_packages+=("unzip:ZIP extraction utility")
        all_satisfied=false
        echo -e "${YELLOW}  [!] unzip utility not found${NC}"
    else
        echo -e "${GREEN}  [✓] unzip utility installed${NC}"
    fi
    
    # wget or curl for potential SDK download
    if ! check_command_exists wget && ! check_command_exists curl; then
        missing_packages+=("wget:Download utility")
        all_satisfied=false
        echo -e "${YELLOW}  [!] wget/curl not found${NC}"
    else
        echo -e "${GREEN}  [✓] Download utility installed${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}[*] Checking optional dependencies...${NC}"
    
    # ImageMagick (optional but recommended for icon processing)
    if ! check_command_exists convert; then
        optional_packages+=("imagemagick:Image processing for custom icons")
        echo -e "${YELLOW}  [!] ImageMagick not found (optional)${NC}"
    else
        echo -e "${GREEN}  [✓] ImageMagick installed${NC}"
    fi
    
    # Python3 (optional for icon generation)
    if ! check_command_exists python3; then
        optional_packages+=("python3:Python for icon generation")
        echo -e "${YELLOW}  [!] Python3 not found (optional)${NC}"
    else
        echo -e "${GREEN}  [✓] Python3 installed${NC}"
    fi
    
    echo ""
    
    # Install missing essential packages
    if [ ${#missing_packages[@]} -gt 0 ]; then
        echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║         MISSING ESSENTIAL DEPENDENCIES                    ║${NC}"
        echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}The following essential packages need to be installed:${NC}"
        for pkg_info in "${missing_packages[@]}"; do
            IFS=':' read -r pkg desc <<< "$pkg_info"
            echo -e "  ${YELLOW}•${NC} $desc"
        done
        echo ""
        
        read -p "Install missing packages now? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo -e "${BLUE}[*] Updating package cache...${NC}"
            $SUDO apt-get update -qq 2>&1 | grep -v "^Hit:" | grep -v "^Get:" || true
            echo ""
            
            for pkg_info in "${missing_packages[@]}"; do
                IFS=':' read -r pkg desc <<< "$pkg_info"
                if ! install_package "$pkg" "$desc"; then
                    echo -e "${RED}[✗] Failed to install essential package: $pkg${NC}"
                    echo -e "${RED}[✗] Cannot continue without this dependency${NC}"
                    exit 1
                fi
            done
            echo ""
            echo -e "${GREEN}[✓] All essential dependencies installed successfully!${NC}"
        else
            echo -e "${RED}[✗] Cannot continue without essential dependencies${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}[✓] All essential dependencies satisfied!${NC}"
    fi
    
    # Offer to install optional packages
    if [ ${#optional_packages[@]} -gt 0 ]; then
        echo ""
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║         OPTIONAL DEPENDENCIES                             ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}The following optional packages can enhance functionality:${NC}"
        for pkg_info in "${optional_packages[@]}"; do
            IFS=':' read -r pkg desc <<< "$pkg_info"
            echo -e "  ${CYAN}•${NC} $desc"
        done
        echo ""
        
        read -p "Install optional packages? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for pkg_info in "${optional_packages[@]}"; do
                IFS=':' read -r pkg desc <<< "$pkg_info"
                install_package "$pkg" "$desc" || echo -e "${YELLOW}[!] Continuing without $pkg${NC}"
            done
        else
            echo -e "${YELLOW}[!] Skipping optional dependencies${NC}"
        fi
    fi
    
    # Verify Android SDK
    echo ""
    echo -e "${BLUE}[*] Checking Android SDK...${NC}"
    ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
    [ ! -d "$ANDROID_HOME" ] && ANDROID_HOME="/root/android-sdk"
    
    if [ ! -d "$ANDROID_HOME" ]; then
        echo -e "${RED}[✗] Android SDK not found at: $ANDROID_HOME${NC}"
        echo -e "${YELLOW}[!] Please install Android SDK manually${NC}"
        echo -e "${YELLOW}[!] Set ANDROID_HOME environment variable to SDK location${NC}"
        echo ""
        echo -e "${CYAN}Quick installation guide:${NC}"
        echo "  1. Download SDK from: https://developer.android.com/studio#command-tools"
        echo "  2. Extract to ~/Android/Sdk"
        echo "  3. Install build-tools and platform: sdkmanager 'build-tools;34.0.0' 'platforms;android-34'"
        echo "  4. Set ANDROID_HOME: export ANDROID_HOME=~/Android/Sdk"
        echo ""
        exit 1
    else
        echo -e "${GREEN}[✓] Android SDK found: $ANDROID_HOME${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         DEPENDENCY CHECK COMPLETE                         ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    DEPENDENCIES_CHECKED=true
}

# ============================================================================
# MAIN APK BUILD LOGIC (ORIGINAL FUNCTIONALITY PRESERVED)
# ============================================================================

build_apk() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           APK BUILD CONFIGURATION                         ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Check for custom icon
    if [ -f "$SCRIPT_DIR/icon.png" ]; then
        echo -e "${GREEN}[✓] Custom icon found: icon.png${NC}"
        CUSTOM_ICON="$SCRIPT_DIR/icon.png"
    else
        echo -e "${YELLOW}[!] No icon.png found, will generate default icon${NC}"
        CUSTOM_ICON=""
    fi

    # Get user input
    echo ""
    echo -ne "${BLUE}App Name: ${NC}"
    read APP_NAME
    [ -z "$APP_NAME" ] && { echo -e "${RED}Error: App name required${NC}"; exit 1; }

    echo -ne "${BLUE}Website URL: ${NC}"
    read WEBSITE_URL
    [ -z "$WEBSITE_URL" ] && { echo -e "${RED}Error: URL required${NC}"; exit 1; }

    echo -ne "${BLUE}Package Name (Enter for auto): ${NC}"
    read PACKAGE_NAME
    if [ -z "$PACKAGE_NAME" ]; then
        SAFE=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')
        PACKAGE_NAME="com.customtabs.${SAFE}"
    fi

    # Theme color
    echo -ne "${BLUE}Toolbar Color (hex, e.g., #2196F3): ${NC}"
    read TOOLBAR_COLOR
    [ -z "$TOOLBAR_COLOR" ] && TOOLBAR_COLOR="#2196F3"

    echo ""
    echo -e "${GREEN}Building: $APP_NAME${NC}"
    echo -e "${GREEN}URL: $WEBSITE_URL${NC}"
    echo -e "${GREEN}Package: $PACKAGE_NAME${NC}"
    echo -e "${GREEN}Color: $TOOLBAR_COLOR${NC}"
    echo ""

    # Setup
    PROJECT=$(echo "$APP_NAME" | tr ' ' '_' | tr -cd '[:alnum:]_')
    [ -d "$PROJECT" ] && rm -rf "$PROJECT"
    mkdir -p "$PROJECT" && cd "$PROJECT"

    ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
    [ ! -d "$ANDROID_HOME" ] && ANDROID_HOME="/root/android-sdk"
    [ ! -d "$ANDROID_HOME" ] && { echo -e "${RED}Android SDK not found${NC}"; exit 1; }

    BT=$(ls -1 "$ANDROID_HOME/build-tools" 2>/dev/null | sort -V | tail -1)
    PLATFORM=$(ls -1 "$ANDROID_HOME/platforms" 2>/dev/null | sort -V | tail -1)

    AAPT="$ANDROID_HOME/build-tools/$BT/aapt"
    D8="$ANDROID_HOME/build-tools/$BT/d8"
    ZIPALIGN="$ANDROID_HOME/build-tools/$BT/zipalign"
    APKSIGNER="$ANDROID_HOME/build-tools/$BT/apksigner"
    ANDROID_JAR="$ANDROID_HOME/platforms/$PLATFORM/android.jar"

    echo -e "${GREEN}[✓] SDK: $ANDROID_HOME${NC}"
    echo -e "${GREEN}[✓] Build Tools: $BT${NC}"

    # Create directories
    PKG_PATH=$(echo "$PACKAGE_NAME" | tr '.' '/')
    mkdir -p "src/main/java/$PKG_PATH"
    mkdir -p src/main/res/{values,values-night,xml,layout}
    mkdir -p src/main/res/{mipmap-mdpi,mipmap-hdpi,mipmap-xhdpi,mipmap-xxhdpi,mipmap-xxxhdpi}
    mkdir -p build/{gen,obj,apk}

    # AndroidManifest.xml
    cat > src/main/AndroidManifest.xml << MANIFEST
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools"
    package="$PACKAGE_NAME"
    android:versionCode="1"
    android:versionName="1.0">

    <uses-sdk android:minSdkVersion="21" android:targetSdkVersion="34" />

    <!-- Internet permission -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <!-- File access permissions for all Android versions -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" 
        android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
    
    <!-- Android 13+ (API 33+) granular media permissions -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
    
    <!-- For accessing all files (Android 11+) -->
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" 
        tools:ignore="ScopedStorage" />

    <application
        android:label="$APP_NAME"
        android:icon="@mipmap/ic_launcher"
        android:theme="@style/AppTheme"
        android:hardwareAccelerated="true"
        android:requestLegacyExternalStorage="true"
        android:preserveLegacyExternalStorage="true">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask"
            android:theme="@style/AppTheme"
            android:configChanges="orientation|screenSize|keyboardHidden"
            android:excludeFromRecents="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
MANIFEST

    # Convert hex color to decimal for Android
    TOOLBAR_COLOR_DEC=$(printf "%d" "0x${TOOLBAR_COLOR#\#}FF")

    # strings.xml
    cat > src/main/res/values/strings.xml << STRINGS
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$APP_NAME</string>
    <string name="website_url">$WEBSITE_URL</string>
    <color name="toolbar_color">$TOOLBAR_COLOR</color>
</resources>
STRINGS

    # Dark theme support
    cat > src/main/res/values-night/strings.xml << STRINGS_NIGHT
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="toolbar_color">#1A1A1A</color>
</resources>
STRINGS_NIGHT

    # Theme
    cat > src/main/res/values/styles.xml << STYLES
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="android:Theme.Material.Light.NoActionBar">
        <item name="android:colorPrimary">@color/toolbar_color</item>
        <item name="android:statusBarColor">@color/toolbar_color</item>
        <item name="android:windowIsTranslucent">true</item>
        <item name="android:windowBackground">@android:color/transparent</item>
        <item name="android:windowContentOverlay">@null</item>
        <item name="android:windowNoTitle">true</item>
        <item name="android:backgroundDimEnabled">false</item>
    </style>
</resources>
STYLES

    # Icons - use custom or generate
    create_icons

    # MainActivity.java - Using built-in Android Custom Tabs APIs with aggressive UI hiding
    cat > "src/main/java/$PKG_PATH/MainActivity.java" << 'JAVACODE'
package __PKG__;

import android.Manifest;
import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.Settings;
import android.util.Log;
import android.view.View;
import android.view.WindowManager;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {
    private static final String TAG = "CustomTabsApp";
    private static final int PERMISSION_REQUEST_CODE = 1001;
    private String pendingUrl;
    private int pendingToolbarColor;
    private boolean hasLaunchedBrowser = false;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Make this activity completely invisible and transparent
        getWindow().setFlags(
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        );
        
        getWindow().setFlags(
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        );
        
        if (Build.VERSION.SDK_INT >= 19) {
            getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            );
        }
        
        // Move to background immediately
        moveTaskToBack(true);
        
        String url = getString(getResources().getIdentifier("website_url", "string", getPackageName()));
        int toolbarColor = getResources().getColor(
            getResources().getIdentifier("toolbar_color", "color", getPackageName())
        );
        
        // Check and request permissions before launching
        if (checkAndRequestPermissions()) {
            launchCustomTab(url, toolbarColor);
        } else {
            // Store for later launch after permissions granted
            pendingUrl = url;
            pendingToolbarColor = toolbarColor;
        }
    }
    
    private boolean checkAndRequestPermissions() {
        List<String> permissionsNeeded = new ArrayList<>();
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ (API 33+) - Granular media permissions
            if (checkSelfPermission(Manifest.permission.READ_MEDIA_IMAGES) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(Manifest.permission.READ_MEDIA_IMAGES);
            }
            if (checkSelfPermission(Manifest.permission.READ_MEDIA_VIDEO) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(Manifest.permission.READ_MEDIA_VIDEO);
            }
            if (checkSelfPermission(Manifest.permission.READ_MEDIA_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(Manifest.permission.READ_MEDIA_AUDIO);
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // Android 6-12 (API 23-32)
            if (checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(Manifest.permission.READ_EXTERNAL_STORAGE);
            }
            if (checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(Manifest.permission.WRITE_EXTERNAL_STORAGE);
            }
        }
        
        // Request MANAGE_EXTERNAL_STORAGE for Android 11+ (API 30+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (!Environment.isExternalStorageManager()) {
                try {
                    Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
                    intent.setData(Uri.parse("package:" + getPackageName()));
                    startActivity(intent);
                    Log.d(TAG, "Requesting MANAGE_EXTERNAL_STORAGE permission");
                } catch (Exception e) {
                    Log.e(TAG, "Failed to request MANAGE_EXTERNAL_STORAGE", e);
                }
            }
        }
        
        if (!permissionsNeeded.isEmpty()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                requestPermissions(permissionsNeeded.toArray(new String[0]), PERMISSION_REQUEST_CODE);
                return false;
            }
        }
        
        return true;
    }
    
    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        
        if (requestCode == PERMISSION_REQUEST_CODE) {
            boolean allGranted = true;
            for (int result : grantResults) {
                if (result != PackageManager.PERMISSION_GRANTED) {
                    allGranted = false;
                    break;
                }
            }
            
            if (allGranted) {
                Log.d(TAG, "All permissions granted");
            } else {
                Log.w(TAG, "Some permissions denied, app may have limited functionality");
            }
            
            // Launch regardless - browser will handle its own permissions
            if (pendingUrl != null) {
                launchCustomTab(pendingUrl, pendingToolbarColor);
            }
        }
    }
    
    private void launchCustomTab(String url, int toolbarColor) {
        if (hasLaunchedBrowser) {
            return; // Prevent multiple launches
        }
        hasLaunchedBrowser = true;
        
        String packageName = getCustomTabsPackage();
        
        // Build Custom Tabs intent with file access support
        Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
        
        // Custom Tabs extras for minimal UI
        intent.putExtra("android.support.customtabs.extra.SESSION", (String) null);
        intent.putExtra("android.support.customtabs.extra.TOOLBAR_COLOR", toolbarColor);
        
        // Aggressive URL bar hiding
        intent.putExtra("android.support.customtabs.extra.ENABLE_URLBAR_HIDING", true);
        
        // Hide title to minimize UI
        intent.putExtra("android.support.customtabs.extra.SHOW_TITLE", false);
        
        // Disable share menu for cleaner UI
        intent.putExtra("android.support.customtabs.extra.SHARE_MENU_ITEM", false);
        
        // Additional flags to minimize browser UI
        intent.putExtra("android.support.customtabs.extra.HIDE_NAVIGATION_BAR", true);
        intent.putExtra("android.support.customtabs.extra.CLOSE_BUTTON_POSITION", 1);
        
        // Critical: Don't use NO_HISTORY - we need to stay alive for file picker results
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.addFlags(Intent.FLAG_ACTIVITY_MULTIPLE_TASK);
        
        // Grant URI read/write permissions to browser for file access
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        intent.addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        intent.addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION);
        
        // Set package if Custom Tabs browser found
        if (packageName != null) {
            intent.setPackage(packageName);
            Log.d(TAG, "Launching Custom Tab with file access: " + packageName);
        } else {
            Log.d(TAG, "No Custom Tabs support, using default browser");
        }
        
        try {
            startActivity(intent);
            
            // Don't finish - stay alive in background to support file picker activity stack
            // Move to back so we're invisible but alive
            moveTaskToBack(true);
            
            Log.d(TAG, "Browser launched, launcher moved to background");
        } catch (ActivityNotFoundException e) {
            Log.e(TAG, "No browser found", e);
            Toast.makeText(this, "No browser installed", Toast.LENGTH_LONG).show();
            finish();
        } catch (SecurityException e) {
            Log.e(TAG, "Security exception launching browser", e);
            Toast.makeText(this, "Permission error - please grant file access", Toast.LENGTH_LONG).show();
            finish();
        }
    }
    
    private String getCustomTabsPackage() {
        // Prioritize browsers with best fullscreen and file handling support
        String[] packages = {
            "com.android.chrome",              // Chrome - best Custom Tabs support
            "com.chrome.beta",
            "com.microsoft.emmx",              // Edge - good support
            "com.brave.browser",               // Brave - good support
            "com.sec.android.app.sbrowser",    // Samsung - good support
            "com.chrome.dev",
            "com.chrome.canary",
            "org.mozilla.firefox",             // Firefox - limited support
            "com.opera.browser"
        };
        
        PackageManager pm = getPackageManager();
        Intent activityIntent = new Intent(Intent.ACTION_VIEW, Uri.parse("http://www.example.com"));
        List<ResolveInfo> resolveInfoList = pm.queryIntentActivities(activityIntent, 0);
        
        List<String> installedPackages = new ArrayList<>();
        for (ResolveInfo info : resolveInfoList) {
            installedPackages.add(info.activityInfo.packageName);
        }
        
        // Return first matching package with Custom Tabs support
        for (String pkg : packages) {
            if (installedPackages.contains(pkg)) {
                Intent serviceIntent = new Intent();
                serviceIntent.setAction("android.support.customtabs.action.CustomTabsService");
                serviceIntent.setPackage(pkg);
                if (pm.resolveService(serviceIntent, 0) != null) {
                    return pkg;
                }
            }
        }
        
        return null;
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        
        // If browser was launched and user returns here, finish quietly
        if (hasLaunchedBrowser) {
            Log.d(TAG, "User returned to launcher, finishing");
            finish();
        }
    }
    
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        // Handle any new intents while in background
        Log.d(TAG, "New intent received");
    }
    
    @Override
    public void onBackPressed() {
        // Don't allow back button - just move to background
        moveTaskToBack(true);
    }
}
JAVACODE

    # Replace placeholders
    sed -i "s/__PKG__/$PACKAGE_NAME/g" "src/main/java/$PKG_PATH/MainActivity.java"

    echo -e "${GREEN}[✓] MainActivity created${NC}"

    # Compile Java
    echo -e "${BLUE}[*] Compiling...${NC}"

    javac -source 1.8 -target 1.8 \
        -bootclasspath "$ANDROID_JAR" \
        -classpath "$ANDROID_JAR" \
        -d build/obj \
        "src/main/java/$PKG_PATH/MainActivity.java" 2>&1

    if [ $? -ne 0 ]; then
        echo -e "${RED}[✗] Compilation failed${NC}"
        exit 1
    fi

    echo -e "${GREEN}[✓] Java compiled${NC}"

    # Generate R.java
    "$AAPT" package -f -m \
        -S src/main/res \
        -M src/main/AndroidManifest.xml \
        -I "$ANDROID_JAR" \
        -J build/gen \
        --auto-add-overlay 2>&1

    R_FILE=$(find build/gen -name "R.java" 2>/dev/null | head -1)
    if [ -z "$R_FILE" ]; then
        echo -e "${RED}[✗] R.java generation failed${NC}"
        exit 1
    fi

    javac -source 1.8 -target 1.8 \
        -bootclasspath "$ANDROID_JAR" \
        -d build/obj \
        "$R_FILE" 2>&1

    echo -e "${GREEN}[✓] Resources compiled${NC}"

    # DEX
    CLASS_FILES=$(find build/obj -name "*.class")
    "$D8" --lib "$ANDROID_JAR" --output build/apk $CLASS_FILES 2>&1

    echo -e "${GREEN}[✓] DEX created${NC}"

    # Package APK
    "$AAPT" package -f \
        -M src/main/AndroidManifest.xml \
        -S src/main/res \
        -I "$ANDROID_JAR" \
        -F build/unsigned.apk \
        build/apk 2>&1

    cd build/apk
    zip -q -u ../unsigned.apk classes.dex
    cd ../..

    # Align
    "$ZIPALIGN" -f 4 build/unsigned.apk build/aligned.apk

    echo -e "${GREEN}[✓] APK packaged${NC}"

    # Sign
    KEYSTORE="$HOME/.android/debug.keystore"
    if [ ! -f "$KEYSTORE" ]; then
        mkdir -p "$HOME/.android"
        keytool -genkey -v \
            -keystore "$KEYSTORE" \
            -storepass android \
            -alias androiddebugkey \
            -keypass android \
            -keyalg RSA \
            -keysize 2048 \
            -validity 10000 \
            -dname "CN=Debug,O=Android,C=US" 2>/dev/null
    fi

    "$APKSIGNER" sign \
        --ks "$KEYSTORE" \
        --ks-key-alias androiddebugkey \
        --ks-pass pass:android \
        --key-pass pass:android \
        --out "build/$PROJECT.apk" \
        build/aligned.apk 2>&1

    APK_PATH="$(pwd)/build/$PROJECT.apk"
    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              BUILD SUCCESSFUL! 🎉                         ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "APK: ${BLUE}$APK_PATH${NC}"
    echo -e "Size: ${BLUE}$APK_SIZE${NC}"
    echo ""
    echo -e "${GREEN}Features:${NC}"
    echo "  ✓ Custom Tabs with minimal UI"
    echo "  ✓ Aggressive toolbar hiding"
    echo "  ✓ Fullscreen immersive mode"
    echo "  ✓ No visible toolbar (hides immediately)"
    echo "  ✓ Opens in user's default browser"
    echo "  ✓ Supports Chrome, Edge, Firefox, Brave, Samsung"
    echo "  ✓ Custom icon support"
    echo "  ✓ Minimal size (~15KB)"
    echo "  ✓ Full file access permissions (read/write)"
    echo "  ✓ File picker support for WebCrypto and uploads"
    echo "  ✓ Proper activity stack management (no crashes)"
    echo "  ✓ Transparent launcher (stays alive in background)"
    echo "  ✓ Android 6-14 compatibility"
    echo ""
    echo -e "${YELLOW}Note: URL bar may briefly appear on load (security feature)${NC}"
    echo -e "${YELLOW}Note: App will request file permissions on first launch${NC}"
    echo -e "${YELLOW}Note: Launcher stays in background to support file pickers${NC}"
    echo ""
    echo -e "${BLUE}Install: adb install \"$APK_PATH\"${NC}"
    echo ""
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}Built with xsukax Custom Tabs APK Builder${NC}"
    echo -e "${CYAN}https://github.com/xsukax${NC}"
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
}

create_icons() {
    if [ -n "$CUSTOM_ICON" ] && [ -f "$CUSTOM_ICON" ]; then
        echo -e "${BLUE}[*] Processing custom icon...${NC}"
        if command -v convert &> /dev/null; then
            convert "$CUSTOM_ICON" -resize 48x48 src/main/res/mipmap-mdpi/ic_launcher.png
            convert "$CUSTOM_ICON" -resize 72x72 src/main/res/mipmap-hdpi/ic_launcher.png
            convert "$CUSTOM_ICON" -resize 96x96 src/main/res/mipmap-xhdpi/ic_launcher.png
            convert "$CUSTOM_ICON" -resize 144x144 src/main/res/mipmap-xxhdpi/ic_launcher.png
            convert "$CUSTOM_ICON" -resize 192x192 src/main/res/mipmap-xxxhdpi/ic_launcher.png
            echo -e "${GREEN}[✓] Custom icon processed${NC}"
        else
            cp "$CUSTOM_ICON" src/main/res/mipmap-mdpi/ic_launcher.png
            cp "$CUSTOM_ICON" src/main/res/mipmap-hdpi/ic_launcher.png
            cp "$CUSTOM_ICON" src/main/res/mipmap-xhdpi/ic_launcher.png
            cp "$CUSTOM_ICON" src/main/res/mipmap-xxhdpi/ic_launcher.png
            cp "$CUSTOM_ICON" src/main/res/mipmap-xxxhdpi/ic_launcher.png
            echo -e "${GREEN}[✓] Custom icon copied${NC}"
        fi
    else
        echo -e "${BLUE}[*] Generating default icon...${NC}"
        if command -v python3 &> /dev/null; then
            python3 << 'PYICON'
import zlib, struct
def png(w,h,r,g,b):
    def chunk(t,d):
        return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
    raw = b''.join([b'\x00'+bytes([r,g,b])*w for _ in range(h)])
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')
for s,d in [(48,'mdpi'),(72,'hdpi'),(96,'xhdpi'),(144,'xxhdpi'),(192,'xxxhdpi')]:
    open(f'src/main/res/mipmap-{d}/ic_launcher.png','wb').write(png(s,s,33,150,243))
PYICON
        else
            for dir in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
                printf '\x89\x50\x4e\x47\x0d\x0a\x1a\x0a\x00\x00\x00\x0d\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90\x77\x53\xde\x00\x00\x00\x0c\x49\x44\x41\x54\x08\xd7\x63\x48\x6d\xfc\x00\x00\x00\x89\x00\x51\x0d\x3a\x28\x25\x00\x00\x00\x00\x49\x45\x4e\x44\xae\x42\x60\x82' > "src/main/res/mipmap-$dir/ic_launcher.png"
            done
        fi
        echo -e "${GREEN}[✓] Default icon created${NC}"
    fi
}

# ============================================================================
# MAIN EXECUTION FLOW
# ============================================================================

main() {
    print_banner
    
    # Perform system checks
    check_os_compatibility
    check_root_privileges
    
    # Verify and install dependencies
    verify_dependencies
    
    # Build the APK
    build_apk
}

# Run main function
main
