let cmdletMapping = [];
const capturedRequests = [];
const compiledMappingCache = new Map();
const fallbackCmdlet = 'Invoke-M365AdminRestMethod';
let trackedPrefixes = null;

fetch('CmdletApiMapping.json')
    .then((response) => response.json())
    .then((data) => {
        cmdletMapping = data;
    })
    .catch((error) => console.error('Failed to load mapping', error));

fetch('TrackedRequestPrefixes.json')
    .then((response) => response.json())
    .then((data) => {
        trackedPrefixes = Array.isArray(data) ? data : [];
    })
    .catch((error) => console.error('Failed to load tracked request prefixes', error));

addDisclaimerToUI();
registerCookieCopyButton('copy-rootauth-btn', 'RootAuthToken', 'Copy RootAuthToken');
registerCookieCopyButton('copy-spaauth-btn', 'SPAAuthCookie', 'Copy SPAAuthCookie');
registerCookieCopyButton('copy-oidcauth-btn', 'OIDCAuthCookie', 'Copy OIDCAuthCookie');
registerCookieCopyButton('copy-ajax-btn', 's.AjaxSessionKey', 'Copy s.AjaxSessionKey');
registerCookieCopyButton('copy-routekey-btn', 'x-portal-routekey', 'Copy x-portal-routekey');

chrome.devtools.network.onRequestFinished.addListener((request) => {
    if (!shouldCaptureRequest(request.request.url)) {
        return;
    }

    processRequest(request);
});

function shouldCaptureRequest(requestUrl) {
    try {
        const url = new URL(requestUrl);
        if (url.hostname !== 'admin.cloud.microsoft') {
            return false;
        }

        const requestPath = url.pathname + url.search;
        if (!Array.isArray(trackedPrefixes) || trackedPrefixes.length === 0) {
            return false;
        }

        return trackedPrefixes.some((prefix) => requestPath.startsWith(prefix));
    } catch (error) {
        console.error('Failed to inspect request URL', error);
        return false;
    }
}

function processRequest(request) {
    const headers = {};
    if (request.request.headers) {
        request.request.headers.forEach((header) => {
            headers[header.name.toLowerCase()] = header.value;
        });
    }

    chrome.runtime.sendMessage(
        { type: 'GET_REQUEST_BODY', url: request.request.url },
        (response) => {
            let body = null;
            if (response && response.success && response.body) {
                try {
                    body = JSON.parse(response.body);
                } catch (error) {
                    body = response.body;
                }
            }

            const requestData = {
                method: request.request.method,
                url: request.request.url,
                path: getDisplayPath(request.request.url),
                headers,
                body,
                timestamp: new Date().toISOString(),
                routeParams: {}
            };

            const mapping = findCmdletMatch(requestData);
            requestData.cmdlet = mapping.cmdlet;
            requestData.parameters = mapping.parameters;
            requestData.switchParameters = mapping.switchParameters;
            requestData.routeParams = mapping.routeParams;

            capturedRequests.push(requestData);
            addRequestToUI(requestData);
        }
    );
}

function getDisplayPath(requestUrl) {
    const url = new URL(requestUrl);
    return url.pathname + url.search;
}

function findCmdletMatch(data) {
    const pathWithSearch = getDisplayPath(data.url);
    const bodyText = getBodyText(data.body);

    for (const map of cmdletMapping) {
        if (map.Method && map.Method.toUpperCase() !== data.method.toUpperCase()) {
            continue;
        }

        const compiled = compileMapping(map);
        const match = compiled.regex.exec(pathWithSearch);
        if (!match) {
            continue;
        }

        if (Array.isArray(map.MatchBodyIncludes) && !map.MatchBodyIncludes.every((fragment) => bodyText.includes(fragment))) {
            continue;
        }

        const routeParams = {};
        compiled.placeholderNames.forEach((name, index) => {
            routeParams[name] = normalizeScalarValue(decodeURIComponent(match[index + 1]));
        });

        return {
            cmdlet: map.Cmdlet,
            parameters: map.Parameters || null,
            switchParameters: new Set(map.SwitchParameters || []),
            routeParams
        };
    }

    return {
        cmdlet: fallbackCmdlet,
        parameters: null,
        switchParameters: new Set(),
        routeParams: {}
    };
}

function compileMapping(map) {
    const cacheKey = `${map.Method || ''}|${map.ApiUri}`;
    if (compiledMappingCache.has(cacheKey)) {
        return compiledMappingCache.get(cacheKey);
    }

    const mappingUrl = new URL(map.ApiUri);
    const mappingPath = mappingUrl.pathname + mappingUrl.search;
    const placeholderNames = [];
    const regexText = '^' + escapeRegex(mappingPath).replace(/\\\{([^}]+)\\\}/g, (_, name) => {
        placeholderNames.push(name);
        return '([^&?#]+)';
    }) + '$';

    const compiled = {
        regex: new RegExp(regexText, 'i'),
        placeholderNames
    };
    compiledMappingCache.set(cacheKey, compiled);
    return compiled;
}

function escapeRegex(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function getBodyText(body) {
    if (body === null || body === undefined) {
        return '';
    }

    return typeof body === 'string' ? body : JSON.stringify(body);
}

function resolveValue(data, sourcePath) {
    if (!sourcePath) {
        return undefined;
    }

    if (sourcePath.startsWith('fixed:')) {
        return normalizeScalarValue(sourcePath.substring(6));
    }

    if (sourcePath.startsWith('header:')) {
        const headerName = sourcePath.substring(7).toLowerCase();
        return normalizeScalarValue(data.headers ? data.headers[headerName] : undefined);
    }

    if (sourcePath.startsWith('query:')) {
        const queryName = sourcePath.substring(6);
        const url = new URL(data.url);
        return normalizeScalarValue(url.searchParams.get(queryName));
    }

    if (sourcePath.startsWith('route:')) {
        const routeName = sourcePath.substring(6);
        return data.routeParams ? data.routeParams[routeName] : undefined;
    }

    const parts = sourcePath.split('.');
    let current = sourcePath.startsWith('body.') ? data.body : data;

    for (const part of parts) {
        if (part === 'body' && current === data) {
            current = data.body;
            continue;
        }

        if (current === null || current === undefined) {
            return undefined;
        }

        current = current[part];
    }

    return normalizeScalarValue(current);
}

function normalizeScalarValue(value) {
    if (typeof value !== 'string') {
        return value;
    }

    const trimmedValue = value.trim();
    if (/^true$/i.test(trimmedValue)) {
        return true;
    }
    if (/^false$/i.test(trimmedValue)) {
        return false;
    }
    if (/^-?\d+$/.test(trimmedValue)) {
        return Number(trimmedValue);
    }

    return value;
}

function addRequestToUI(data) {
    const list = document.getElementById('request-list');
    const item = document.createElement('div');
    item.className = 'request-item';

    const summary = document.createElement('div');
    summary.className = 'request-summary';

    const methodSpan = document.createElement('span');
    methodSpan.className = `method ${data.method}`;
    methodSpan.textContent = data.method;
    summary.appendChild(methodSpan);

    const labelSpan = document.createElement('span');
    labelSpan.className = 'cmdlet';
    labelSpan.textContent = data.cmdlet;
    summary.appendChild(labelSpan);

    const urlSpan = document.createElement('span');
    urlSpan.className = 'url';
    urlSpan.textContent = data.path;
    summary.appendChild(urlSpan);

    const details = document.createElement('div');
    details.className = 'details';

    const psCode = generatePowerShellCode(data);

    const copyBtn = document.createElement('button');
    copyBtn.className = 'copy-btn';
    copyBtn.textContent = 'Copy Code';

    const codeDiv = document.createElement('div');
    codeDiv.style.marginBottom = '10px';
    codeDiv.style.color = '#9cdcfe';
    codeDiv.style.whiteSpace = 'pre-wrap';
    codeDiv.textContent = psCode;

    const timestampDiv = document.createElement('div');
    timestampDiv.style.color = '#808080';
    timestampDiv.textContent = `# Captured: ${data.timestamp}`;

    const urlDiv = document.createElement('div');
    urlDiv.style.color = '#6a9955';
    urlDiv.textContent = `# Full URL: ${data.url}`;

    details.appendChild(copyBtn);
    details.appendChild(codeDiv);
    details.appendChild(timestampDiv);
    details.appendChild(urlDiv);

    if (data.body) {
        const bodyDiv = document.createElement('div');
        bodyDiv.style.marginTop = '5px';
        bodyDiv.style.color = '#6a9955';
        bodyDiv.style.whiteSpace = 'pre-wrap';
        bodyDiv.textContent = `# Request Payload: ${typeof data.body === 'string' ? data.body : JSON.stringify(data.body, null, 2)}`;
        details.appendChild(bodyDiv);
    }

    summary.addEventListener('click', () => {
        details.classList.toggle('open');
    });

    copyBtn.addEventListener('click', (event) => {
        event.stopPropagation();
        copyToClipboard(psCode, copyBtn);
    });

    item.appendChild(summary);
    item.appendChild(details);
    list.appendChild(item);
}

function generatePowerShellCode(data) {
    if (data.cmdlet !== fallbackCmdlet) {
        let code = `# ${data.cmdlet}\n${data.cmdlet}`;

        if (data.parameters) {
            for (const [paramName, sourcePath] of Object.entries(data.parameters)) {
                const value = resolveValue(data, sourcePath);
                if (value === undefined || value === null) {
                    continue;
                }

                if (data.switchParameters.has(paramName)) {
                    if (value) {
                        code += ` -${paramName}`;
                    }
                    continue;
                }

                code += ` -${paramName} ${formatPowerShellValue(value)}`;
            }
        }

        return code;
    }

    const url = new URL(data.url);
    const commandTargetName = url.hostname === 'admin.cloud.microsoft' ? 'Path' : 'Uri';
    const commandTargetValue = commandTargetName === 'Path' ? url.pathname + url.search : data.url;
    const commandPrefix = `${fallbackCmdlet} -${commandTargetName} ${formatPowerShellValue(commandTargetValue)} -Method ${formatPowerShellValue(data.method)}`;
    const lines = [
        `# ${fallbackCmdlet}`,
        '# No native M365Internals cmdlet mapping found for this request.'
    ];

    if (url.pathname.startsWith('/fd/msgraph/')) {
        lines.push('# Captured Graph proxy requests often require the originating admin page headers.');
    }

    if (data.body !== null && data.body !== undefined) {
        lines.push('$Body = @\'');
        lines.push(typeof data.body === 'string' ? data.body : JSON.stringify(data.body, null, 2));
        lines.push('\'@');
        lines.push(`${commandPrefix} -Body $Body`);
    } else {
        lines.push(commandPrefix);
    }

    return lines.join('\n');
}

function formatPowerShellValue(value) {
    if (value === null || value === undefined) {
        return '$null';
    }

    if (typeof value === 'boolean') {
        return value ? '$true' : '$false';
    }

    if (typeof value === 'number') {
        return String(value);
    }

    return `'${escapeForSingleQuotedPowerShellString(String(value))}'`;
}

function escapeForSingleQuotedPowerShellString(value) {
    return String(value).replace(/'/g, "''");
}

function addDisclaimerToUI() {
    const list = document.getElementById('request-list');
    const item = document.createElement('div');
    item.className = 'request-item';
    item.style.borderColor = '#007acc';

    const summary = document.createElement('div');
    summary.className = 'request-summary';
    summary.style.backgroundColor = '#1e2e3e';
    summary.style.cursor = 'default';

    const iconSpan = document.createElement('span');
    iconSpan.textContent = 'i';
    iconSpan.style.marginRight = '10px';
    iconSpan.style.color = '#007acc';
    summary.appendChild(iconSpan);

    const titleSpan = document.createElement('span');
    titleSpan.textContent = 'M365Ray maps captured admin.cloud.microsoft requests to M365Internals cmdlets when possible and falls back to Invoke-M365AdminRestMethod otherwise. Verify generated code before running it.';
    titleSpan.style.color = '#cccccc';
    titleSpan.style.fontSize = '11px';
    summary.appendChild(titleSpan);

    item.appendChild(summary);
    if (list.firstChild) {
        list.insertBefore(item, list.firstChild);
    } else {
        list.appendChild(item);
    }
}

document.getElementById('clear-btn').addEventListener('click', () => {
    capturedRequests.length = 0;
    document.getElementById('request-list').innerHTML = '';
    addDisclaimerToUI();
});

document.getElementById('save-btn').addEventListener('click', () => {
    let scriptContent = '# M365Ray Generated Script\n';
    scriptContent += '# Best-effort mapping based on the current M365Internals cmdlet catalog.\n';
    scriptContent += '# Review the generated code and authentication context before running it.\n\n';

    capturedRequests.forEach((request) => {
        scriptContent += generatePowerShellCode(request) + '\n\n';
    });

    const blob = new Blob([scriptContent], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = 'M365Ray-Script.ps1.txt';
    anchor.click();
    URL.revokeObjectURL(url);
});

document.getElementById('danger-zone-toggle').addEventListener('click', (event) => {
    const button = event.currentTarget;
    if (button.textContent.includes('Danger Zone')) {
        button.textContent = 'I understand the security risks';
        button.style.backgroundColor = '#ce9178';
        button.style.color = '#1e1e1e';
        return;
    }

    document.getElementById('danger-zone-content').style.display = 'flex';
    addDangerZoneInfoToUI();
    button.style.display = 'none';
});

function addDangerZoneInfoToUI() {
    const list = document.getElementById('request-list');
    const item = document.createElement('div');
    item.className = 'request-item';
    item.style.borderColor = '#ce9178';

    const summary = document.createElement('div');
    summary.className = 'request-summary';
    summary.style.backgroundColor = '#3e2d2d';

    const iconSpan = document.createElement('span');
    iconSpan.textContent = '!';
    iconSpan.style.marginRight = '10px';
    iconSpan.style.color = '#ce9178';
    summary.appendChild(iconSpan);

    const titleSpan = document.createElement('span');
    titleSpan.textContent = 'Setup M365Internals with captured admin portal cookies';
    titleSpan.style.fontWeight = 'bold';
    titleSpan.style.color = '#ce9178';
    summary.appendChild(titleSpan);

    const details = document.createElement('div');
    details.className = 'details open';

    const codeBlock = document.createElement('div');
    codeBlock.style.color = '#dcdcaa';
    codeBlock.style.whiteSpace = 'pre-wrap';
    codeBlock.style.marginBottom = '10px';
    codeBlock.textContent = `Import-Module M365Internals.psd1\n$RootAuthToken = Read-Host -Prompt "Paste the RootAuthToken cookie value"\n$SPAAuthCookie = Read-Host -Prompt "Paste the SPAAuthCookie cookie value"\n$OIDCAuthCookie = Read-Host -Prompt "Paste the OIDCAuthCookie cookie value"\n$AjaxSessionKey = Read-Host -Prompt "Paste the s.AjaxSessionKey cookie value"\nConnect-M365Portal -RootAuthToken $RootAuthToken -SPAAuthCookie $SPAAuthCookie -OIDCAuthCookie $OIDCAuthCookie -AjaxSessionKey $AjaxSessionKey`;

    const copyBtn = document.createElement('button');
    copyBtn.className = 'copy-btn';
    copyBtn.textContent = 'Copy Code';
    copyBtn.addEventListener('click', (event) => {
        event.stopPropagation();
        copyToClipboard(codeBlock.textContent, copyBtn);
    });

    details.appendChild(copyBtn);
    details.appendChild(codeBlock);

    summary.addEventListener('click', () => {
        details.classList.toggle('open');
    });

    item.appendChild(summary);
    item.appendChild(details);
    list.insertBefore(item, list.firstChild);
}

function registerCookieCopyButton(buttonId, cookieName, defaultLabel) {
    const button = document.getElementById(buttonId);
    if (!button) {
        return;
    }

    button.dataset.defaultLabel = defaultLabel;
    button.addEventListener('click', (event) => {
        chrome.runtime.sendMessage({ type: 'GET_COOKIE', cookieName }, (response) => {
            if (response && response.success) {
                copyToClipboard(response.value, event.currentTarget, true);
            } else {
                showTemporaryLabel(event.currentTarget, 'Not Found', defaultLabel, 2000);
            }
        });
    });
}

function copyToClipboard(text, button, isSensitive = false) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(() => {
            showTemporaryLabel(button, isSensitive ? 'Copied Securely' : 'Copied', button.dataset.defaultLabel || button.textContent, 2000);
        }).catch(() => {
            fallbackCopyToClipboard(text, button, isSensitive);
        });
        return;
    }

    fallbackCopyToClipboard(text, button, isSensitive);
}

function fallbackCopyToClipboard(text, button, isSensitive) {
    const textArea = document.createElement('textarea');
    textArea.value = text;
    document.body.appendChild(textArea);
    textArea.select();
    document.execCommand('copy');
    document.body.removeChild(textArea);
    showTemporaryLabel(button, isSensitive ? 'Copied Securely' : 'Copied', button.dataset.defaultLabel || button.textContent, 2000);
}

function showTemporaryLabel(button, temporaryLabel, defaultLabel, timeout) {
    if (!button.dataset.defaultLabel) {
        button.dataset.defaultLabel = defaultLabel;
    }

    button.textContent = temporaryLabel;
    setTimeout(() => {
        button.textContent = button.dataset.defaultLabel;
    }, timeout);
}
