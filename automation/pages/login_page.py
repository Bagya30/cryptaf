from automation.pages.base_page import BasePage

class LoginPage(BasePage):
    def navigate(self):
        self.open("")

    def is_loaded(self):
        return True
