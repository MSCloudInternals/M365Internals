const requestBodies = new Map();
let trackedPrefixes = null;

fetch(chrome.runtime.getURL('TrackedRequestPrefixes.json'))
    .then((response) => response.json())
    .then((data) => {
        trackedPrefixes = Array.isArray(data) ? data : [];
    })
    .catch((error) => console.error('Failed to load tracked request prefixes', error));

setInterval(() => {
    const fiveMinutesAgo = Date.now() - 5 * 60 * 1000;
    for (const [key, value] of requestBodies.entries()) {
        if (value.timestamp < fiveMinutesAgo) {
            requestBodies.delete(key);
        }
    }
}, 60000);

chrome.webRequest.onBeforeRequest.addListener(
    (details) => {
        if (!shouldTrackRequest(details.url)) {
            return;
        }

        let bodyData = null;
        if (details.requestBody) {
            if (details.requestBody.raw) {
                const decoder = new TextDecoder('utf-8');
                bodyData = details.requestBody.raw.map((part) => decoder.decode(part.bytes)).join('');
            } else if (details.requestBody.formData) {
                bodyData = JSON.stringify(details.requestBody.formData);
            }
        }

        requestBodies.set(details.url, {
            body: bodyData,
            method: details.method,
            timestamp: Date.now()
        });
    },
    {
        urls: [
            'https://admin.cloud.microsoft/*'
        ]
    },
    ['requestBody']
);

function shouldTrackRequest(requestUrl) {
    try {
        const url = new URL(requestUrl);
        if (url.hostname !== 'admin.cloud.microsoft') {
            return false;
        }

        const requestPath = url.pathname + url.search;
        if (!Array.isArray(trackedPrefixes) || trackedPrefixes.length === 0) {
            return true;
        }

        return trackedPrefixes.some((prefix) => requestPath.startsWith(prefix));
    }
    catch (error) {
        console.error('Failed to inspect request URL', error);
        return false;
    }
}

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === 'GET_REQUEST_BODY') {
        const stored = requestBodies.get(message.url);

        if (!stored) {
            sendResponse({ success: false, error: 'No body found for this URL' });
            return true;
        }

        sendResponse({ success: true, body: stored.body, method: stored.method });
        if (!stored.retrieved) {
            stored.retrieved = true;
            setTimeout(() => requestBodies.delete(message.url), 5000);
        }
        return true;
    }

    if (message.type === 'GET_COOKIE') {
        chrome.cookies.getAll(
            {
                domain: 'admin.cloud.microsoft',
                name: message.cookieName
            },
            (cookies) => {
                if (chrome.runtime.lastError) {
                    sendResponse({ success: false, error: chrome.runtime.lastError.message });
                    return;
                }

                const cookie = cookies.find((entry) => entry.name === message.cookieName) || cookies[0];
                if (cookie) {
                    sendResponse({ success: true, value: cookie.value });
                } else {
                    sendResponse({ success: false, error: 'Cookie not found' });
                }
            }
        );
        return true;
    }
});

console.log('M365Ray background service worker initialized');
