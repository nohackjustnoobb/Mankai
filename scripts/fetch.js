async function fetch(url, options = {}) {
  let headers = options.headers || {};
  if (headers instanceof Headers)
    headers = Object.fromEntries(headers.entries());

  const params = {
    url: url,
    method: options.method || "GET",
    headers: headers,
    body: options.body,
  };

  try {
    const result =
      await window.webkit.messageHandlers.DEFAULT_BRIDGE.postMessage({
        method: "fetch",
        params: params,
      });

    const headers = {
      get: (name) => result.headers[name] || result.headers[name.toLowerCase()],
      has: (name) =>
        name in result.headers || name.toLowerCase() in result.headers,
      entries: () => Object.entries(result.headers),
      keys: () => Object.keys(result.headers),
      values: () => Object.values(result.headers),
    };

    const binaryString = atob(result.data);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }

    return {
      ok: result.ok,
      status: result.status,
      statusText: result.statusText,
      headers: headers,
      url: result.url,
      text: async () => new TextDecoder().decode(bytes),
      json: async () => JSON.parse(new TextDecoder().decode(bytes)),
      blob: async () => new Blob([bytes]),
      arrayBuffer: async () => bytes.buffer,
    };
  } catch (error) {
    throw new Error(`Fetch failed: ${error.message}`);
  }
}
