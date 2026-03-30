const fs = require('fs');
const path = require('path');
const { test, expect } = require('@playwright/test');

const artifactRoot = path.join(__dirname, '..', 'TestResults', 'Artifacts');
const storageStatePath = process.env.M365_PLAYWRIGHT_STORAGE || path.join(artifactRoot, 'playwright-admin-storage-state.json');
const metadataPath = process.env.M365_PLAYWRIGHT_METADATA || path.join(artifactRoot, 'playwright-admin-metadata.json');
const outputPath = process.env.M365_BROWSER_CAPTURE_OUTPUT || path.join(artifactRoot, 'browser-agent-copilot-captures.json');

const metadata = fs.existsSync(metadataPath)
  ? JSON.parse(fs.readFileSync(metadataPath, 'utf8'))
  : {};

const tenantId = process.env.M365_TENANT_ID || metadata.TenantId;

if (!tenantId) {
  throw new Error(`M365_TENANT_ID was not provided and ${metadataPath} does not contain a tenant ID.`);
}

const now = new Date();
const windowStart = new Date(now.getTime() - (31 * 24 * 60 * 60 * 1000));
const encode = encodeURIComponent;
const defaultDlpPolicyFilter = encode("Identity eq 'Default DLP policy - Protect sensitive M365 Copilot interactions'");
const complianceRecommendationFilter = encode("PurviewAIScenario eq 'P4AIAdhocQuery14' and HostNames eq '' and SensitiveInfoTypes eq 'None'");

function getCapturePlan() {
  return {
    Agent: [
      {
        name: 'SharedSettings',
        path: '/fd/addins/api/v2/settings?keys=IsTenantEligibleForEntireOrgEmail,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AreMicrosoftCertified3PAppsAllowed,MetaOSCopilotExtensibilitySettings'
      },
      {
        name: 'RequestSettings',
        path: '/fd/addins/api/v2/settings?keys=MetaOSCopilotExtensibilitySettings,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AdminRoles,AllowOrgWideSharing'
      },
      {
        name: 'FrontierAccess',
        path: '/admin/api/settings/company/frontier/access'
      },
      {
        name: 'Templates',
        path: '/admin/api/agenttemplates/getagenttemplates'
      },
      {
        name: 'TemplatePolicies',
        path: '/admin/api/agenttemplates/getpolicies?expand=true'
      },
      {
        name: 'TemplateBillingAccounts',
        path: '/admin/api/tenant/billingAccountsWithShell'
      },
      {
        name: 'AutoQuotaEnabled',
        path: '/_api/SPOInternalUseOnly.TenantAdminSettings/AutoQuotaEnabled'
      },
      {
        name: 'CustomViewFilterDefaults',
        path: '/admin/api/tenant/customviewfilterdefaults'
      },
      {
        name: 'UserRoles',
        path: '/admin/api/users/getuserroles',
        method: 'POST',
        body: {}
      },
      {
        name: 'McpServers',
        path: '/admin/api/agentssettings/mcpservers'
      }
    ],
    Copilot: [
      {
        name: 'SettingsPage',
        path: '/admin/api/copilotsettings/settings'
      },
      {
        name: 'PinPolicy',
        path: '/admin/api/settings/company/copilotpolicy/pin'
      },
      {
        name: 'Recommendations',
        path: '/admin/api/recommendations/m365/ccs'
      },
      {
        name: 'Dismissed',
        path: '/admin/api/copilotsettings/settings/dismissed'
      },
      {
        name: 'SecurityCopilotAuth',
        path: '/admin/api/copilotsettings/securitycopilot/auth'
      },
      {
        name: 'AzureSubscriptions',
        path: '/admin/api/syntexbilling/azureSubscriptions'
      },
      {
        name: 'CopilotChatBillingPolicy',
        path: '/_api/v2.1/billingPolicies?feature=M365CopilotChat'
      },
      {
        name: 'AuditEnabled',
        path: '/fd/purview/apiproxy/adtsch/AuditEnabled'
      },
      {
        name: 'AIBaselineSummary',
        path: '/fd/purview/apiproxy/cpm/v1.0/Tenant/AIBaselineSummary',
        headers: {
          tenantid: tenantId,
          'x-tid': tenantId,
          'client-type': 'purview',
          'x-clientpage': '/',
          'client-version': '1.0.2774.1',
          'x-tabvisible': 'visible',
          'x-clientpkgversion': '',
          'client-request-id': '11111111-1111-4111-8111-111111111111'
        }
      },
      {
        name: 'PurviewForAISetting',
        path: `/fd/purview/apiproxy/di/find/PurviewForAISetting?tenantId=${encode(tenantId)}`
      },
      {
        name: 'DefaultDlpPolicy',
        path: `/fd/purview/apiproxy/di/find/DlpCompliancePolicy?tenantId=${encode(tenantId)}&filter=${defaultDlpPolicyFilter}`
      },
      {
        name: 'ComplianceRecommendation',
        path: `/fd/purview/apiproxy/di/find/PurviewForAI?tenantId=${encode(tenantId)}&filter=${complianceRecommendationFilter}&startTime=${encode(windowStart.toISOString())}&endTime=${encode(now.toISOString())}`
      }
    ]
  };
}

async function fetchCapture(page, request) {
  return page.evaluate(async (captureRequest) => {
    const headers = { ...(captureRequest.headers || {}) };
    const controller = new AbortController();
    const timeoutMs = captureRequest.timeoutMs || 15000;
    const timeoutHandle = setTimeout(() => controller.abort(), timeoutMs);
    const init = {
      method: captureRequest.method || 'GET',
      credentials: 'include',
      headers,
      signal: controller.signal
    };

    if (typeof captureRequest.body !== 'undefined') {
      init.body = typeof captureRequest.body === 'string'
        ? captureRequest.body
        : JSON.stringify(captureRequest.body);

      const hasContentType = Object.keys(headers).some((key) => key.toLowerCase() === 'content-type');
      if (!hasContentType) {
        init.headers['Content-Type'] = 'application/json';
      }
    }

    try {
      const response = await fetch(captureRequest.path, init);
      const bodyText = await response.text();

      return {
        status: response.status,
        ok: response.ok,
        url: response.url,
        contentType: response.headers.get('content-type'),
        bodyText,
        timedOut: false,
        errorMessage: null
      };
    }
    catch (error) {
      return {
        status: null,
        ok: false,
        url: captureRequest.path,
        contentType: null,
        bodyText: null,
        timedOut: error && error.name === 'AbortError',
        errorMessage: error ? String(error.message || error) : 'Unknown browser fetch error.'
      };
    }
    finally {
      clearTimeout(timeoutHandle);
    }
  }, request);
}

test.use({
  browserName: 'chromium',
  channel: 'msedge',
  storageState: storageStatePath,
  ignoreHTTPSErrors: true
});

test('captures Agent and Copilot browser responses', async ({ page }) => {
  test.setTimeout(300000);

  await page.goto('https://admin.cloud.microsoft/', {
    waitUntil: 'domcontentloaded',
    timeout: 120000
  });

  await page.waitForTimeout(5000);

  const title = await page.title();
  expect(title).not.toMatch(/sign in/i);

  const capturePlan = getCapturePlan();
  const results = {};

  for (const [sectionName, sectionRequests] of Object.entries(capturePlan)) {
    results[sectionName] = {};

    for (const request of sectionRequests) {
      console.log(`Capturing ${sectionName}/${request.name}`);
      const response = await fetchCapture(page, request);
      let body;

      try {
        body = response.bodyText === null ? null : JSON.parse(response.bodyText);
      }
      catch {
        body = response.bodyText;
      }

      results[sectionName][request.name] = {
        path: request.path,
        method: request.method || 'GET',
        status: response.status,
        ok: response.ok,
        timedOut: response.timedOut,
        errorMessage: response.errorMessage,
        url: response.url,
        contentType: response.contentType,
        body
      };
    }
  }

  const output = {
    capturedAt: new Date().toISOString(),
    tenantId,
    page: {
      url: page.url(),
      title
    },
    results
  };

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));
});