const requestBodies = new Map();
const trackedPrefixes = [
    'https://admin.cloud.microsoft/admin/api/',
    'https://admin.cloud.microsoft/adminportal/home/',
    'https://admin.cloud.microsoft/fd/msgraph/'
];

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
        if (!trackedPrefixes.some((prefix) => details.url.startsWith(prefix))) {
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
            'https://admin.cloud.microsoft/admin/api/*',
            'https://admin.cloud.microsoft/adminportal/home/*',
            'https://admin.cloud.microsoft/fd/msgraph/*'
        ]
    },
    ['requestBody']
);

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
        const cookieApi = typeof browser !== 'undefined' ? browser.cookies : chrome.cookies;
        cookieApi.getAll({ domain: 'admin.cloud.microsoft', name: message.cookieName })
            .then((cookies) => {
                const cookie = cookies.find((entry) => entry.name === message.cookieName) || cookies[0];
                if (cookie) {
                    sendResponse({ success: true, value: cookie.value });
                } else {
                    sendResponse({ success: false, error: 'Cookie not found' });
                }
            })
            .catch((error) => {
                sendResponse({ success: false, error: error.message });
            });
        return true;
    }
});

console.log('M365Ray Firefox background initialized');