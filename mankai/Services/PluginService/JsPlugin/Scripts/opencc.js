async function s2t(text) {
  const result = await window.webkit.messageHandlers.DEFAULT_BRIDGE.postMessage(
    {
      method: "s2t",
      params: { text },
    },
  );

  return result;
}

async function t2s(text) {
  const result = await window.webkit.messageHandlers.DEFAULT_BRIDGE.postMessage(
    {
      method: "t2s",
      params: { text },
    },
  );

  return result;
}
