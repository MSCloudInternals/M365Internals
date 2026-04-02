const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { test, expect } = require('@playwright/test');

const artifactRoot = path.join(__dirname, '..', 'TestResults', 'Artifacts');
const storageStatePath = process.env.M365_PLAYWRIGHT_STORAGE || path.join(artifactRoot, 'playwright-admin-storage-state.json');
const metadataPath = process.env.M365_PLAYWRIGHT_METADATA || path.join(artifactRoot, 'playwright-admin-metadata.json');
const outputPath = process.env.M365_BROWSER_CAPTURE_OUTPUT || path.join(artifactRoot, 'browser-portal-surface-discovery.json');
const planPath = process.env.M365_BROWSER_CAPTURE_PLAN || path.join(artifactRoot, 'portal-surface-discovery-plan.json');

if (!fs.existsSync(planPath)) {
  throw new Error(`Portal surface discovery plan was not found at ${planPath}.`);
}

const metadata = fs.existsSync(metadataPath)
  ? JSON.parse(fs.readFileSync(metadataPath, 'utf8'))
  : {};

const plan = JSON.parse(fs.readFileSync(planPath, 'utf8'));
const tenantId = process.env.M365_TENANT_ID || metadata.TenantId || plan.TenantId;

if (!tenantId) {
  throw new Error('M365_TENANT_ID was not provided and the discovery plan does not contain a tenant ID.');
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function compileTemplate(template) {
  const regexText = '^' + escapeRegex(template).replace(/\\\{[^}]+\\\}/g, '([^&?#]+)') + '$';
  return new RegExp(regexText, 'i');
}

function getRequestPath(urlText) {
  const url = new URL(urlText);
  return url.pathname + url.search;
}

function shouldTrackRequest(urlText, trackedPrefixes) {
  try {
    const url = new URL(urlText);
    if (url.hostname !== 'admin.cloud.microsoft') {
      return false;
    }

    const requestPath = url.pathname + url.search;
    return trackedPrefixes.some((prefix) => requestPath.startsWith(prefix));
  } catch {
    return false;
  }
}

function normalizeBody(bodyText) {
  if (!bodyText) {
    return '';
  }

  return String(bodyText).replace(/\s+/g, ' ').trim();
}

function getBodyHash(bodyText) {
  const normalizedBody = normalizeBody(bodyText);
  if (!normalizedBody) {
    return '';
  }

  return crypto.createHash('sha256').update(normalizedBody, 'utf8').digest('hex');
}

function matchKnownRequest(knownRequest, observedRequest) {
  const knownMethod = (knownRequest.Method || 'GET').toUpperCase();
  if (knownMethod !== observedRequest.method.toUpperCase()) {
    return false;
  }

  const templateRegex = compileTemplate(knownRequest.PathTemplate);
  if (!templateRegex.test(observedRequest.path)) {
    return false;
  }

  const fragments = Array.isArray(knownRequest.MatchBodyIncludes)
    ? knownRequest.MatchBodyIncludes
    : [];

  if (fragments.length > 0) {
    const normalizedBody = normalizeBody(observedRequest.bodyText);
    return fragments.every((fragment) => normalizedBody.includes(fragment));
  }

  return true;
}

function createObservedRequestRecord(request) {
  let bodyText = null;
  try {
    bodyText = request.postData() || null;
  } catch {
    bodyText = null;
  }

  return {
    method: request.method(),
    url: request.url(),
    path: getRequestPath(request.url()),
    bodyText,
    bodyHash: getBodyHash(bodyText)
  };
}

function dedupeRequests(requests) {
  const deduped = new Map();
  for (const request of requests) {
    const key = `${request.method}|${request.path}|${request.bodyHash}`;
    if (!deduped.has(key)) {
      deduped.set(key, request);
    }
  }

  return Array.from(deduped.values()).sort((left, right) => {
    return `${left.method}|${left.path}|${left.bodyHash}`.localeCompare(`${right.method}|${right.path}|${right.bodyHash}`);
  });
}

function normalizeInteractionAction(actionName) {
  return String(actionName || '').replace(/[^A-Za-z]/g, '').toLowerCase();
}

function getInteractionTimeout(action, fallback = 5000) {
  const timeoutMs = Number(action.TimeoutMs);
  return Number.isFinite(timeoutMs) && timeoutMs > 0 ? timeoutMs : fallback;
}

function getInteractionWaitDuration(action, fallback = 1000) {
  const waitMs = Number(action.DurationMs ?? action.WaitMs ?? action.TimeoutMs);
  return Number.isFinite(waitMs) && waitMs >= 0 ? waitMs : fallback;
}

function getInteractionLabel(action) {
  return action.Label || action.Text || action.Name || action.Selector || action.Action || 'interaction';
}

async function resolveInteractionLocator(page, action) {
  switch (normalizeInteractionAction(action.Action)) {
    case 'clicktext':
    case 'waitfortext':
      return page.getByText(String(action.Text), { exact: action.Exact === true }).first();
    case 'clickrole':
      return page.getByRole(String(action.Role), {
        name: String(action.Name),
        exact: action.Exact === true
      }).first();
    case 'clickselector':
    case 'waitforselector':
      return page.locator(String(action.Selector)).first();
    default:
      return null;
  }
}

async function executeDiscoveryInteraction(page, action) {
  const normalizedAction = normalizeInteractionAction(action.Action);
  const timeout = getInteractionTimeout(action);
  const locator = await resolveInteractionLocator(page, action);

  switch (normalizedAction) {
    case 'wait':
      await page.waitForTimeout(getInteractionWaitDuration(action));
      break;
    case 'clicktext':
    case 'clickrole':
    case 'clickselector':
      await locator.waitFor({ state: 'visible', timeout });
      await locator.click({ timeout });
      break;
    case 'waitfortext':
      await locator.waitFor({ state: action.State || 'visible', timeout });
      break;
    case 'waitforselector':
      await locator.waitFor({ state: action.State || 'visible', timeout });
      break;
    default:
      throw new Error(`Unsupported discovery interaction '${action.Action}'.`);
  }

  if (Number.isFinite(Number(action.WaitAfterMs)) && Number(action.WaitAfterMs) > 0) {
    await page.waitForTimeout(Number(action.WaitAfterMs));
  }
}

async function executeDiscoveryInteractions(page, route) {
  const interactionResults = [];

  for (const action of route.Interactions || []) {
    const label = getInteractionLabel(action);

    try {
      await executeDiscoveryInteraction(page, action);
      interactionResults.push({
        label,
        action: action.Action,
        status: 'completed'
      });
    } catch (error) {
      if (action.Optional) {
        interactionResults.push({
          label,
          action: action.Action,
          status: 'skipped',
          reason: error.message
        });
        continue;
      }

      throw new Error(`Interaction '${label}' failed for route '${route.Name}': ${error.message}`);
    }
  }

  return interactionResults;
}

function toObservedRequestOutput(request) {
  return {
    method: request.method,
    path: request.path,
    bodyHash: request.bodyHash
  };
}

function toUnexpectedRequestOutput(request) {
  return {
    method: request.method,
    path: request.path,
    bodyHash: request.bodyHash,
    sampleUrl: request.url,
    sampleBody: request.bodyText
  };
}

test.use({
  browserName: 'chromium',
  channel: 'msedge',
  storageState: storageStatePath,
  ignoreHTTPSErrors: true
});

test('discovers portal surface requests', async ({ page }) => {
  test.setTimeout(900000);

  await page.goto('https://admin.cloud.microsoft/', {
    waitUntil: 'domcontentloaded',
    timeout: 120000
  });

  await page.waitForTimeout(5000);

  const title = await page.title();
  expect(title).not.toMatch(/sign in/i);

  const routeResults = [];
  const uniqueUnexpectedByKey = new Map();

  for (const route of plan.Routes || []) {
    const observedRequests = [];
    const requestListener = (request) => {
      if (!shouldTrackRequest(request.url(), plan.TrackedPrefixes || [])) {
        return;
      }

      observedRequests.push(createObservedRequestRecord(request));
    };

    page.on('request', requestListener);

    let interactionResults = [];
    try {
      const routeUrl = route.Route.startsWith('#')
        ? `https://admin.cloud.microsoft/${route.Route}`
        : route.Route;

      console.log(`Discovering ${route.Name} via ${routeUrl}`);
      await page.goto(routeUrl, {
        waitUntil: 'domcontentloaded',
        timeout: 120000
      });

      interactionResults = await executeDiscoveryInteractions(page, route);
      await page.waitForTimeout(route.WaitMs || 8000);
    } finally {
      page.off('request', requestListener);
    }

    const uniqueObserved = dedupeRequests(observedRequests);
    const unexpectedRequests = uniqueObserved.filter((request) => {
      return !(plan.KnownRequests || []).some((knownRequest) => matchKnownRequest(knownRequest, request));
    });

    for (const request of unexpectedRequests) {
      const key = `${route.Name}|${request.method}|${request.path}|${request.bodyHash}`;
      if (!uniqueUnexpectedByKey.has(key)) {
        uniqueUnexpectedByKey.set(key, {
          routeName: route.Name,
          route: route.Route,
          metadata: route.Metadata || {},
          ...toUnexpectedRequestOutput(request)
        });
      }
    }

    routeResults.push({
      name: route.Name,
      route: route.Route,
      metadata: route.Metadata || {},
      interactionResults,
      observedRequestCount: observedRequests.length,
      uniqueObservedRequestCount: uniqueObserved.length,
      observedRequests: uniqueObserved.map(toObservedRequestOutput),
      unexpectedRequestCount: unexpectedRequests.length,
      unexpectedRequests: unexpectedRequests.map(toUnexpectedRequestOutput)
    });
  }

  const output = {
    discoveredAt: new Date().toISOString(),
    tenantId,
    planIds: plan.PlanIds || [],
    trackedPrefixes: plan.TrackedPrefixes || [],
    routeResults,
    unexpectedRequests: Array.from(uniqueUnexpectedByKey.values())
  };

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));
});
