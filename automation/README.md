# 🚀 Enterprise Selenium E2E Automation Framework & CI/CD Pipeline

**Cryptaf Vault Application**  
**Target Live Deployment URL:** `https://bagya30.github.io/cryptaf/`

---

## 🏗️ Automation Architecture & Folder Structure

```
automation/
├── config/
│   └── config.py               # Environment configuration & BASE_URL
├── data/
│   └── test_data.json          # Test data fixtures
├── pages/
│   ├── base_page.py            # Page Object Model Base Class
│   ├── login_page.py           # Login Page Object
│   └── emergency_page.py       # Emergency Card Page Object
├── utils/
│   ├── logger.py               # Centralized logging engine
│   ├── screenshot.py           # Failure screenshot capturer
│   └── report_generator.py     # HTML & Excel report builder
└── tests/
    └── test_runner.py          # 420 E2E Test Suite Runner
```

---

## 🛠️ Repository Configuration & Required Settings

### 1. GitHub Pages Configuration
- **Source Branch:** `gh-pages` (Deployed automatically by `peaceiris/actions-gh-pages@v3`)
- **Folder:** `/` (root)
- **Custom Domain:** N/A (`https://bagya30.github.io/cryptaf/`)

### 2. GitHub Actions Permissions
Navigate to **Settings -> Actions -> General -> Workflow permissions**:
- Select **Read and write permissions**
- Check **Allow GitHub Actions to create and approve pull requests**

---

## 💻 Local Execution Guide

```bash
# 1. Install Python dependencies
pip install openpyxl requests

# 2. Set environment variables (Optional, defaults to LIVE GitHub Pages URL)
export BASE_URL="https://bagya30.github.io/cryptaf/"
export HEADLESS="true"

# 3. Run E2E Test Suite & Generate Reports
python build_selenium_framework_step2.py
```

Reports will be generated in `Test Results/`:
- `Test Results/Excel/Automation_Test_Report.xlsx`
- `Test Results/HTML/execution-report.html`
- `Test Results/Summary/summary.md`

---

## 🔧 Troubleshooting Guide

| Issue / Symptom | Possible Cause | Resolution |
| :--- | :--- | :--- |
| **HTTP 404 on BASE_URL** | GitHub Pages CDN propagation delay | Stage 6 in CI/CD waits 30 seconds for propagation before running tests. |
| **Selenium WebDriver Error** | Chrome version mismatch | CI/CD pipeline uses Headless mode with auto-configured Chrome environment. |
| **Missing Environment Secrets** | Repository secrets not populated | Verify `FIREBASE_*` and `MASTER_APP_KEY` secrets are populated in GitHub Repository Settings. |
