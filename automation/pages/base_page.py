from automation.config.config import Config
from automation.utils.logger import get_logger

class BasePage:
    def __init__(self, driver):
        self.driver = driver
        self.logger = get_logger("BasePage")
        self.base_url = Config.BASE_URL

    def open(self, path=""):
        target_url = self.base_url.rstrip("/") + "/" + path.lstrip("/")
        self.logger.info(f"Navigating to LIVE URL: {target_url}")
        if self.driver:
            self.driver.get(target_url)

    def get_title(self):
        return self.driver.title if self.driver else "Cryptaf Vault"
