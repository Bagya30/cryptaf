import os

class Config:
    BASE_URL = os.getenv("BASE_URL", "https://bagya30.github.io/cryptaf/")
    HEADLESS = os.getenv("HEADLESS", "true").lower() == "true"
    IMPLICIT_WAIT = int(os.getenv("IMPLICIT_WAIT", "10"))
    PAGE_LOAD_TIMEOUT = int(os.getenv("PAGE_LOAD_TIMEOUT", "30"))
    SCREENSHOT_DIR = os.getenv("SCREENSHOT_DIR", "Test Results/Screenshots")
    LOG_DIR = os.getenv("LOG_DIR", "Test Results/Logs")
