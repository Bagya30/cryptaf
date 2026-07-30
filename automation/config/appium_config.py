import os

class AppiumConfig:
    PLATFORM_NAME = "Android"
    AUTOMATION_NAME = "UiAutomator2"
    DEVICE_NAME = os.getenv("DEVICE_NAME", "Android Emulator")
    APP_PACKAGE = "com.cryptaf.vault"
    APP_ACTIVITY = "com.cryptaf.vault.MainActivity"
    APP_PATH = os.getenv("APK_PATH", "build/app/outputs/flutter-apk/app-debug.apk")
    APPIUM_SERVER_URL = os.getenv("APPIUM_URL", "http://127.0.0.1:4723/wd/hub")
    IMPLICIT_WAIT = 15
