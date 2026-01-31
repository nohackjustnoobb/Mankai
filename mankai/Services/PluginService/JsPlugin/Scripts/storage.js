function _getValue(key, from) {
  return window.webkit.messageHandlers.DEFAULT_BRIDGE.postMessage({
    method: "getValue",
    params: {
      key,
      from,
    },
  });
}

function _setValue(key, value, from) {
  return window.webkit.messageHandlers.DEFAULT_BRIDGE.postMessage({
    method: "setValue",
    params: {
      key,
      value,
      from,
    },
  });
}

function _removeValue(key, from) {
  return window.webkit.messageHandlers.DEFAULT_BRIDGE.postMessage({
    method: "removeValue",
    params: {
      key,
      from,
    },
  });
}
