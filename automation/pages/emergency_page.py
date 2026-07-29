from automation.pages.base_page import BasePage

class EmergencyPage(BasePage):
    def navigate(self, uid="DEMO_UID"):
        self.open(f"emergency.html?uid={uid}")
