function _log(mesg, from = "JS") {
  window.webkit.messageHandlers.DEFAULT_BRIDGE.postMessage({
    method: "log",
    params: {
      message: mesg,
      from: from,
    },
  });
}
