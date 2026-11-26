const form = document.querySelector("form.list-filters");
const results = document.getElementById("filter-results");
let activeRequest;
let searchTimer;

async function refreshResults() {
    if (!form.checkValidity()) return;

    const url = new URL(form.action);
    url.search = new URLSearchParams(new FormData(form));
    const request = new AbortController();
    activeRequest = request;

    try {
        const response = await fetch(url, { signal: request.signal });
        // Follow sign-in redirects as page navigations so the login form can render.
        if (response.redirected) {
            if (!request.signal.aborted) window.location.assign(response.url);
            return;
        }
        const page = new DOMParser().parseFromString(await response.text(), "text/html");
        if (request.signal.aborted) return;

        const updated = page.getElementById("filter-results");
        if (updated) {
            results.replaceChildren(...updated.childNodes);
            history.replaceState(history.state, "", url);
        } else {
            window.location.assign(url);
        }
    } catch {
        if (!request.signal.aborted) window.location.assign(url);
    }
}

function scheduleRefresh(delay) {
    activeRequest?.abort();
    clearTimeout(searchTimer);
    searchTimer = setTimeout(refreshResults, delay);
}

form.addEventListener("change", (event) => {
    if (event.target.name !== "q") scheduleRefresh(0);
});
form.elements.namedItem("q")?.addEventListener("input", () => scheduleRefresh(300));
form.addEventListener("submit", (event) => {
    event.preventDefault();
    scheduleRefresh(0);
});
