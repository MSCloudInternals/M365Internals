const fs = require('fs');
const path = require('path');
const { test, expect } = require('@playwright/test');

const artifactRoot = path.join(__dirname, '..', 'TestResults', 'Artifacts');
const storageStatePath = process.env.M365_PLAYWRIGHT_STORAGE || path.join(artifactRoot, 'playwright-admin-storage-state.json');
const metadataPath = process.env.M365_PLAYWRIGHT_METADATA || path.join(artifactRoot, 'playwright-admin-metadata.json');
const outputPath = process.env.M365_BROWSER_CAPTURE_OUTPUT || path.join(artifactRoot, 'browser-agent-copilot-captures.json');
const planPath = process.env.M365_BROWSER_CAPTURE_PLAN || path.join(artifactRoot, 'agent-copilot-browser-capture-plan.json');

if (!fs.existsSync(planPath)) {
  throw new Error(`Agent and Copilot browser capture plan was not found at ${planPath}.`);
}

const metadata = fs.existsSync(metadataPath)
  ? JSON.parse(fs.readFileSync(metadataPath, 'utf8'))
  : {};

const planData = JSON.parse(fs.readFileSync(planPath, 'utf8'));

const tenantId = process.env.M365_TENANT_ID || metadata.TenantId || planData.TenantId;

if (!tenantId) {
  throw new Error(`M365_TENANT_ID was not provided and ${metadataPath} does not contain a tenant ID.`);
}

function getCapturePlan() {
  return planData.Requests || planData.requests || planData;
}

async function fetchCapture(page, request) {
  return page.evaluate(async (captureRequest) => {
    const headers = {
      ...(captureRequest.DefaultHeaders || captureRequest.defaultHeaders || {}),
      ...(captureRequest.Headers || captureRequest.headers || {})
    };
    const controller = new AbortController();
    const timeoutMs = captureRequest.TimeoutMs || captureRequest.timeoutMs || 20000;
    const timeoutHandle = setTimeout(() => controller.abort(), timeoutMs);
    const init = {
      method: captureRequest.Method || captureRequest.method || 'GET',
      credentials: 'include',
      headers,
      signal: controller.signal
    };

    if (typeof captureRequest.Body !== 'undefined' || typeof captureRequest.body !== 'undefined') {
      const body = typeof captureRequest.Body !== 'undefined' ? captureRequest.Body : captureRequest.body;
      init.body = typeof body === 'string'
        ? body
        : JSON.stringify(body);

      const hasContentType = Object.keys(headers).some((key) => key.toLowerCase() === 'content-type');
      if (!hasContentType) {
        init.headers['Content-Type'] = 'application/json';
      }
    }

    try {
      const response = await fetch(captureRequest.Path || captureRequest.path, init);
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
        url: captureRequest.Path || captureRequest.path,
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
      const requestName = request.Name || request.name;
      console.log(`Capturing ${sectionName}/${requestName}`);
      const response = await fetchCapture(page, {
        ...request,
        DefaultHeaders: planData.DefaultHeaders || planData.defaultHeaders || {}
      });
      let body;

      try {
        body = response.bodyText === null ? null : JSON.parse(response.bodyText);
      }
      catch {
        body = response.bodyText;
      }

      results[sectionName][requestName] = {
        path: request.Path || request.path,
        method: request.Method || request.method || 'GET',
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
